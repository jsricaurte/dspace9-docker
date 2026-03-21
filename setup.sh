#!/usr/bin/env bash
# =============================================================================
#  setup.sh ÃÂÃÂ¢ÃÂÃÂÃÂÃÂ DSpace 9 con Docker Compose
#  https://github.com/jsricaurte/dspace9-docker
#
#  Uso:
#    ./setup.sh                ÃÂÃÂ¢ÃÂÃÂÃÂÃÂ instala y levanta todo
#    ./setup.sh create-admin   ÃÂÃÂ¢ÃÂÃÂÃÂÃÂ crea la cuenta de administrador
#    ./setup.sh status         ÃÂÃÂ¢ÃÂÃÂÃÂÃÂ estado de los contenedores
#    ./setup.sh logs           ÃÂÃÂ¢ÃÂÃÂÃÂÃÂ logs en tiempo real (Ctrl+C para salir)
#    ./setup.sh stop           ÃÂÃÂ¢ÃÂÃÂÃÂÃÂ detiene contenedores (datos se conservan)
#    ./setup.sh restart        ÃÂÃÂ¢ÃÂÃÂÃÂÃÂ reinicia contenedores
#    ./setup.sh reindex        ÃÂÃÂ¢ÃÂÃÂÃÂÃÂ re-indexa contenido en Solr
#
#  Para limpiar TODO y empezar desde cero: ./limpiar.sh
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}   $1"; }
success() { echo -e "${GREEN}[OK]${NC}     $1"; }
warn()    { echo -e "${YELLOW}[AVISO]${NC}  $1"; }
error()   { echo -e "${RED}[ERROR]${NC}  $1"; exit 1; }
titulo()  { echo -e "\n${BOLD}ÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂ $1 ÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂ${NC}\n"; }

COMPOSE="docker compose"

# =============================================================================
# VERIFICAR REQUISITOS
# =============================================================================
check_requisitos() {
    command -v docker >/dev/null 2>&1 \
        || error "Docker no estÃÂÃÂÃÂÃÂ¡ instalado. Sigue la guÃÂÃÂÃÂÃÂ­a: 00-instalar-docker.md"

    docker compose version >/dev/null 2>&1 \
        || error "El plugin 'docker compose' no estÃÂÃÂÃÂÃÂ¡ instalado."

    [ -f ".env" ] \
        || error "Falta el archivo .env ÃÂÃÂ¢ÃÂÃÂÃÂÃÂ ejecuta: cp .env.example .env && nano .env"

    grep -q "CAMBIA_" .env \
        && error "Edita el .env antes de continuar. Reemplaza los valores CAMBIA_... por los tuyos."

    success "Docker y .env listos."
}

# =============================================================================
# INSTALACIÃÂÃÂÃÂÃÂN
# =============================================================================
do_install() {
    titulo "Instalando DSpace 9"
    check_requisitos

    DSPACE_HOST_VAL=$(grep "^DSPACE_HOST=" .env | cut -d= -f2 | tr -d ' ')

    # ÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂ 1. Generar nginx/nginx.conf ÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂ
    # El setup.sh genera este archivo directamente para garantizar que
    # siempre estÃÂÃÂÃÂÃÂ© en la ubicaciÃÂÃÂÃÂÃÂ³n correcta sin depender del repo descargado.
    info "Generando nginx/nginx.conf..."
    mkdir -p nginx/ssl
    cat > nginx/nginx.conf << 'NGINXEOF'
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    sendfile      on;
    keepalive_timeout 65;
    client_max_body_size 512M;

    server {
        listen 80;
        server_name _;
        return 301 https://$host$request_uri;
    }

    server {
        listen 443 ssl;
        server_name _;

        ssl_certificate     /etc/nginx/ssl/server.crt;
        ssl_certificate_key /etc/nginx/ssl/server.key;
        ssl_protocols       TLSv1.2 TLSv1.3;
        ssl_ciphers         HIGH:!aNULL:!MD5;

        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        location /server {
            proxy_pass          http://dspace:8080/server;
            proxy_read_timeout  300s;
            proxy_connect_timeout 300s;
            proxy_send_timeout  300s;
        }

        location / {
            proxy_pass         http://dspace-ui:4000;
            proxy_read_timeout 120s;
        }
    }
}
NGINXEOF
    success "nginx/nginx.conf generado."

    # ÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂ 2. Certificado SSL auto-firmado ÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂ
    if [ ! -f "nginx/ssl/server.crt" ] || [ ! -f "nginx/ssl/server.key" ]; then
        info "Generando certificado SSL auto-firmado (vÃÂÃÂÃÂÃÂ¡lido 10 aÃÂÃÂÃÂÃÂ±os)..."
        openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
            -keyout nginx/ssl/server.key \
            -out    nginx/ssl/server.crt \
            -subj   "/C=CO/O=Universidad/CN=${DSPACE_HOST_VAL}" \
            -addext "subjectAltName=IP:${DSPACE_HOST_VAL}" 2>/dev/null \
        || openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
            -keyout nginx/ssl/server.key \
            -out    nginx/ssl/server.crt \
            -subj   "/C=CO/O=Universidad/CN=${DSPACE_HOST_VAL}" 2>/dev/null
        success "Certificado SSL generado."
    else
        success "Certificado SSL ya existe, se reutiliza."
    fi

    # ÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂ 3. config.yml para Angular SSR ÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂ
    # ssl: true  ÃÂÃÂ¢ÃÂÃÂÃÂÃÂ el navegador usa HTTPS para contactar el backend
    # ssrBaseUrl ÃÂÃÂ¢ÃÂÃÂÃÂÃÂ el servidor Node (SSR) usa la red interna Docker
    # Sin ssrBaseUrl ÃÂÃÂ¢ÃÂÃÂÃÂÃÂ error 500 permanente (IP pÃÂÃÂÃÂÃÂºblica inaccesible desde contenedor)
    info "Generando dspace-ui/config.yml..."
    mkdir -p dspace-ui
    cat > dspace-ui/config.yml << EOF
# config.yml ÃÂÃÂ¢ÃÂÃÂÃÂÃÂ DSpace Angular UI
# Generado automÃÂÃÂÃÂÃÂ¡ticamente por setup.sh ÃÂÃÂ¢ÃÂÃÂÃÂÃÂ no editar a mano.
# Para cambiar la IP: edita .env y vuelve a ejecutar ./setup.sh

rest:
  ssl: true
  host: ${DSPACE_HOST_VAL}
  port: 443
  nameSpace: /server
  ssrBaseUrl: http://dspace:8080/server

ssr:
  replaceRestUrl: true
EOF
    success "dspace-ui/config.yml generado con host: ${DSPACE_HOST_VAL}"

    # ÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂ 3b. Borrar volumen angular_dist para garantizar build limpio
  info "Eliminando volumen angular_dist previo si existe..."
  docker volume rm $(docker volume ls -q | grep angular_dist) 2>/dev/null || true

  # 4. Descargar imÃÂÃÂÃÂÃÂ¡genes ÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂ
    info "Descargando imÃÂÃÂÃÂÃÂ¡genes Docker (puede tardar segÃÂÃÂÃÂÃÂºn la conexiÃÂÃÂÃÂÃÂ³n)..."
    $COMPOSE pull

    # ÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂ 5. Levantar ÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂ
    info "Levantando contenedores..."
    $COMPOSE up -d

    echo ""
    echo -e "${BOLD}${GREEN}ÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂ${NC}"
    echo -e "${BOLD}${GREEN}ÃÂÃÂ¢ÃÂÃÂÃÂÃÂ   DSpace 9 iniciando...                      ÃÂÃÂ¢ÃÂÃÂÃÂÃÂ${NC}"
    echo -e "${BOLD}${GREEN}ÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂ${NC}"
    echo ""
    echo -e "${YELLOW}Tiempos de arranque (primera vez):${NC}"
    echo -e "  PostgreSQL + Solr:  ~30 segundos"
    echo -e "  DSpace API:         5-10 minutos  (migraciÃÂÃÂÃÂÃÂ³n de base de datos)"
    echo -e "  Angular UI:         25-40 minutos (compilaciÃÂÃÂÃÂÃÂ³n inicial en modo producciÃÂÃÂÃÂÃÂ³n)"
    echo ""
    warn "El '502 Bad Gateway' en estos primeros minutos es NORMAL."
    echo ""
    echo -e "Monitorear backend:  ${BLUE}docker logs dspace -f${NC}"
    echo -e "Monitorear frontend: ${BLUE}docker logs dspace-ui -f${NC}"
    echo ""
    echo -e "Cuando estÃÂÃÂÃÂÃÂ© listo:   ${GREEN}https://${DSPACE_HOST_VAL}${NC}"
    echo ""
    info "Siguiente paso ÃÂÃÂ¢ÃÂÃÂÃÂÃÂ crea el administrador con:  ./setup.sh create-admin"
    echo ""

  # -- 6. Instalar servicio systemd para parches post-reinicio --
  info "Instalando servicio systemd de parches..."
  INSTALL_DIR="$(pwd)"
  chmod +x dspace-patch.sh
  sed "s|INSTALL_DIR|$INSTALL_DIR|g" dspace-patch.service | sudo tee /etc/systemd/system/dspace-patch.service > /dev/null
  sudo systemctl daemon-reload
  sudo systemctl enable dspace-patch.service
  sudo systemctl start dspace-patch.service
  success "Servicio systemd instalado. Los parches se aplicaran automaticamente."
}

# =============================================================================
# CREAR ADMINISTRADOR
# =============================================================================
do_create_admin() {
    titulo "Crear Administrador de DSpace 9"

    docker ps --filter "name=^dspace$" --filter "status=running" --format "{{.Names}}" \
        | grep -q "^dspace$" \
        || error "El contenedor 'dspace' no estÃÂÃÂÃÂÃÂ¡ corriendo. Ejecuta primero: ./setup.sh"

    echo -e "Ingresa los datos del administrador:\n"
    read -rp  "  Email       : " ADMIN_EMAIL
    read -rp  "  Nombre      : " ADMIN_FIRST
    read -rp  "  Apellido    : " ADMIN_LAST
    read -rsp "  ContraseÃÂÃÂÃÂÃÂ±a  : " ADMIN_PASS;  echo ""
    read -rsp "  Repite clave: " ADMIN_PASS2; echo ""

    [ "$ADMIN_PASS" = "$ADMIN_PASS2" ] \
        || error "Las contraseÃÂÃÂÃÂÃÂ±as no coinciden."
    [ ${#ADMIN_PASS} -ge 8 ] \
        || error "La contraseÃÂÃÂÃÂÃÂ±a debe tener al menos 8 caracteres."

    info "Creando administrador..."
    docker exec dspace /dspace/bin/dspace create-administrator \
        -e "$ADMIN_EMAIL" \
        -f "$ADMIN_FIRST" \
        -l "$ADMIN_LAST" \
        -p "$ADMIN_PASS" \
        -c en

    echo ""
    success "Administrador creado: ${ADMIN_EMAIL}"
    DSPACE_HOST_VAL=$(grep "^DSPACE_HOST=" .env | cut -d= -f2 | tr -d ' ')
    echo -e "Accede en: ${GREEN}https://${DSPACE_HOST_VAL}/login${NC}"
}

# =============================================================================
# RE-INDEXAR SOLR
# =============================================================================
do_reindex() {
    titulo "Re-indexando contenido en Solr"
    docker ps --filter "name=^dspace$" --filter "status=running" --format "{{.Names}}" \
        | grep -q "^dspace$" \
        || error "El contenedor 'dspace' no estÃÂÃÂÃÂÃÂ¡ corriendo."
    info "Puede tardar varios minutos..."
    docker exec dspace /dspace/bin/dspace index-discovery -b
    success "Re-indexaciÃÂÃÂÃÂÃÂ³n completada."
}

# =============================================================================
# ESTADO / LOGS / STOP / RESTART
# =============================================================================
do_status()  { titulo "Estado de los contenedores"; $COMPOSE ps; }
do_logs()    { info "Mostrando logs (Ctrl+C para salir)..."; $COMPOSE logs -f --tail=100; }
do_stop()    { titulo "Deteniendo DSpace 9"; $COMPOSE stop; success "Detenido. Datos conservados."; }
do_restart() { titulo "Reiniciando DSpace 9"; $COMPOSE restart; success "Listo."; }

# =============================================================================
# DISPATCHER
# =============================================================================
case "${1:-install}" in
    install)       do_install ;;
    create-admin)  do_create_admin ;;
    reindex)       do_reindex ;;
    status)        do_status ;;
    logs)          do_logs ;;
    stop)          do_stop ;;
    restart)       do_restart ;;
    *)
        echo ""
        echo -e "${BOLD}Uso:${NC} $0 [comando]"
        echo ""
        echo "  (sin argumento)  Instala y levanta DSpace 9"
        echo "  create-admin     Crea la cuenta de administrador"
        echo "  reindex          Re-indexa contenido en Solr"
        echo "  status           Estado de los contenedores"
        echo "  logs             Logs en tiempo real"
        echo "  stop             Detener (datos se conservan)"
        echo "  restart          Reiniciar"
        echo ""
        echo "  Para limpiar TODO: ./limpiar.sh"
        echo ""
        ;;
esac
