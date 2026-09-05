import json
import os
import datetime
import urllib.request

import boto3

S3 = boto3.client("s3")
BUCKET = os.environ["DATA_BUCKET"]
FEED_URL = "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_day.geojson"

def handler(event, context):
    with urllib.request.urlopen(FEED_URL, timeout=20) as r:
        raw = r.read()
        now = datetime.datetime.now(datetime.timezone.utc)
        
    key = f"bronze/{now:%Y/%m/%d}/{now:%H%M%S}.json"
    S3.put_object(Bucket = BUCKET, Key = key, Body = raw)
    
    payload = json.loads(raw)
    
    res = {"stored":key,"count": len(payload.get("features",[])) }
    return res
        
    
if __name__ == "__main__":
    result = handler(None,None)
    print(result)