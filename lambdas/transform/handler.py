import json
import io
import boto3
import pandas as pd
import os

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass
    
S3 = boto3.client("s3")
BUCKET = os.environ["DATA_BUCKET"]

# flattens raw feed json into rows, drops bad/duplicate ones
def to_dataframe(raw_bytes):
    data = json.loads(raw_bytes)
    
    rows = []
    
    for feature in data.get("features",[]):
       prop = feature.get("properties",{})
       geo = feature.get("geometry") or {}
       coord = geo.get("coordinates",[None,None,None])
       
       row = {
           "id" : feature.get("id"),
           "magnitude" : prop.get("mag"),
           "place" : prop.get("place"),
           "event_time" : pd.to_datetime(prop.get("time"), unit="ms",utc=True),
           "tsunami" : prop.get("tsunami",0),
           "longitude" : coord[0],
           "latitude" : coord[1],
           "depth_km" : coord[2]   
       }
       
       rows.append(row)
    
    df = pd.DataFrame(rows)
    df = df.dropna(subset=["id","magnitude"])
    df = df.drop_duplicates("id")
    
    return df

# triggered by s3 whenever a new file lands in bronze/ - reads it, cleans it,
# writes parquet to gold/ partitioned by day
def handler(event,context):
    record = event["Records"][0]["s3"]
    key = record["object"]["key"]
    
    obj = S3.get_object(Bucket=BUCKET,Key=key)
    
    rawBytes = obj["Body"].read()
    df = to_dataframe(rawBytes)
    
    if len(df) > 0:
        day = df["event_time"].dt.strftime("%Y-%m-%d").iloc[0]
    else:
        day = "unknown"
        
    buf = io.BytesIO()
    df.to_parquet(buf,index=False)
    
    filename = key.split("/")[-1].replace(".json",".parquet")
    out_key = f"gold/dt={day}/{filename}"
    
    S3.put_object(Bucket=BUCKET,Key=out_key,Body=buf.getvalue())
    
    return {
        "rows_processed": len(df),
        "output_path" : out_key
    }
    
if __name__ == "__main__":
    with open("../../earthquakes.json","rb") as f:
        raw_bytes = f.read()
        
    dataframe = to_dataframe(raw_bytes)
    
    print(dataframe.shape)   
    print(dataframe.dtypes) 
    print(dataframe.head())
       
       