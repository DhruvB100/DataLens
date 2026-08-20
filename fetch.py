import requests
import json

def main():
    feed_url = "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_day.geojson"

    response = requests.get(feed_url)
    assert response.status_code == 200, "Failed to GET"

    data = response.json()
    with open("earthquakes.json","w") as file:
        json.dump(data,file,indent=2)
    
    features = data["features"][0]
    with open("features.json","w") as file:
        json.dump(features,file,indent=2)
    
    records = []
    for feature in data["features"]:
        props = feature["properties"]
        coords = feature["geometry"]["coordinates"]
        
        dic = {"id":feature["id"],
                "magnitude":props["mag"],
                "place":props["place"],
                "event_time":props["time"],
                "tsunami":props["tsunami"],
                "longitude":coords[0],
                "latitude":coords[1],
                "depth_km":coords[2]}
        records.append(dic)
    
    with open("records.json","w") as file:
        json.dump(records,file,indent=2)
        
if __name__=="__main__":
    main()


