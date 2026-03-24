# DSpace 9 â Docker Compose para ProducciÃ³n

> â **Validado en un entorno universitario real.**
> Desplegado en Ubuntu 24.04 Â· 8 nÃºcleos Â· 8 GB RAM.
> Cada error que encontramos estÃ¡ documentado â con su soluciÃ³n exacta.

---

## Â¿QuÃ© es esto?

[DSpace](https://dspace.org/) es una de las plataformas open source mÃ¡s usadas en el mundo para crear y gestionar repositorios digitales institucionales. Universidades, bibliotecas y centros de investigaciÃ³n lo usan para publicar y preservar su producciÃ³n acadÃ©mica.

Este repositorio te da un **setup de Docker Compose listo para producciÃ³n con DSpace 9** â algo que oficialmente no existe. Las imÃ¡genes Docker que provee el equipo de DSpace estÃ¡n pensadas para desarrollo y pruebas locales, no para correr en un servidor real con IP pÃºblica, SSL y Nginx.

Lo construimos a las malas, chocamos contra todas las paredes posibles y documentamos todo para que tÃº no tengas que hacerlo.

---

## Â¿Por quÃ© Docker y no una instalaciÃ³n tradicional?

- **Portabilidad total** â mueve todo el repositorio entre servidores con un solo comando
- **Backups y migraciones** â lo que antes tomaba dÃ­as, ahora son minutos
- **MÃºltiples instancias en la misma mÃ¡quina** â corre varios entornos de DSpace en paralelo con diferentes configuraciones de Nginx, sin que se choquen
- **Rollbacks** â si algo falla, vuelves atrÃ¡s en segundos
- **Reproducibilidad** â el mismo setup funciona en cualquier servidor Linux

---

## Arquitectura

```
Navegador del usuario
        â
   [NGINX :80/:443]
   âââ /server âââââââº [dspace :8080]     REST API (Spring Boot + Java)
   âââ /       âââââââº [dspace-ui :4000]  Frontend Angular (SSR)
                              â
               ââââââââââââââââ
               â
   [dspacesolr :8983]        [dspacedb :5432]
    Apache Solr               PostgreSQL 16
```

---

## Requisitos del servidor

| Recurso | MÃ­nimo | Probado con |
|---------|--------|-------------|
| SO | Ubuntu 22.04 o 24.04 LTS sin GUI | Ubuntu 24.04 LTS |
| CPU | 2 nÃºcleos | 8 nÃºcleos |
| RAM | 6 GB | 8 GB |
| Disco | 40 GB | 64 GB |

---

## InstalaciÃ³n rÃ¡pida (si ya tienes Docker)

### OpciÃ³n A â Con Git

```bash
git clone https://github.com/jsricaurte/dspace9-docker.git ~/dspace9
cd ~/dspace9
```

### OpciÃ³n B â Sin Git (solo wget)

```bash
cd ~
wget https://github.com/jsricaurte/dspace9-docker/archive/refs/heads/main.zip
unzip main.zip
mv dspace9-docker-main dspace9
cd dspace9
```

> Â¿No tienes `wget` ni `unzip`? Ejecuta: `sudo apt install -y wget unzip`

---

### Pasos comunes (ambas opciones)

```bash
cp .env.example .env
nano .env        # â configura tu IP, contraseÃ±a y nombre del repositorio

chmod +x setup.sh limpiar.sh

./setup.sh       # Instala todo â la primera vez tarda ~40 min
```

El script `setup.sh`:
1. Genera la configuraciÃ³n de Nginx y el certificado SSL
2. Descarga las imÃ¡genes Docker
3. Levanta todos los contenedores
4. Muestra los logs de Angular en vivo en tu terminal
5. Cuando el build termina, pide tu contraseÃ±a `sudo` para instalar el servicio systemd
6. Aplica todos los parches automÃ¡ticamente

Cuando todo estÃ© listo, crea tu cuenta de administrador:

```bash
./setup.sh create-admin
```

---

## InstalaciÃ³n completa desde cero (sin Docker)

Sigue las guÃ­as en orden:

| # | GuÃ­a | Contenido |
|---|------|-----------|
| 1 | [00-instalar-docker.md](00-instalar-docker.md) | Instalar Ubuntu Server + Docker + Docker Compose |
| 2 | [01-instalar-dspace.md](01-instalar-dspace.md) | Configurar e instalar DSpace 9 paso a paso |
| 3 | [ERRORES.md](ERRORES.md) | 12+ errores reales de producciÃ³n con causas y soluciones exactas |

---

## Estructura del repositorio

```
dspace9-docker/
âââ docker-compose.yml      â Orquesta los 5 contenedores
âââ .env.example            â Plantilla de configuraciÃ³n (copiar a .env)
âââ setup.sh                â Script principal de instalaciÃ³n y gestiÃ³n
âââ limpiar.sh              â Limpieza total (â  borra todos los datos)
âââ dspace-patch.sh         â Script de parches post-arranque (SSL + i18n)
âââ dspace-patch.service    â Servicio systemd para parches permanentes
âââ nginx/
â   âââ nginx.conf          â Proxy inverso con SSL
â   âââ ssl/                â Certificados generados por setup.sh
âââ dspace-ui/
â   âââ config.yml          â Generado por setup.sh (no editar a mano)
âââ 00-instalar-docker.md   â GuÃ­a: instalar Ubuntu + Docker
âââ 01-instalar-dspace.md   â GuÃ­a: instalar DSpace paso a paso
âââ ERRORES.md              â 12+ errores reales con soluciones
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
./limpiar.sh             # â  Borra TODO â solo para empezar desde cero
```

---

## Tiempos de arranque

| Servicio | Primera vez | Siguientes |
|---------|------------|------------|
| PostgreSQL + Solr | ~30 seg | ~15 seg |
| DSpace REST API | 5â10 min | 1â2 min |
| Angular UI | ~40 min (build) | 1â2 min |

> El **502 Bad Gateway** en el primer arranque es completamente normal.
> Espera a que el build de Angular termine.
> Monitorea el progreso con: `docker logs dspace-ui -f`

---

## Errores crÃ­ticos resueltos

| Error | Causa | SoluciÃ³n |
|-------|-------|---------|
| Spring Boot muere silenciosamente | Bug Log4j2 + Spring Boot 3.5.x | `LOGGING_CONFIG` en el compose |
| Error 500 permanente | SSR de Angular intenta usar la IP pÃºblica desde dentro del contenedor | `ssrBaseUrl` en config.yml |
| Error 502 permanente | `proxy_pass` sin `/server` al final | CorrecciÃ³n en nginx.conf |
| `docker compose down` no para todo | PolÃ­tica de restart incorrecta | Ajustada en el compose |
| Solr falla con error `cp` | El compose oficial estÃ¡ diseÃ±ado para desarrollo con cÃ³digo fuente | Entrypoint sin comandos `cp` |
| Red interna no confiable | Subnet no alineada con `proxies.trusted` | Subnet fija `172.23.0.0/24` |
| SSR de Angular rechaza IPs | PolÃ­tica de seguridad de Angular SSR bloquea hostnames que no son dominio | Fallback a CSR + parche post-arranque |
| `config.json` siempre con `ssl: false` | El build de producciÃ³n embebe el valor en tiempo de compilaciÃ³n | Parche Python aplicado por servicio systemd en cada arranque |
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

## Â¿Por quÃ© existe este repositorio?

El setup oficial de Docker de DSpace estÃ¡ pensado para desarrolladores trabajando con cÃ³digo fuente local â nunca fue diseÃ±ado para correr imÃ¡genes de producciÃ³n directamente desde Docker Hub. No existe documentaciÃ³n oficial que cubra los errores reales que aparecen al desplegar en un servidor real.

Este repositorio existe porque alguien tuvo que averiguarlo, documentar cada falla y compartir lo que realmente funcionÃ³. Si te ahorra una semana de depuraciÃ³n, ese es exactamente el punto.

---

## Contribuciones

Â¿Encontraste un error o tienes una mejora? Los PRs son bienvenidos.
Si esto te ayudÃ³ a desplegar DSpace en tu instituciÃ³n, deja una â­ â ayuda a que otros lo encuentren.

---

*Hecho con cabezonerÃ­a y demasiadas noches. â [@jsricaurte](https://github.com/jsricaurte)*
