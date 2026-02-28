#!/bin/bash
# ============================================================
#  Desinstalador - Cloudflare DDNS
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Ejecuta como root: sudo bash uninstall.sh${NC}"
    exit 1
fi

echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║     Cloudflare DDNS - Desinstalador      ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${YELLOW}¿Seguro que quieres desinstalar Cloudflare DDNS? [s/N]:${NC} "
read -r CONFIRM
if [[ ! "$CONFIRM" =~ ^[Ss]$ ]]; then
    echo "Cancelado."
    exit 0
fi

echo ""

# Detener y deshabilitar timer
if systemctl is-active --quiet cloudflare-ddns.timer 2>/dev/null; then
    systemctl stop cloudflare-ddns.timer
    systemctl disable cloudflare-ddns.timer
    echo -e "  ${GREEN}✔ Timer detenido${NC}"
fi

# Eliminar archivos systemd
rm -f /etc/systemd/system/cloudflare-ddns.service
rm -f /etc/systemd/system/cloudflare-ddns.timer
systemctl daemon-reload
echo -e "  ${GREEN}✔ Archivos systemd eliminados${NC}"

# Eliminar cron
rm -f /etc/cron.d/cloudflare-ddns
echo -e "  ${GREEN}✔ Cron eliminado${NC}"

# Eliminar script
rm -f /usr/local/bin/cloudflare_ddns_update
echo -e "  ${GREEN}✔ Script eliminado${NC}"

# Eliminar configuración
rm -rf /etc/cloudflare-ddns
echo -e "  ${GREEN}✔ Configuración eliminada${NC}"

# Preguntar si eliminar logs
echo ""
read -rp "  ¿Eliminar también los logs (/var/log/cloudflare-ddns.log)? [s/N]: " DEL_LOG
if [[ "$DEL_LOG" =~ ^[Ss]$ ]]; then
    rm -f /var/log/cloudflare-ddns.log
    echo -e "  ${GREEN}✔ Log eliminado${NC}"
fi

echo ""
echo -e "  ${GREEN}${BOLD}Desinstalación completada.${NC}"
echo ""
