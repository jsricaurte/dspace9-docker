# DSpace 9 — Docker Compose para Producción

> ✅ **Validado en un entorno universitario real.**
> Desplegado en Ubuntu 24.04 · 8 núcleos · 8 GB RAM.
> Cada error que encontramos está documentado — con su solución exacta.

---

## ¿Qué es esto?

[DSpace](https://dspace.org/) es una de las plataformas open source más usadas en el mundo para crear y gestionar repositorios digitales institucionales. Universidades, bibliotecas y centros de investigación lo usan para publicar y preservar su producción académica.

Este repositorio te da un **setup de Docker Compose listo para producción con DSpace 9** — algo que oficialmente no existe. Las imágenes Docker que provee el equipo de DSpace están pensadas para desarrollo y pruebas locales, no para correr en un servidor real con IP pública, SSL y Nginx.

Lo construimos a las malas, chocamos contra todas las paredes posibles y documentamos todo para que tú no tengas que hacerlo.

---

## ¿Por qué Docker y no una instalación tradicional?

- **Portabilidad total** — mueve todo el repositorio entre servidores con un solo comando
- **Backups y migraciones** — lo que antes tomaba días, ahora son minutos
- **Múltiples instancias en la misma máquina** — corre varios entornos de DSpace en paralelo con diferentes configuraciones de Nginx, sin que se choquen
- **Rollbacks** — si algo falla, vuelves atrás en segundos
- **Reproducibilidad** — el mismo setup funciona en cualquier servidor Linux

---

## Arquitectura

```
Navegador del usuario
        │
   [NGINX :80/:443]
   ├── /server ──────► [dspace :8080]     REST API (Spring Boot + Java)
   └── /       ──────► [dspace-ui :4000]  Frontend Angular (SSR)
                              │
               ┌──────────────┘
               │
   [dspacesolr :8983]        [dspacedb :5432]
    Apache Solr               PostgreSQL 16
```

---

## Requisitos del servidor

| Recurso | Mínimo | Probado con |
|---------|--------|-------------|
| SO | Ubuntu 22.04 o 24.04 LTS sin GUI | Ubuntu 24.04 LTS |
| CPU | 2 núcleos | 8 núcleos |
| RAM | 6 GB | 8 GB |
| Disco | 40 GB | 64 GB |

---

## Instalación rápida (si ya tienes Docker)

### Opción A — Con Git

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

> ¿No tienes `wget` ni `unzip`? Ejecuta: `sudo apt install -y wget unzip`

---

### Pasos comunes (ambas opciones)

```bash
cp .env.example .env
nano .env        # ← configura tu IP, contraseña y nombre del repositorio

chmod +x setup.sh limpiar.sh

./setup.sh       # Instala todo — la primera vez tarda ~40 min
```

El script `setup.sh`:
1. Genera la configuración de Nginx y el certificado SSL
2. Descarga las imágenes Docker
3. Levanta todos los contenedores
4. Muestra los logs de Angular en vivo en tu terminal
5. Cuando el build termina, pide tu contraseña `sudo` para instalar el servicio systemd
6. Aplica todos los parches automáticamente

Cuando todo esté listo, crea tu cuenta de administrador:

```bash
./setup.sh create-admin
```

---

## Instalación completa desde cero (sin Docker)

Sigue las guías en orden:

| # | Guía | Contenido |
|---|------|-----------|
| 1 | [00-instalar-docker.md](00-instalar-docker.md) | Instalar Ubuntu Server + Docker + Docker Compose |
| 2 | [01-instalar-dspace.md](01-instalar-dspace.md) | Configurar e instalar DSpace 9 paso a paso |
| 3 | [ERRORES.md](ERRORES.md) | 12+ errores reales de producción con causas y soluciones exactas |

---

## Estructura del repositorio

```
dspace9-docker/
├── docker-compose.yml      ← Orquesta los 5 contenedores
├── .env.example            ← Plantilla de configuración (copiar a .env)
├── setup.sh                ← Script principal de instalación y gestión
├── limpiar.sh              ← Limpieza total (⚠ borra todos los datos)
├── dspace-patch.sh         ← Script de parches post-arranque (SSL + i18n)
├── dspace-patch.service    ← Servicio systemd para parches permanentes
├── nginx/
│   ├── nginx.conf          ← Proxy inverso con SSL
│   └── ssl/                ← Certificados generados por setup.sh
├── dspace-ui/
│   └── config.yml          ← Generado por setup.sh (no editar a mano)
├── 00-instalar-docker.md   ← Guía: instalar Ubuntu + Docker
├── 01-instalar-dspace.md   ← Guía: instalar DSpace paso a paso
└── ERRORES.md              ← 12+ errores reales con soluciones
```

---

## Comandos disponibles

```bash
./setup.sh               # Instala y levanta DSpace
./setup.sh create-admin  # Crear cuenta de administrador
./setup.sh status        # Estado de los contenedores
./setup.sh logs          # Logs en tiempo real (Ctrl+C para salir)
./setup.sh stop          # Apagar (datos se conservan)
./setup.sh restart       # Reiniciar contenedores
./setup.sh reindex       # Re-indexar contenido en Solr
./limpiar.sh             # ⚠ Borra TODO — solo para empezar desde cero
```

---

## Tiempos de arranque

| Servicio | Primera vez | Siguientes |
|---------|------------|------------|
| PostgreSQL + Solr | ~30 seg | ~15 seg |
| DSpace REST API | 5–10 min | 1–2 min |
| Angular UI | ~40 min (build) | 1–2 min |

> El **502 Bad Gateway** en el primer arranque es completamente normal.
> Espera a que el build de Angular termine.
> Monitorea el progreso con: `docker logs dspace-ui -f`

---

## Errores críticos resueltos

| Error | Causa | Solución |
|-------|-------|---------|
| Spring Boot muere silenciosamente | Bug Log4j2 + Spring Boot 3.5.x | `LOGGING_CONFIG` en el compose |
| Error 500 permanente | SSR de Angular intenta usar la IP pública desde dentro del contenedor | `ssrBaseUrl` en config.yml |
| Error 502 permanente | `proxy_pass` sin `/server` al final | Corrección en nginx.conf |
| `docker compose down` no para todo | Política de restart incorrecta | Ajustada en el compose |
| Solr falla con error `cp` | El compose oficial está diseñado para desarrollo con código fuente | Entrypoint sin comandos `cp` |
| Red interna no confiable | Subnet no alineada con `proxies.trusted` | Subnet fija `172.23.0.0/24` |
| SSR de Angular rechaza IPs | Política de seguridad de Angular SSR bloquea hostnames que no son dominio | Fallback a CSR + parche post-arranque |
| `config.json` siempre con `ssl: false` | El build de producción embebe el valor en tiempo de compilación | Parche Python aplicado por servicio systemd en cada arranque |
| Traducciones i18n no cargan | Hash del build no coincide entre los bundles de Angular | El parche copia los archivos i18n con los hashes correctos al arrancar |

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

El setup oficial de Docker de DSpace está pensado para desarrolladores trabajando con código fuente local — nunca fue diseñado para correr imágenes de producción directamente desde Docker Hub. No existe documentación oficial que cubra los errores reales que aparecen al desplegar en un servidor real.

Este repositorio existe porque alguien tuvo que averiguarlo, documentar cada falla y compartir lo que realmente funcionó. Si te ahorra una semana de depuración, ese es exactamente el punto.

---

## Contribuciones

¿Encontraste un error o tienes una mejora? Los PRs son bienvenidos.
Si esto te ayudó a desplegar DSpace en tu institución, deja una ⭐ — ayuda a que otros lo encuentren.

---

*Hecho con cabezonería y demasiadas noches. — [@jsricaurte](https://github.com/jsricaurte)*
