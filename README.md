# DSpace 9 — Instalación con Docker Compose

> ✅ **Validado en producción universitaria.**
> Instalación real en Ubuntu 24.04 · 8 cores · 8 GB RAM.
> Incluye todos los errores encontrados y cómo resolverlos.

---

## Descripción

Esta guía explica cómo instalar **DSpace 9** usando **Docker Compose** en un servidor Ubuntu Server sin experiencia previa. Está pensada para administradores de sistemas universitarios, bibliotecarios digitales y equipos de TI que necesitan desplegar un repositorio institucional funcional sin instalar manualmente Java, PostgreSQL, Apache Solr ni Angular.

El repositorio incluye el `docker-compose.yml` definitivo con los errores de producción ya resueltos, scripts de instalación y limpieza, guías paso a paso desde cero (incluyendo la instalación de Docker), y un catálogo de los 8 errores más comunes con sus causas y soluciones exactas.

**Palabras clave:** DSpace 9 Docker, DSpace Docker Compose Ubuntu, instalar DSpace repositorio institucional, DSpace 9 producción, DSpace Angular SSR Docker, LOGGING_CONFIG DSpace Spring Boot, ssrBaseUrl DSpace config.yml, repositorio institucional open access Docker, DSpace 502 error, DSpace 500 Service unavailable.

---

---

## ¿Qué es DSpace?

DSpace es el software de repositorio institucional más usado en universidades
del mundo. Permite gestionar, preservar y dar acceso abierto a tesis, artículos,
libros y cualquier producción académica de la institución.

Esta guía usa **Docker** para simplificar la instalación — sin instalar
manualmente Java, PostgreSQL, Solr ni Angular.

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

```bash
# 1. Clonar
git clone https://github.com/jsricaurte/dspace9-docker.git ~/dspace9
cd ~/dspace9

# 2. Configurar
cp .env.example .env
nano .env              # ← edita IP, contraseña y nombre del repositorio

# 3. Permisos
chmod +x setup.sh limpiar.sh

# 4. Instalar
./setup.sh

# 5. Cuando el frontend esté listo (15-25 min), crear administrador
./setup.sh create-admin
```

---

## Instalación completa desde cero (sin Docker)

Sigue las guías en orden:

| # | Guía | Contenido |
|---|------|-----------|
| 1 | [docs/00-instalar-docker.md](docs/00-instalar-docker.md) | Instalar Ubuntu Server + Docker + Docker Compose |
| 2 | [docs/01-instalar-dspace.md](docs/01-instalar-dspace.md) | Configurar e instalar DSpace 9 paso a paso |
| 3 | [docs/ERRORES.md](docs/ERRORES.md) | 8 errores reales con causas y soluciones |

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
└── docs/
    ├── 00-instalar-docker.md
    ├── 01-instalar-dspace.md
    └── ERRORES.md
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

> El **502 Bad Gateway** durante el primer arranque es normal.
> Espera hasta que `docker logs dspace-ui -f` muestre:
> `Server listening on http://0.0.0.0:4000`

---

## Errores críticos resueltos

Esta configuración resuelve problemas que no están documentados en otros tutoriales:

| Error | Causa | Solución |
|-------|-------|---------|
| Spring Boot muere silenciosamente | Bug Log4j2 + Spring Boot 3.5.x | `LOGGING_CONFIG` en el compose |
| Error 500 permanente | SSR de Angular usa IP pública desde dentro del contenedor | `ssrBaseUrl` en config.yml |
| Error 502 permanente | `proxy_pass` sin ruta `/server` | Corrección en nginx.conf |
| `docker compose down` no baja todo | `restart: unless-stopped` | Cambiado a `restart: "no"` |
| Solr falla con error de `cp` | Compose oficial diseñado para desarrollo | Entrypoint sin comandos `cp` |

Ver detalles completos en [docs/ERRORES.md](docs/ERRORES.md).

---

## Versiones validadas

- **DSpace:** 9.3-SNAPSHOT (`dspace/dspace:dspace-9_x`)
- **PostgreSQL:** 16 Alpine
- **Solr:** `dspace/dspace-solr:dspace-9_x`
- **Angular UI:** `dspace/dspace-angular:dspace-9_x`
- **NGINX:** 1.25 Alpine

---

## ¿Por qué existe este repositorio?

Durante la instalación en producción encontramos que:
- El `docker-compose.yml` oficial de DSpace **no funciona** con imágenes precompiladas
- No existe documentación sobre los errores comunes con Docker en producción
- Los tutoriales disponibles omiten detalles críticos como `LOGGING_CONFIG` y `ssrBaseUrl`

Este repositorio documenta lo que realmente funcionó.
