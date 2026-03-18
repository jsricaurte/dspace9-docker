# Errores encontrados y soluciones — DSpace 9 con Docker

> Todos estos errores ocurrieron durante una instalación universitaria real.
> Cada uno incluye el síntoma exacto, la causa raíz y la solución validada.

---

## Error 1 — Spring Boot muere silenciosamente (solo aparece el banner ASCII)

**Síntoma:**
```
docker logs dspace

  .   ____          _            __ _ _
 /\\ / ___'_ __ _ _(_)_ __  __ _ \ \ \ \
 :: Spring Boot ::  (v3.5.11)
```
Solo el banner. Sin ningún mensaje de error. Exit code 1.
`docker ps` no muestra el contenedor `dspace`.

**Causa:**
Spring Boot 3.5.x tiene un bug con Log4j2: durante la inicialización,
Log4j2 intenta leer propiedades de Spring, Spring llama a Log4j2 de vuelta,
generando un bucle recursivo que mata el proceso antes de loguear nada.

**Solución — variable `LOGGING_CONFIG` en el servicio dspace:**
```yaml
environment:
  LOGGING_CONFIG: /dspace/config/log4j2-container.xml
```
Este archivo ya existe dentro de la imagen. Apuntarle con esa variable
rompe el ciclo y Spring Boot arranca normalmente.

---

## Error 2 — Error 500 "Service unavailable" permanente

**Síntoma:**
La interfaz carga parcialmente pero muestra:
```
500 — Service unavailable
The server is temporarily unable to service your request...
```
El backend responde, los contenedores están Up, pero la página no carga.

**Causa:**
Angular usa SSR (Server Side Rendering): renderiza la página en el servidor
Node ANTES de enviarla al navegador. Durante ese proceso, Node intenta
contactar el backend usando la IP pública (ej. `192.168.1.100`), pero
esa IP no es accesible desde dentro del contenedor Docker.

Confirmación del problema:
```bash
docker exec dspace-ui cat /app/config/config.yml
# Mostraba: host: sandbox.dspace.org  (hardcodeado en la imagen)
```

**Solución — `ssrBaseUrl` en `dspace-ui/config.yml`:**
```yaml
rest:
  ssl: false
  host: 192.168.1.100       # ← IP pública (para el navegador del usuario)
  port: 443
  nameSpace: /server
  ssrBaseUrl: http://dspace:8080/server  # ← nombre Docker interno (para el SSR)

ssr:
  replaceRestUrl: true      # ← reemplaza URLs internas antes de llegar al browser
```
El `setup.sh` genera este archivo automáticamente con la IP de tu `.env`.

> **Nota sobre SEO:** `ssrBaseUrl` preserva el SSR completo. La alternativa
> de deshabilitar SSR sacrifica el SEO — no fue necesaria.

---

## Error 3 — 502 Bad Gateway permanente (no temporal)

**Síntoma:**
Después de 30+ minutos nginx devuelve 502. Todos los contenedores están Up.

**Causa:**
`proxy_pass` al backend sin la ruta `/server` al final:
```nginx
# INCORRECTO
location /server {
    proxy_pass http://dspace:8080;   # ← falta /server
}
```

**Solución:**
```nginx
# CORRECTO
location /server {
    proxy_pass http://dspace:8080/server;   # ← con /server
}
```

---

## Error 4 — `docker compose down` no baja todos los contenedores

**Síntoma:**
```bash
docker compose down
docker ps   # ← siguen corriendo nginx y dspace-ui
```

**Causa:**
La política `restart: unless-stopped` hace que Docker reinicie los
contenedores automáticamente, incluso después de un `compose down`.

**Solución:**
Cambiar a `restart: "no"` en todos los servicios:
```yaml
restart: "no"
```
Cuando se necesite que los contenedores sobrevivan reinicios del servidor,
se puede cambiar a `restart: unless-stopped` en producción estable.

---

## Error 5 — Solr falla con "cp: cannot stat... No such file"

**Síntoma:**
```
cp: cannot stat '/opt/solr/server/solr/configsets/authority': No such file
```
El contenedor `dspacesolr` se reinicia en loop.

**Causa:**
El `docker-compose.yml` oficial de GitHub de DSpace incluye comandos `cp`
para copiar configsets desde el código fuente local. Con imágenes
precompiladas de Docker Hub esos archivos locales no existen.

**Solución:**
Eliminar los comandos `cp`. Las imágenes precompiladas ya incluyen los
configsets internamente. Solo se necesita `precreate-core`:
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

**Síntoma:**
```bash
docker exec dspace ps aux
# PID 1: /bin/bash -c while (! /dev/tcp/dspacedb/5432)...
# PID xxx: sleep 1
```
El contenedor lleva 10+ minutos en ese bucle. PostgreSQL está Up y healthy.

**Causa:**
La sintaxis `/dev/tcp/` falla silenciosamente dentro de la imagen DSpace:
```bash
# NO funciona en esta imagen:
while (! /dev/tcp/dspacedb/5432) > /dev/null 2>&1; do sleep 1; done
```

**Solución:**
Usar la sintaxis correcta con redirección explícita:
```bash
while ! (echo > /dev/tcp/dspacedb/5432) 2>/dev/null; do sleep 3; done
```

---

## Error 7 — nginx no arranca: "No such file or directory"

**Síntoma:**
```
nginx: [emerg] open() "/etc/nginx/nginx.conf" failed (2: No such file)
```

**Causa:**
Los archivos estaban en la raíz del proyecto en lugar de sus subcarpetas.

**Solución — estructura obligatoria:**
```
proyecto/
├── nginx/
│   └── nginx.conf        ← AQUÍ, no en la raíz
└── dspace-ui/
    └── config.yml        ← AQUÍ, no en la raíz
```

---

## Error 8 — 502 Bad Gateway durante los primeros 15-25 minutos

**Este NO es un error.** Es comportamiento normal.

Angular compila la aplicación completa en el primer arranque.
Ese proceso tarda 15-25 minutos.

**Cómo saber cuándo está listo:**
```bash
docker logs dspace-ui -f
```

Cuando veas esta línea, el sistema está completamente listo:
```
Server listening on http://0.0.0.0:4000
```

---

## Lección general

El `docker-compose.yml` oficial del repositorio de DSpace en GitHub
**no funciona directamente** con imágenes precompiladas de Docker Hub.
Está diseñado para desarrollo con código fuente local.

Este repositorio documenta lo que realmente funciona en producción.
