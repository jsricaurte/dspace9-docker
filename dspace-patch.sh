#!/bin/bash
until docker exec dspace-ui test -f /app/dist/browser/assets/config.json 2>/dev/null; do sleep 5; done

until docker logs dspace-ui 2>/dev/null | grep -q "Listening at http://localhost:4000"; do sleep 5; done

sleep 5

docker exec dspace-ui python3 -c "
import json, os
f = '/app/dist/browser/assets/config.json'
h = os.environ.get('DSPACE_REST_HOST', 'localhost')
d = json.load(open(f))
d['rest']['ssl'] = True
d['rest']['baseUrl'] = 'https://' + h + '/server'
json.dump(d, open(f, 'w'))
print('Parche config.json OK: ssl=True')
"

docker exec dspace-ui python3 -c "
import os, shutil, re

browser = '/app/dist/browser/assets/i18n'
server = '/app/dist/server/assets/i18n'
os.makedirs(server, exist_ok=True)

langs = [f.replace('.json','') for f in os.listdir(browser) if f.endswith('.json') and not f.endswith('.json5') and '.' not in f.replace('.json','')]

hashes = set()
for fname in os.listdir('/app/dist/browser'):
    if fname.endswith('.js'):
        try:
            content = open(os.path.join('/app/dist/browser', fname), encoding='utf-8', errors='ignore').read()
            found = re.findall(r'[a-f0-9]{32}', content)
            hashes.update(found)
        except:
            pass

for lang in langs:
    src = os.path.join(browser, lang + '.json')
    shutil.copy(src, os.path.join(server, lang + '.json'))
    for h in hashes:
        shutil.copy(src, os.path.join(browser, lang + '.' + h + '.json'))
        shutil.copy(src, os.path.join(server, lang + '.' + h + '.json'))

print('Parche i18n OK: ' + str(len(langs)) + ' idiomas copiados con hashes')
"
