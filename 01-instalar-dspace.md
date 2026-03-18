# Guía 01 — Instalar DSpace 9

> **Requisito previo:** Docker instalado y funcionando.
> Si no lo tienes, ve primero a [00-instalar-docker.md](00-instalar-docker.md).

---

## Paso 1 — Descargar los archivos al servidor

### Opción A — Con Git instalado

```bash
git clone https://github.com/jsricaurte/dspace9-docker.git ~/dspace9
cd ~/dspace9
```

### Opción B — Sin Git (solo wget)

Si tienes Docker instalado pero no Git, descarga el repositorio como ZIP:

```bash
cd ~
wget https://github.com/jsricaurte/dspace9-docker/archive/refs/heads/main.zip
unzip main.zip
mv dspace9-docker-main dspace9
cd dspace9
```

> Si no tienes `wget` ni `unzip`: `sudo apt install -y wget unzip`

---

## Paso 2 — Verificar la estructura de archivos

```bash
ls -la
```

Debes ver exactamente esto:

```
dspace9/
├── docker-compose.yml
├── .env.example
├── setup.sh
├── limpiar.sh
├── nginx/
│   ├── nginx.conf
│   └── ssl/              ← vacía, el setup.sh genera los certificados aquí
├── dspace-ui/
│   └── config.yml        ← NO editar a mano, lo regenera setup.sh
└── docs/
    ├── 00-instalar-docker.md
    ├── 01-instalar-dspace.md   ← este archivo
    └── ERRORES.md
```

> ⚠️ Si `nginx.conf` o `config.yml` están en la raíz (no en sus subcarpetas),
> la instalación fallará. La estructura de carpetas es obligatoria.

---

## Paso 3 — Configurar el archivo .env

```bash
cp .env.example .env
nano .env
```

Verás esto:
```
POSTGRES_PASSWORD=CAMBIA_ESTA_CLAVE_AHORA
DSPACE_NAME=Repositorio Institucional Universidad
DSPACE_HOST=CAMBIA_POR_TU_IP_O_DOMINIO
```

Edita los tres valores:

**`POSTGRES_PASSWORD`** → una contraseña segura para la base de datos.
Ejemplo: `MiClave_Segura_2025`

**`DSPACE_NAME`** → el nombre oficial de tu repositorio.
Ejemplo: `Repositorio Institucional Universidad de Sabaneta`

**`DSPACE_HOST`** → la IP o dominio **tal como lo escribe el usuario en el navegador**.

Para conocer la IP de tu servidor:
```bash
ip a | grep "inet " | grep -v 127
```

Ejemplos válidos:
- IP red interna: `192.168.1.100`
- IP pública: `203.0.113.45`
- Dominio: `repositorio.universidad.edu.co`

Para guardar en nano: `Ctrl+O` → Enter → `Ctrl+X`

---

## Paso 4 — Dar permisos a los scripts

```bash
chmod +x setup.sh limpiar.sh
```

> ⚠️ Este paso se olvida con mucha frecuencia.
> Sin él el siguiente comando falla con "Permission denied".

---

## Paso 5 — Instalar

```bash
./setup.sh
```

El script hace automáticamente:
1. Verifica que Docker y el `.env` estén listos
2. Genera un certificado SSL auto-firmado (válido 10 años)
3. Genera `dspace-ui/config.yml` con tu IP/dominio
4. Descarga las imágenes Docker (puede tardar según la conexión)
5. Levanta los 5 contenedores

---

## Paso 6 — Esperar los tiempos de arranque

La primera vez que arranca, los tiempos son largos. Es completamente normal.

| Servicio | Primera vez | Arranques siguientes |
|----------|------------|----------------------|
| PostgreSQL + Solr | ~30 segundos | ~15 segundos |
| DSpace API (backend) | 5–10 minutos | 1–2 minutos |
| Angular UI (frontend) | 15–25 minutos | 1–2 minutos |

> **El mensaje "502 Bad Gateway" en el navegador durante este tiempo es NORMAL.**
> El sistema está iniciando. No cierres la terminal ni reinicies nada.

### Monitorear el progreso

Abre una segunda conexión SSH y ejecuta:

```bash
# Ver el backend:
docker logs dspace -f

# Ver el frontend:
docker logs dspace-ui -f
```

El sistema está listo cuando los logs de `dspace-ui` muestran:
```
Server listening on http://0.0.0.0:4000
```

---

## Paso 7 — Crear el administrador

Una vez que el frontend esté listo:

```bash
./setup.sh create-admin
```

El script pedirá:
```
Email       : admin@universidad.edu.co
Nombre      : Juan
Apellido    : Pérez
Contraseña  : (no se muestra al escribir, mínimo 8 caracteres)
Repite clave: (igual que antes)
```

---

## Paso 8 — Acceder a DSpace

Abre el navegador en:
```
https://TU_IP_O_DOMINIO
```

El navegador mostrará una advertencia de certificado no confiable porque usamos
un certificado auto-firmado. Haz clic en **"Avanzado"** → **"Continuar de todas formas"**.
Esto es normal en instalaciones de prueba.

Para ingresar como administrador:
1. Clic en **"Log In"** en la esquina superior derecha
2. Usa el email y contraseña creados en el paso anterior

---

## Verificar que todo funciona

```bash
./setup.sh status
```

Debes ver los 5 contenedores en estado **Up**:
```
NAME            STATUS
dspacedb        Up (healthy)
dspacesolr      Up
dspace          Up
dspace-ui       Up
dspace-nginx    Up
```

---

## Comandos del día a día

```bash
./setup.sh status        # Ver si los contenedores están corriendo
./setup.sh logs          # Ver logs de todos los contenedores
./setup.sh stop          # Apagar DSpace (los datos NO se pierden)
./setup.sh restart       # Reiniciar todos los contenedores
./setup.sh reindex       # Re-indexar si las búsquedas no funcionan
./setup.sh create-admin  # Crear otro administrador

./limpiar.sh             # ⚠ BORRA TODO — solo para empezar desde cero
```

---

## Problemas frecuentes

Si algo falla, consulta **[ERRORES.md](ERRORES.md)** — contiene los 8 errores
reales encontrados durante la instalación con sus causas y soluciones exactas.
