#!/bin/bash
until docker exec dspace-ui test -f /app/dist/browser/assets/config.json 2>/dev/null; do sleep 5; done

docker exec dspace-ui python3 -c "import json,os; f='/app/dist/browser/assets/config.json'; h=os.environ.get('DSPACE_REST_HOST','localhost'); d=json.load(open(f)); d['rest']['ssl']=True; d['rest']['baseUrl']='https://'+h+'/server'; json.dump(d,open(f,'w'))"

docker exec dspace-ui python3 -c "
import os, shutil
browser = '/app/dist/browser/assets/i18n'
server = '/app/dist/server/assets/i18n'
os.makedirs(server, exist_ok=True)
for fname in os.listdir(browser):
    if fname.endswith('.json') and not fname.endswith('.json5'):
        shutil.copy(os.path.join(browser, fname), os.path.join(server, fname))
        print('copiado:', fname)
"
