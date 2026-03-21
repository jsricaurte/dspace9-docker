#!/bin/bash
until docker exec dspace-ui test -f /app/dist/browser/assets/config.json 2>/dev/null; do sleep 5; done
docker exec dspace-ui python3 -c "import json,os; f='/app/dist/browser/assets/config.json'; h=os.environ.get('DSPACE_REST_HOST','localhost'); d=json.load(open(f)); d['rest']['ssl']=True; d['rest']['baseUrl']='https://'+h+'/server'; json.dump(d,open(f,'w'))"
docker exec dspace-ui cp /app/dist/browser/assets/i18n/en.json /app/dist/browser/assets/i18n/en.48c9dbeb5b0689800f7343f6feedfc09.json
