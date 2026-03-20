# Errores encontrados y soluciones — DSpace 9 con Docker

> Todos estos errores ocurrieron durante una instalación universitaria real.
> Cada uno incluye el síntoma exacto, la causa raíz y la solución validada.

---

## Error 1 — Spring Boot muere silenciosamente (solo aparece el banner ASCII)

**Síntoma:**
```
docker logs dspace

  .   ____          _            __ _ _
 :: Spring Boot ::  (v3.5.11)
```
Solo el banner. Sin ningún mensaje de error. Exit code 1.

**Causa:**
Spring Boot 3.5.x tiene un bug con Log4j2: bucle recursivo durante la
inicialización que mata el proceso antes de loguear nada.

**Solución — variable `LOGGING_CONFIG` en el servicio dspace:**
```yaml
environment:
  LOGGING_CONFIG: /dspace/config/log4j2-container.xml
```

---

## Error 2 — Error 500 "Service unavailable" permanente

**Síntoma:**
```
500 — Service unavailable
```
Backend responde, contenedores están Up, pero la página no carga.

**Causa:**
Angular SSR intenta contactar el backend usando la IP pública desde DENTRO
del contenedor Docker — donde esa IP no es accesible.

**Solución — `ssrBaseUrl` en `dspace-ui/config.yml`:**
```yaml
rest:
  ssl: true
  host: 192.168.1.100
  port: 443
  nameSpace: /server
  ssrBaseUrl: http://dspace:8080/server  # ← red interna Docker para el SSR

ssr:
  replaceRestUrl: true
```

---

## Error 3 — 502 Bad Gateway permanente

**Causa:**
```nginx
# INCORRECTO
location /server {
    proxy_pass http://dspace:8080;
}
```

**Solución:**
```nginx
# CORRECTO
location /server {
    proxy_pass http://dspace:8080/server;
}
```

---

## Error 4 — `docker compose down` no baja todos los contenedores

**Causa:**
`restart: unless-stopped` reinicia automáticamente.

**Solución para desarrollo:**
```yaml
restart: "no"
```

**Para producción** usar `restart: unless-stopped` — los servicios se
levantan solos después de un reinicio del servidor.

---

## Error 5 — Solr falla con "cp: cannot stat... No such file"

**Causa:**
El compose oficial de GitHub incluye comandos `cp` para copiar configsets
desde código fuente local. Con imágenes precompiladas esos archivos no existen.

**Solución:**
```yaml
entrypoint:
  - /bin/bash
  - '-c'
  - |
    init-var-solr
    precreate-core authority  /opt/solr/server/solr/configsets/authority
    precreate-core oai        /opt/solr/server/solr/configsets/oai
    precreate-core search     /opt/solr/server/solr/configsets/search
    precreate-core statistics /opt/solr/server/solr/configsets/statistics
    chown -R solr:solr /var/solr
    runuser -u solr -- solr-foreground
```

---

## Error 6 — Spring Boot en loop infinito esperando PostgreSQL

**Causa:**
```bash
# NO funciona en esta imagen:
while (! /dev/tcp/dspacedb/5432) > /dev/null 2>&1; do sleep 1; done
```

**Solución:**
```bash
while ! (echo > /dev/tcp/dspacedb/5432) 2>/dev/null; do sleep 3; done
```

---

## Error 7 — nginx no arranca: "No such file or directory"

**Causa:**
`nginx.conf` en la raíz del proyecto en lugar de `nginx/nginx.conf`.

**Solución:**
El `setup.sh` genera el archivo automáticamente en la ubicación correcta.
No depende de la estructura del repositorio descargado.

---

## Error 8 — 502 Bad Gateway durante los primeros 15-40 minutos

**NO es un error.** Es comportamiento normal.

Angular compila la aplicación en el primer arranque (~25-40 min en modo producción).

Monitorea con:
```bash
docker logs dspace-ui -f
```

Listo cuando ves:
```
Listening at http://localhost:4000
```

---

## Error 9 — `cross-env: not found` — contenedor en loop infinito

**Síntoma:**
```
docker logs dspace-ui
/bin/sh: cross-env: not found
Build encontrado. Arrancando en modo producción...
/bin/sh: cross-env: not found
Build encontrado. Arrancando en modo producción...
```
El contenedor se reinicia continuamente.

**Causa:**
`cross-env` es un paquete npm diseñado para Windows que permite definir
variables de entorno de forma multiplataforma. No existe en `/bin/sh` de
Linux Alpine (la imagen base de dspace-angular).

**Solución — usar la sintaxis nativa de Linux:**
```yaml
# INCORRECTO
entrypoint:
  - /bin/sh
  - '-c'
  - |
    cross-env NODE_ENV=production node /app/dist/server/main

# CORRECTO
entrypoint:
  - /bin/sh
  - '-c'
  - |
    NODE_ENV=production node /app/dist/server/main
```

---

## Error 10 — Angular SSR no permite IPs como hostname

**Síntoma:**
```
Error: URL with hostname "10.10.0.28" is not allowed.
ERROR: URL with hostname "10.10.0.28" is not allowed.Please provide a list
of allowed hosts in the "allowedHosts" option in the "CommonEngine" constructor.
Error in server-side rendering (SSR)
Falling back to serving direct client-side rendering (CSR).
```

**Causa:**
Angular SSR (modo producción) tiene una validación de seguridad que rechaza
IPs directas como hostname por defecto. Solo acepta nombres de dominio
a menos que se configure explícitamente.

**Solución — el SSR hace fallback a CSR automáticamente:**
El error es recuperable — Angular sirve la página en modo CSR (Client Side
Rendering) aunque el SSR falle. El sistema funciona. El log de error es
esperado cuando se usa una IP en lugar de un dominio.

Para eliminar el error completamente, usar un dominio real con Let's Encrypt
en lugar de una IP directa.

---

## Error 11 — El build de producción embebe `ssl: false` en el `config.json`

**Síntoma:**
La interfaz carga pero el backend responde con 503. Las peticiones van por
`http://` en lugar de `https://`.

**Causa:**
El build de producción de Angular (`ng build --configuration production`)
embebe la configuración en el bundle durante la compilación. Si el
`config.yml` tenía `ssl: false` cuando se compiló, el `config.json`
resultante también tendrá `ssl: false`, independientemente de los cambios
posteriores al `config.yml`.

**Verificación:**
```bash
docker exec dspace-ui python3 -c "
import json
with open('/app/dist/browser/assets/config.json','r') as f:
    d = json.load(f)
print('ssl:', d['rest']['ssl'], '| baseUrl:', d['rest']['baseUrl'])
"
```

**Solución — parche Python post-build:**
```bash
docker exec dspace-ui python3 -c "
import json
with open('/app/dist/browser/assets/config.json','r') as f:
    d = json.load(f)
d['rest']['ssl'] = True
d['rest']['baseUrl'] = 'https://TU_IP/server'
with open('/app/dist/browser/assets/config.json','w') as f:
    json.dump(d, f)
print('Parche aplicado')
"
docker restart dspace-ui
```

El `setup.sh` aplica este parche automáticamente después de detectar que
el build terminó.

---

## Lección general

El `docker-compose.yml` oficial del repositorio de DSpace en GitHub
**no funciona directamente** con imágenes precompiladas de Docker Hub.
Está diseñado para desarrollo con código fuente local.

Este repositorio documenta lo que realmente funciona en producción universitaria.
