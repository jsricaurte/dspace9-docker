#!/bin/bash
until docker exec dspace-ui test -f /app/dist/browser/assets/config.json 2>/dev/null; do sleep 5; done

docker exec dspace-ui python3 -c "import json,os; f='/app/dist/browser/assets/config.json'; h=os.environ.get('DSPACE_REST_HOST','localhost'); d=json.load(open(f)); d['rest']['ssl']=True; d['rest']['baseUrl']='https://'+h+'/server'; json.dump(d,open(f,'w'))"

docker exec dspace-ui sh -c "
for LANG in ar bn ca cs da de el en eo es fi fr gl he hr hu id it ja ko lt lv nl no pl pt-BR pt-PT ro ru sk sr sv sw tr uk vi zh-CN zh-TW; do
  SRC=/app/dist/browser/assets/i18n/${LANG}.json
  if [ -f $SRC ]; then
    for HASHFILE in $(ls /app/dist/browser/assets/i18n/ 2>/dev/null | grep "^${LANG}\..*\.json$"); do
      cp $SRC /app/dist/browser/assets/i18n/$HASHFILE
    done
    mkdir -p /app/dist/server/assets/i18n
    cp $SRC /app/dist/server/assets/i18n/${LANG}.json
    for HASHFILE in $(ls /app/dist/server/assets/i18n/ 2>/dev/null | grep "^${LANG}\..*\.json$"); do
      cp $SRC /app/dist/server/assets/i18n/$HASHFILE
    done
  fi
done
"
