import os
import json
import urllib.request

import time
import boto3

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass
    

ATHENA = boto3.client("athena")
DATABASE = os.environ["GLUE_DB"]
OUT_PATH = os.environ["ATHENA_OUTPUT"]

GEMINI_API_KEY = os.environ["GEMINI_API_KEY"]

# fed to the llm so it knows the real table shape - and the guardrails below
# so it (hopefully) doesn't generate anything dangerous
SCHEMA = """Table earthquakes(
    id string, magnitude double, place string, event_time timestamp, tsunami int,
    longitude double, latitude double, depth_km double, dt string)"""
    
RULES = """1. Generate exactly one read-only SQL SELECT statement for aws ATHENA, nothing else.
           2. Never generate INSERT, UPDATE, DELETE, DROP, ALTER, or any other statements that changes data.
           3. Only reference the earthquakes table and no other tables, not even hypothetical ones.
           4. Use only columns listed in the schema. Do not invent new ones.
           5. Output must not have semicolons and don't chain multiple statements together.
           6. Output must not have any comments or explanatory texts. ONLY SQL, nothing else.
        """

# raw http call to gemini - no sdk, just urllib, so nothing extra to package
def call_llm(prompt):
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key={GEMINI_API_KEY}"
    body = {
        "contents": [
            {
                "parts": [
                    {
                        "text": prompt
                    }
                ]
            }
        ]
    }
    
    data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(
        url,
        data = data,
        headers={"Content-Type": "application/json"},
        method="POST"
    )
    try:
        with urllib.request.urlopen(req) as response:
            response_json = json.loads(response.read().decode("utf-8"))
            return response_json["candidates"][0]["content"]["parts"][0]["text"]
            
    except urllib.error.HTTPError as err:
        error = err.read().decode("utf-8")
        print(f"ERROR: {error}")
        raise
    
def generate_sql(question):
    prompt = f"{RULES}\n\nSchema:\n,{SCHEMA}\n\nQuestion: {question}\nSQL:"
    sql = call_llm(prompt).strip()

    # gemini likes to wrap sql in markdown fences even when told not to
    if sql.startswith("```"):
        lines = sql.split("\n")
        if lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].startswith("```"):
            lines = lines[:-1]
        sql = "\n".join(lines).strip()

    sql = sql.rstrip(";")

    # the actual guardrails - don't just trust the prompt to be obeyed
    if not sql.lower().startswith("select"):
        raise ValueError(f"Non SELECT statement: {sql}")    
    
    if ";" in sql:
        raise ValueError(f"Chained statements: {sql}")
    
    if "earthquakes" not in sql.lower():
        raise ValueError(f"Hallucination: {sql}")
    
    return sql

def run_query(sql_query):
    resp = ATHENA.start_query_execution(
        QueryString = sql_query,
        QueryExecutionContext = {
            "Database":DATABASE,
        },
        ResultConfiguration = {
            "OutputLocation":OUT_PATH
        }
    )
    
    query_id = resp["QueryExecutionId"]
    
    while True:
        status_resp = ATHENA.get_query_execution(QueryExecutionId=query_id)
        state = status_resp["QueryExecution"]["Status"]["State"]
        
        if state in ("SUCCEEDED","FAILED","CANCELLED"):
            break
        
        time.sleep(0.5)
        
    if state != "SUCCEEDED":
        raise RuntimeError(f"Athena query {state}. Ticket: {query_id}")
    
    result = ATHENA.get_query_results(QueryExecutionId=query_id)
    
    return result["ResultSet"]["Rows"]


def rows_to_dict(rows):
    header_row = rows[0]["Data"]
    header = [col.get("VarCharValue") for col in header_row]
    
    records = []
    
    for row in rows[1:]:
        values = [cell.get("VarCharValue") for cell in row["Data"]]
        records_dict = dict(zip(header,values))
        
        records.append(records_dict)
    return records

# asks the llm to turn the raw query results into one plain-english sentence
def summarize_results(question,records):
    prompt = f"Question: {question}\n\nQuery results(JSON): {json.dumps(records)}\n\nWrite one short, plain-English sentence answering the question based on this data. NO SQL, no explanations, just answer."
    result = call_llm(prompt).strip()
    return result

# the whole pipeline: question -> sql -> athena -> plain english answer
def handler(event,context):
    question = json.loads(event["body"]).get("question","")
    try:
        sql = generate_sql(question)
    except ValueError as e:
        # guardrail rejected it - bad question, not a server problem
        return {
            "statusCode":400,
            "headers":{
                "Content-Type":"application/json",
                "Access-Control-Allow-Origin":"*"
            },
            "body": json.dumps({"error":str(e)})
        }

    rows = run_query(sql)
    records = rows_to_dict(rows)
    
    answer = summarize_results(question,records)
    
    return {
        "statusCode":200,
        "headers":{
            "Content-Type":"application/json",
            "Access-Control-Allow-Origin":"*"
        },
        "body":json.dumps({
            "answer":answer,
            "sql":sql,
            "rows":records})
    }
    
if __name__ == "__main__":
    questions = [
        "Q1. How many earthquakes happened today?",
        "Q2. What is the average magnitude this week?",
        "Q3. List me the 5 strongest earthquakes.",
        "Q4. List me the 5 strongest earthquakes in the recent month",
        "Q5. Were there any tsunami warnings recently?",
        "Q6. What's the average depth of earthquakes by day?"
        ]
    for question in questions:
        print(question)
        sample_event = {
            "body":json.dumps({
                "question": question
            })
        }
        
        gen_sql = handler(sample_event,None)
        print(f"Generate SQL: {gen_sql}")
            