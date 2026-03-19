# DSpace 9 — Instalación con Docker Compose

> ✅ **Validado en producción universitaria.**
> Instalación real en Ubuntu 24.04 · 8 cores · 8 GB RAM.
> Incluye todos los errores encontrados y cómo resolverlos.

---

## Descripción

Esta guía explica cómo instalar **DSpace 9** usando **Docker Compose** en un servidor Ubuntu Server, pensada para administradores de sistemas universitarios, bibliotecarios digitales y equipos de TI que necesitan desplegar un repositorio institucional funcional sin instalar manualmente Java, PostgreSQL, Apache Solr ni Angular.

Incluye el `docker-compose.yml` definitivo con los errores de producción ya resueltos, scripts de instalación y limpieza, guías paso a paso desde cero (incluyendo la instalación de Docker), y un catálogo de los 8 errores más comunes con sus causas y soluciones exactas.

**Palabras clave:** DSpace 9 Docker, DSpace Docker Compose Ubuntu, instalar DSpace repositorio institucional, DSpace 9 producción, DSpace Angular SSR Docker, LOGGING_CONFIG DSpace Spring Boot, ssrBaseUrl DSpace config.yml, repositorio institucional open access Docker, DSpace 502 error, DSpace 500 Service unavailable.

---

## Arquitectura

```
Navegador del usuario
        │
   [NGINX :80/:443]
        ├── /server  ──────► [dspace :8080]      REST API (Spring Boot + Java)
        └── /        ──────► [dspace-ui :4000]   Frontend Angular (SSR)
                                    │                       │
                             [dspacesolr :8983]      [dspacedb :5432]
                              Apache Solr              PostgreSQL 16
```

---

## Requisitos del servidor

| Recurso  | Mínimo  | Probado con               |
|----------|---------|---------------------------|
| SO       | Ubuntu 22.04 o 24.04 LTS sin GUI | Ubuntu 24.04 LTS |
| CPU      | 2 núcleos | 8 núcleos               |
| RAM      | 6 GB    | 8 GB                      |
| Disco    | 40 GB   | 64 GB                     |

---

## Instalación rápida (si ya tienes Docker instalado)

### Opción A — Con Git instalado

```bash
git clone https://github.com/jsricaurte/dspace9-docker.git ~/dspace9
cd ~/dspace9
```

### Opción B — Sin Git (solo wget)

```bash
cd ~
wget https://github.com/jsricaurte/dspace9-docker/archive/refs/heads/main.zip
unzip main.zip
mv dspace9-docker-main dspace9
cd dspace9
```

> Si no tienes `wget` ni `unzip`: `sudo apt install -y wget unzip`

---

### Pasos comunes (para ambas opciones)

```bash
# Configurar
cp .env.example .env
nano .env              # ← edita IP, contraseña y nombre del repositorio

# Permisos
chmod +x setup.sh limpiar.sh

# Instalar
./setup.sh

# Cuando el frontend esté listo (15-25 min), crear administrador
./setup.sh create-admin
```

---

## Instalación completa desde cero (sin Docker)

Sigue las guías en orden:

| # | Guía | Contenido |
|---|------|-----------|
| 1 | [00-instalar-docker.md](00-instalar-docker.md) | Instalar Ubuntu Server + Docker + Docker Compose |
| 2 | [01-instalar-dspace.md](01-instalar-dspace.md) | Configurar e instalar DSpace 9 paso a paso |
| 3 | [ERRORES.md](ERRORES.md) | 8 errores reales con causas y soluciones |

---

## Estructura del repositorio

```
dspace9-docker/
├── docker-compose.yml     ← Orquestación de los 5 contenedores
├── .env.example           ← Plantilla de configuración (copiar a .env)
├── setup.sh               ← Instalación y gestión diaria
├── limpiar.sh             ← Limpieza total (⚠ borra datos)
├── nginx/
│   ├── nginx.conf         ← Proxy inverso con SSL
│   └── ssl/               ← setup.sh genera los certificados aquí
├── dspace-ui/
│   └── config.yml         ← Generado por setup.sh (no editar a mano)
├── 00-instalar-docker.md  ← Guía: instalar Ubuntu + Docker
├── 01-instalar-dspace.md  ← Guía: instalar DSpace paso a paso
└── ERRORES.md             ← 8 errores reales con soluciones
```

---

## Comandos disponibles

```bash
./setup.sh                # Instala y levanta DSpace
./setup.sh create-admin   # Crear administrador
./setup.sh status         # Estado de los contenedores
./setup.sh logs           # Logs en tiempo real
./setup.sh stop           # Apagar (datos se conservan)
./setup.sh restart        # Reiniciar
./setup.sh reindex        # Re-indexar en Solr

./limpiar.sh              # ⚠ Borra TODO — solo para empezar desde cero
```

---

## Tiempos de arranque

| Servicio | Primera vez | Siguientes |
|----------|------------|------------|
| PostgreSQL + Solr | ~30 seg | ~15 seg |
| DSpace API | 5–10 min | 1–2 min |
| Angular UI | 15–25 min | 1–2 min |

> El **502 Bad Gateway** en el primer arranque es normal.
> Espera hasta que `docker logs dspace-ui -f` muestre:
> `Server listening on http://0.0.0.0:4000`

---

## Errores críticos resueltos

| Error | Causa | Solución |
|-------|-------|---------|
| Spring Boot muere silenciosamente | Bug Log4j2 + Spring Boot 3.5.x | `LOGGING_CONFIG` en el compose |
| Error 500 permanente | SSR de Angular usa IP pública desde el contenedor | `ssrBaseUrl` en config.yml |
| Error 502 permanente | `proxy_pass` sin `/server` al final | Corrección en nginx.conf |
| `docker compose down` no baja todo | `restart: unless-stopped` | Cambiado a `restart: "no"` |
| Solr falla con error de `cp` | Compose oficial diseñado para desarrollo | Entrypoint sin comandos `cp` |
| Red interna no confiable | Subnet no alineada con proxies.trusted | Subnet fija `172.23.0.0/24` |

Ver detalles completos en [ERRORES.md](ERRORES.md).

---

## Versiones validadas

- **DSpace:** 9.3-SNAPSHOT (`dspace/dspace:dspace-9_x`)
- **PostgreSQL:** 16 Alpine
- **Solr:** `dspace/dspace-solr:dspace-9_x`
- **Angular UI:** `dspace/dspace-angular:dspace-9_x`
- **NGINX:** 1.25 Alpine

---

## ¿Por qué existe este repositorio?

El `docker-compose.yml` oficial de DSpace está diseñado para desarrollo con código fuente local — no funciona directamente con imágenes precompiladas de Docker Hub. No existe documentación sobre los errores críticos que aparecen en producción. Este repositorio documenta lo que realmente funcionó.
