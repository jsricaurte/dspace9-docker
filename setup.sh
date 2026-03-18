#!/usr/bin/env bash
# =============================================================================
#  setup.sh — DSpace 9 con Docker Compose
#
#  Qué hace este script:
#    1. Verifica que Docker y el .env estén listos
#    2. Genera el certificado SSL auto-firmado (si no existe)
#    3. Genera dspace-ui/config.yml con la IP real de tu .env
#    4. Descarga las imágenes Docker
#    5. Levanta los contenedores
#
#  Comandos disponibles:
#    ./setup.sh                → instala y levanta todo
#    ./setup.sh create-admin   → crea la cuenta de administrador
#    ./setup.sh status         → estado de los contenedores
#    ./setup.sh logs           → logs en tiempo real (Ctrl+C para salir)
#    ./setup.sh stop           → detiene contenedores (datos se conservan)
#    ./setup.sh restart        → reinicia contenedores
#    ./setup.sh reindex        → re-indexa contenido en Solr
#
#  Para limpiar TODO y empezar desde cero: ./limpiar.sh
# =============================================================================

set -euo pipefail

# ── Colores ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}   $1"; }
success() { echo -e "${GREEN}[OK]${NC}     $1"; }
warn()    { echo -e "${YELLOW}[AVISO]${NC}  $1"; }
error()   { echo -e "${RED}[ERROR]${NC}  $1"; exit 1; }
titulo()  { echo -e "\n${BOLD}═══ $1 ═══${NC}\n"; }

COMPOSE="docker compose"

# =============================================================================
# VERIFICAR REQUISITOS
# =============================================================================
check_requisitos() {
    command -v docker >/dev/null 2>&1 \
        || error "Docker no está instalado. Sigue la guía en docs/00-instalar-docker.md"

    docker compose version >/dev/null 2>&1 \
        || error "El plugin 'docker compose' no está instalado."

    [ -f ".env" ] \
        || error "Falta el archivo .env — ejecuta: cp .env.example .env && nano .env"

    # Verificar que se editaron los valores por defecto
    grep -q "CAMBIA_" .env \
        && error "Edita el .env antes de continuar. Cambia los valores CAMBIA_... por los tuyos."

    success "Docker instalado y .env configurado."
}

# =============================================================================
# INSTALACIÓN PRINCIPAL
# =============================================================================
do_install() {
    titulo "Instalando DSpace 9"
    check_requisitos

    # Leer IP/dominio del .env
    DSPACE_HOST_VAL=$(grep "^DSPACE_HOST=" .env | cut -d= -f2 | tr -d ' ')

    # ── 1. Certificado SSL ──────────────────────────────────────────────────
    mkdir -p nginx/ssl
    if [ ! -f "nginx/ssl/server.crt" ] || [ ! -f "nginx/ssl/server.key" ]; then
        info "Generando certificado SSL auto-firmado (válido 10 años)..."
        # Intentar con SAN (para IPs), si falla hacer sin SAN (para dominios)
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

    # ── 2. config.yml para Angular SSR ─────────────────────────────────────
    # CRÍTICO: ssrBaseUrl le dice al servidor Node (SSR) que use la red
    # interna Docker en vez de la IP pública (inaccesible desde el contenedor).
    # Sin ssrBaseUrl → error 500 "Service unavailable" permanente.
    # Con ssrBaseUrl → SSR funciona Y el SEO se preserva (replaceRestUrl: true
    # garantiza que las URLs internas no llegan al navegador del usuario).
    info "Generando dspace-ui/config.yml con host: ${DSPACE_HOST_VAL}..."
    mkdir -p dspace-ui
    cat > dspace-ui/config.yml << EOF
# config.yml — DSpace Angular UI
# Generado automáticamente por setup.sh — no editar a mano.
# Para cambiar la IP/dominio: edita .env y re-ejecuta ./setup.sh

rest:
  ssl: false
  host: ${DSPACE_HOST_VAL}
  port: 443
  nameSpace: /server
  # ssrBaseUrl: URL que usa el servidor Node internamente para el SSR.
  # DEBE ser el nombre del contenedor Docker, no la IP pública.
  ssrBaseUrl: http://dspace:8080/server

ssr:
  # replaceRestUrl: reemplaza las URLs internas del SSR por la URL pública
  # antes de enviar la página al navegador. Preserva el SEO.
  replaceRestUrl: true
EOF
    success "dspace-ui/config.yml generado."

    # ── 3. Descargar imágenes ───────────────────────────────────────────────
    info "Descargando imágenes Docker (puede tardar según la conexión)..."
    $COMPOSE pull

    # ── 4. Levantar ────────────────────────────────────────────────────────
    info "Levantando contenedores..."
    $COMPOSE up -d

    echo ""
    echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${GREEN}║   DSpace 9 iniciando...                  ║${NC}"
    echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Tiempos de arranque (primera vez):${NC}"
    echo -e "  PostgreSQL + Solr:  ~30 segundos"
    echo -e "  DSpace API:         5-10 minutos  (migración de base de datos)"
    echo -e "  Angular UI:         15-25 minutos (compilación inicial)"
    echo ""
    warn "El error '502 Bad Gateway' en estos primeros minutos es NORMAL."
    warn "Espera hasta ver en los logs: 'Server listening on http://0.0.0.0:4000'"
    echo ""
    echo -e "Monitorear backend:  ${BLUE}docker logs dspace -f${NC}"
    echo -e "Monitorear frontend: ${BLUE}docker logs dspace-ui -f${NC}"
    echo ""
    echo -e "Cuando esté listo:   ${GREEN}https://${DSPACE_HOST_VAL}${NC}"
    echo ""
    info "Siguiente paso: crea el administrador con  ./setup.sh create-admin"
}

# =============================================================================
# CREAR ADMINISTRADOR
# =============================================================================
do_create_admin() {
    titulo "Crear Administrador de DSpace 9"

    # Verificar que el backend está corriendo
    docker ps --filter "name=^dspace$" --filter "status=running" --format "{{.Names}}" \
        | grep -q "^dspace$" \
        || error "El contenedor 'dspace' no está corriendo. Ejecuta primero: ./setup.sh"

    echo -e "Ingresa los datos del administrador:\n"
    read -rp "  Email       : " ADMIN_EMAIL
    read -rp "  Nombre      : " ADMIN_FIRST
    read -rp "  Apellido    : " ADMIN_LAST
    read -rsp "  Contraseña  : " ADMIN_PASS; echo ""
    read -rsp "  Repite clave: " ADMIN_PASS2; echo ""

    [ "$ADMIN_PASS" = "$ADMIN_PASS2" ] \
        || error "Las contraseñas no coinciden. Vuelve a intentarlo."
    [ ${#ADMIN_PASS} -ge 8 ] \
        || error "La contraseña debe tener al menos 8 caracteres."

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
    info "Puede tardar varios minutos según el volumen de contenido..."
    docker exec dspace /dspace/bin/dspace index-discovery -b
    success "Re-indexación completada."
}

# =============================================================================
# ESTADO
# =============================================================================
do_status() {
    titulo "Estado de los contenedores"
    $COMPOSE ps
}

# =============================================================================
# LOGS
# =============================================================================
do_logs() {
    info "Mostrando logs (Ctrl+C para salir)..."
    $COMPOSE logs -f --tail=100
}

# =============================================================================
# DETENER
# =============================================================================
do_stop() {
    titulo "Deteniendo DSpace 9"
    $COMPOSE stop
    success "Contenedores detenidos. Los datos persisten en los volúmenes Docker."
    info "Para volver a arrancar:  docker compose up -d"
}

# =============================================================================
# REINICIAR
# =============================================================================
do_restart() {
    titulo "Reiniciando DSpace 9"
    $COMPOSE restart
    success "Reiniciado."
}

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
        echo "  (sin comando)   Instala y levanta DSpace 9"
        echo "  create-admin    Crea la cuenta de administrador"
        echo "  reindex         Re-indexa contenido en Solr"
        echo "  status          Estado de los contenedores"
        echo "  logs            Logs en tiempo real"
        echo "  stop            Detener contenedores"
        echo "  restart         Reiniciar contenedores"
        echo ""
        echo "Para limpiar TODO: ./limpiar.sh"
        echo ""
        ;;
esac
