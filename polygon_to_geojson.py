import json
features = [json.loads(line) for line in open('polygons.json')]
fc = {'type': 'FeatureCollection', 'features': [{'type': 'Feature', 'properties': {'gauge_name': f['gauge_name']}, 'geometry': f['geometry']} for f in features]}
json.dump(fc, open('final_polygons.geojson', 'w'))
