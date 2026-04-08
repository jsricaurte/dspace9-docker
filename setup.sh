#!/usr/bin/env bash
# =============================================================================
#  setup.sh - DSpace 9 con Docker Compose
#  https://github.com/jsricaurte/dspace9-docker
#
#  Uso:
#    ./setup.sh                - instala y levanta todo
#    ./setup.sh create-admin   - crea la cuenta de administrador
#    ./setup.sh status         - estado de los contenedores
#    ./setup.sh logs           - logs en tiempo real (Ctrl+C para salir)
#    ./setup.sh stop           - detiene contenedores (datos se conservan)
#    ./setup.sh restart        - reinicia contenedores
#    ./setup.sh reindex        - re-indexa contenido en Solr
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
titulo()  { echo -e "\n${BOLD}=== $1 ===${NC}\n"; }

COMPOSE="docker compose"

# =============================================================================
# VERIFICAR REQUISITOS
# =============================================================================
check_requisitos() {
    command -v docker >/dev/null 2>&1 \
        || error "Docker no esta instalado. Sigue la guia: 00-instalar-docker.md"
    docker compose version >/dev/null 2>&1 \
        || error "El plugin 'docker compose' no esta instalado."
    [ -f ".env" ] \
        || error "Falta el archivo .env - ejecuta: cp .env.example .env && nano .env"
    grep -q "CAMBIA_" .env \
        && error "Edita el .env antes de continuar. Reemplaza los valores CAMBIA_... por los tuyos."
    success "Docker y .env listos."
}

# =============================================================================
# INSTALACION
# =============================================================================
do_install() {
    titulo "Instalando DSpace 9"
    check_requisitos

    DSPACE_HOST_VAL=$(grep "^DSPACE_HOST=" .env | cut -d= -f2 | tr -d ' ')

    # -- 1. Generar nginx/nginx.conf
    info "Generando nginx/nginx.conf..."
    mkdir -p nginx/ssl
    cat > nginx/nginx.conf << 'NGINXEOF'
events { worker_connections 1024; }
http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    sendfile on;
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
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
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

    # -- 2. Certificado SSL auto-firmado
    if [ ! -f "nginx/ssl/server.crt" ] || [ ! -f "nginx/ssl/server.key" ]; then
        info "Generando certificado SSL auto-firmado (valido 10 anos)..."
        openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
            -keyout nginx/ssl/server.key \
            -out nginx/ssl/server.crt \
            -subj "/C=CO/O=Universidad/CN=${DSPACE_HOST_VAL}" \
            -addext "subjectAltName=IP:${DSPACE_HOST_VAL}" 2>/dev/null \
        || openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
            -keyout nginx/ssl/server.key \
            -out nginx/ssl/server.crt \
            -subj "/C=CO/O=Universidad/CN=${DSPACE_HOST_VAL}" 2>/dev/null
        success "Certificado SSL generado."
    else
        success "Certificado SSL ya existe, se reutiliza."
    fi

    # -- 3. config.yml para Angular SSR
    info "Generando dspace-ui/config.yml..."
    mkdir -p dspace-ui
    cat > dspace-ui/config.yml << EOF
rest:
  ssl: true
  host: ${DSPACE_HOST_VAL}
  port: 443
  nameSpace: /server
  ssrBaseUrl: http://dspace:8080/server

ssr:
  replaceRestUrl: true
  enableSearchComponent: false
  enableBrowseComponent: false
  excludePathPatterns:
    - pattern: ".*"
EOF
    success "dspace-ui/config.yml generado con host: ${DSPACE_HOST_VAL}"

    # -- 3b. Borrar volumen angular_dist previo si existe
    info "Eliminando volumen angular_dist previo si existe..."
    docker volume rm $(docker volume ls -q | grep angular_dist) 2>/dev/null || true

    # -- 4. Descargar imagenes Docker
    info "Descargando imagenes Docker (puede tardar segun la conexion)..."
    $COMPOSE pull

    # -- 5. Levantar contenedores
    info "Levantando contenedores..."
    $COMPOSE up -d

    echo ""
    echo -e "${BOLD}${GREEN}================================================${NC}"
    echo -e "${BOLD}${GREEN}  DSpace 9 iniciando...                        ${NC}"
    echo -e "${BOLD}${GREEN}================================================${NC}"
    echo ""
    echo -e "${YELLOW}Tiempos de arranque (primera vez):${NC}"
    echo -e "  PostgreSQL + Solr:  ~30 segundos"
    echo -e "  DSpace API:         5-10 minutos  (migracion de base de datos)"
    echo -e "  Angular UI:         25-40 minutos (compilacion inicial en modo produccion)"
    echo ""
    warn "El '502 Bad Gateway' en estos primeros minutos es NORMAL."
    echo ""
    echo -e "Monitorear backend:  ${BLUE}docker logs dspace -f${NC}"
    echo -e "Monitorear frontend: ${BLUE}docker logs dspace-ui -f${NC}"
    echo ""
    echo -e "Cuando este listo:   ${GREEN}https://${DSPACE_HOST_VAL}${NC}"
    echo ""
    info "Siguiente paso - crea el administrador con: ./setup.sh create-admin"
    echo ""

    # -- 6. Esperar build de Angular y aplicar parches
    echo ""
    echo -e "${BOLD}${YELLOW}"
    echo "        ( ("
    echo "         ) )"
    echo "      ........"
    echo "      |      |]"
    echo "      \\      /"
    echo "       \`----'"
    echo -e "${NC}"
    echo -e "${YELLOW}  El cafe esta listo. Ahora a esperar...            ${NC}"
    echo -e "${YELLOW}  Angular UI tarda ~40 min en compilar.             ${NC}"
    echo -e "${YELLOW}  El servidor NO se congelo. No cierres esto.       ${NC}"
    echo -e "${YELLOW}  Pon musica, ve por mas tinto, o toma una siesta.  ${NC}"
    echo ""
    info "Logs de Angular en vivo (el progreso aparece aqui abajo)..."
    docker logs dspace-ui -f 2>/dev/null &
    LOGS_PID=$!
    until docker logs dspace-ui 2>/dev/null | grep -q "Listening at http://localhost:4000"; do
        sleep 10
    done
    kill $LOGS_PID 2>/dev/null || true
    echo ""
    echo -e "${GREEN}  Listo. Angular compilo. El cafe te supo bien.  ${NC}"
    echo ""
    echo ""
    success "Build de Angular completado."
    echo ""
    info "Instalando servicio systemd y aplicando parches..."
    INSTALL_DIR="$(pwd)"
    chmod +x dspace-patch.sh
    sed "s|INSTALL_DIR|$INSTALL_DIR|g" dspace-patch.service | sudo tee /etc/systemd/system/dspace-patch.service > /dev/null
    sudo systemctl daemon-reload
    sudo systemctl enable dspace-patch.service
    bash dspace-patch.sh
    success "Parches aplicados. DSpace listo en https://${DSPACE_HOST_VAL}"
}

# =============================================================================
# CREAR ADMINISTRADOR
# =============================================================================
do_create_admin() {
    titulo "Crear Administrador de DSpace 9"
    docker ps --filter "name=^dspace$" --filter "status=running" --format "{{.Names}}" \
        | grep -q "^dspace$" \
        || error "El contenedor 'dspace' no esta corriendo. Ejecuta primero: ./setup.sh"
    echo -e "Ingresa los datos del administrador:\n"
    read -rp "  Email     : " ADMIN_EMAIL
    read -rp "  Nombre    : " ADMIN_FIRST
    read -rp "  Apellido  : " ADMIN_LAST
    read -rsp "  Contrasena: " ADMIN_PASS; echo ""
    read -rsp "  Repite    : " ADMIN_PASS2; echo ""
    [ "$ADMIN_PASS" = "$ADMIN_PASS2" ] \
        || error "Las contrasenas no coinciden."
    [ ${#ADMIN_PASS} -ge 8 ] \
        || error "La contrasena debe tener al menos 8 caracteres."
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
        || error "El contenedor 'dspace' no esta corriendo."
    info "Puede tardar varios minutos..."
    docker exec dspace /dspace/bin/dspace index-discovery -b
    success "Re-indexacion completada."
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
        echo "" ;;
esac
