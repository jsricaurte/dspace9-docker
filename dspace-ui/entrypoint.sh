#!/bin/sh
# entrypoint.sh — DSpace Angular UI
# Aplica parche SSL al config.json antes de arrancar Node.
# Esto resuelve el error: config.json embebe ssl:false durante el build.

# Primera vez: compilar en modo producción
if [ ! -f /app/dist/server/main.js ]; then
  echo "Primera vez: compilando en modo producción (~25-40 min)..."
  npm run build:ssr
fi

# Aplicar parche SSL al config.json generado por el build
# El build embebe ssl:false aunque config.yml tenga ssl:true
echo "Aplicando parche SSL al config.json..."
python3 -c "
import json, os
f = '/app/dist/browser/assets/config.json'
host = os.environ.get('DSPACE_REST_HOST', 'localhost')
with open(f, 'r') as fp:
    d = json.load(fp)
d['rest']['ssl'] = True
d['rest']['baseUrl'] = 'https://' + host + '/server'
with open(f, 'w') as fp:
    json.dump(d, fp)
print('Parche OK: ssl=True, baseUrl=https://' + host + '/server')
"

# Arrancar Node en modo producción
echo "Arrancando servidor Node en modo producción..."
NODE_ENV=production node /app/dist/server/main
