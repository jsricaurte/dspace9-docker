# Guía 00 — Instalar Ubuntu Server + Docker + Docker Compose

> **Para quién:** alguien sin experiencia previa en servidores Linux.
> Sigue los pasos en orden. Cada paso depende del anterior.

---

## Parte 1 — Instalar Ubuntu Server 24.04 LTS

### Lo que necesitas

- Una máquina física o virtual (mínimo 6 GB RAM, 40 GB disco)
- Un pendrive USB de 4 GB o más
- La ISO de Ubuntu Server: https://ubuntu.com/download/server
- Software para grabar el pendrive:
  - **Windows:** Rufus — https://rufus.ie (gratuito)
  - **Mac / Linux:** Balena Etcher — https://etcher.balena.io (gratuito)

### Pasos

1. Descarga la ISO de Ubuntu Server 24.04 LTS
2. Graba la ISO en el pendrive con Rufus o Etcher
3. Conecta el pendrive al servidor y enciéndelo
4. Presiona **F12** (o F2, Escape, según el equipo) para entrar al menú de arranque
5. Selecciona arrancar desde el pendrive
6. En el menú de Ubuntu, selecciona **"Try or Install Ubuntu Server"**
7. **Idioma:** English (los comandos funcionan igual)
8. **Tipo de instalación:** Ubuntu Server (no la versión minimized)
9. **Red:** si tienes DHCP, se configura sola
10. **Disco:** Use entire disk → confirma el formateo
11. **Usuario:** crea un usuario (ejemplo: `admin`) y una contraseña segura
12. **Nombre del servidor:** ponle algo descriptivo (ejemplo: `dspace-server`)
13. **SSH:** marca ✓ **Install OpenSSH server** ← MUY IMPORTANTE
14. **Featured Snaps:** no selecciones nada, solo continúa
15. Espera que termine la instalación y reinicia cuando te lo pida

Después de reiniciar verás una pantalla negra con texto. **Eso es normal** — Ubuntu Server no tiene escritorio gráfico.

---

## Parte 2 — Conectarte por SSH desde tu computador

En vez de escribir en la pantalla del servidor, lo controlas desde tu computador.

### Conocer la IP del servidor

Inicia sesión en el servidor y ejecuta:
```bash
ip a | grep "inet " | grep -v 127
```
Busca una línea como `inet 192.168.1.xxx` — esa es la IP del servidor.

### Conectarte

**Desde Windows** — abre PowerShell o la aplicación "Terminal":
```
ssh tuusuario@192.168.1.xxx
```

**Desde Mac o Linux** — abre la Terminal:
```bash
ssh tuusuario@192.168.1.xxx
```

Escribe `yes` cuando pregunta por la huella digital, luego ingresa tu contraseña.

A partir de aquí trabajas desde la terminal de tu computador. No necesitas estar frente al servidor.

---

## Parte 3 — Instalar Docker

Ejecuta los siguientes comandos **uno por uno**. Espera que cada uno termine antes de ejecutar el siguiente.

### Paso 1 — Actualizar el sistema
```bash
sudo apt update && sudo apt upgrade -y
```
Este paso puede tardar varios minutos.

### Paso 2 — Instalar dependencias necesarias
```bash
sudo apt install -y ca-certificates curl gnupg lsb-release openssl nano git
```

### Paso 3 — Agregar la llave oficial de Docker
```bash
sudo install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

### Paso 4 — Agregar el repositorio de Docker
```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

### Paso 5 — Instalar Docker CE y el plugin Compose
```bash
sudo apt update

sudo apt install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
```

### Paso 6 — Verificar la instalación
```bash
sudo docker run hello-world
```
Si ves el mensaje `Hello from Docker!` — Docker está instalado correctamente.

---

## Parte 4 — Usar Docker sin sudo

Por defecto Docker requiere `sudo`. Estos pasos lo eliminan:

### Agregar tu usuario al grupo docker
```bash
sudo usermod -aG docker $USER
```

### Aplicar el cambio en la sesión actual
```bash
newgrp docker
```

### Verificar que funciona sin sudo
```bash
docker run hello-world
```
Debe funcionar sin pedir contraseña.

> **¿Por qué importa esto?**
> El `setup.sh` usa `docker compose` sin sudo.
> Si no haces este paso, el script falla con "permission denied".

---

## Parte 5 — Verificación final

Ejecuta los tres comandos. Todos deben mostrar una versión, no un error:

```bash
docker --version
```
Ejemplo de salida correcta: `Docker version 26.x.x`

```bash
docker compose version
```
Ejemplo de salida correcta: `Docker Compose version v2.x.x`

```bash
docker ps
```
Debe mostrar la tabla de encabezados vacía (sin contenedores corriendo).

---

## Problemas frecuentes

| Síntoma | Solución |
|---------|---------|
| `Permission denied` al usar docker | Ejecuta `newgrp docker` o cierra y reconecta por SSH |
| `curl: command not found` | Ejecuta `sudo apt install -y curl` |
| La instalación del paso 5 falla | Ejecuta `sudo apt update` y vuelve a intentarlo |
| No puedo conectarme por SSH | Verifica que el servidor está encendido y la IP es correcta |
| La IP del servidor cambia | Configura IP fija en tu router o sigue la guía de IP estática en Ubuntu |

---

## Siguiente paso

➡ Continúa con **[01-instalar-dspace.md](01-instalar-dspace.md)**
