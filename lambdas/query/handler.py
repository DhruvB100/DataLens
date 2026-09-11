import os
import time
import boto3

import json

ATHENA = boto3.client("athena")
DATABASE = os.environ["GLUE_DB"]
OUT_PATH = os.environ["ATHENA_OUTPUT"]

CACHE = {}
CACHE_TTL = 30

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
    
def handler(event,context):
    path = event.get("path","")
    params = event.get("queryStringParameters") or {}
    
    cache_key = f"{path}-{str(sorted(params.items()))}"
    
    if cache_key in CACHE:
        saved_time, saved_response = CACHE[cache_key]
        
        if time.time() - saved_time < CACHE_TTL:
            # CACHE HIT!
            return saved_response
    
    if path == "/stats":
        sql_query = "SELECT dt,count(*) as num_events, avg(magnitude) as avg_magnitude FROM earthquakes GROUP BY dt ORDER BY dt DESC"
    
    elif path == "/recent":
        limit = params.get("limit","50")
        sql_query = f"SELECT * FROM earthquakes ORDER BY event_time DESC LIMIT {int(limit)}"
    
    elif path == "/largest":
        limit = params.get("limit","10")
        sql_query = f"SELECT * FROM earthquakes ORDER BY magnitude DESC LIMIT {int(limit)}"
        
    else:
        return {
            "statusCode":404,
            "body": json.dumps({"error":f"PATH:{path} NOT FOUND"})
        }
    
    rows = run_query(sql_query)
    
    records = rows_to_dict(rows)
    
    api_response =  {
        "statusCode":200,
        "headers":{
            "Content-Type":"application/json",
            "Access-Control-Allow-Origin": "*"
        },
        "body": json.dumps(records)
    }
    
    CACHE[cache_key] = (time.time(),api_response)
    
    return api_response
    
if __name__ == "__main__":
    # query = "SELECT dt,count(*) FROM earthquakes GROUP BY dt"
    # response = run_query(query)
    # print(response)
    
    print("============TESTING==================")
    event1 = {"path":"/stats","queryStringParameters":None}
    print(handler(event1,None))
    
    event2 = {"path": "/recent", "queryStringParameters": {"limit": "5"}}
    print(handler(event2,None))
    
    event3 = {"path": "/largest", "queryStringParameters": {"limit": "9"}}
    print(handler(event3,None))