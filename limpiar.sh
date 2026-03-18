#!/usr/bin/env bash
# =============================================================================
#  limpiar.sh — Elimina TODO Docker: contenedores, imágenes, volúmenes, redes
#
#  ⚠ ATENCIÓN: Este script BORRA LOS DATOS (base de datos, archivos subidos,
#  índices Solr). Úsalo SOLO cuando quieras empezar absolutamente desde cero.
#
#  Para un uso normal (apagar/encender) usa:
#    docker compose stop    ← apaga sin borrar datos
#    docker compose up -d   ← vuelve a encender
# =============================================================================

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; NC='\033[0m'

echo ""
echo -e "${RED}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║  ADVERTENCIA: Esto borrará TODOS los datos de DSpace.    ║${NC}"
echo -e "${RED}║  Base de datos, archivos subidos e índices de búsqueda.  ║${NC}"
echo -e "${RED}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
read -rp "Escribe 'CONFIRMAR' en mayúsculas para continuar: " CONFIRM

if [ "$CONFIRM" != "CONFIRMAR" ]; then
    echo -e "${GREEN}Operación cancelada. Nada fue borrado.${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}Limpiando Docker...${NC}"

docker compose down --remove-orphans 2>/dev/null || true
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm -f $(docker ps -aq) 2>/dev/null || true
docker system prune -af --volumes 2>/dev/null || true
docker network prune -f 2>/dev/null || true

echo ""
echo -e "${GREEN}Docker limpio. Contenedores, imágenes, volúmenes y redes eliminados.${NC}"
echo -e "${GREEN}Ejecuta ./setup.sh para empezar desde cero.${NC}"
echo ""
