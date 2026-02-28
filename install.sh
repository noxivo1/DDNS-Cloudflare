#!/bin/bash
# ============================================================
#  Instalador Cloudflare DDNS - Debian/Ubuntu
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/cloudflare-ddns"
LOG_FILE="/var/log/cloudflare-ddns.log"
SERVICE_NAME="cloudflare-ddns"

print_banner() {
    echo -e "${CYAN}"
    echo "  ╔══════════════════════════════════════════╗"
    echo "  ║     Cloudflare DDNS - Instalador         ║"
    echo "  ║     Debian / Ubuntu                      ║"
    echo "  ╚══════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "\n${BOLD}${YELLOW}▶ $1${NC}"
}

print_ok() {
    echo -e "  ${GREEN}✔ $1${NC}"
}

print_error() {
    echo -e "  ${RED}✘ $1${NC}"
}

# --- Verificar root ---
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Este instalador debe ejecutarse como root:${NC}"
    echo "  sudo bash install.sh"
    exit 1
fi

print_banner

# ============================================================
#  PASO 1: Instalar dependencias
# ============================================================
print_step "Verificando dependencias (curl, jq)..."

apt-get update -qq
for pkg in curl jq; do
    if ! command -v "$pkg" &>/dev/null; then
        echo -e "  Instalando ${pkg}..."
        apt-get install -y "$pkg" -qq
        print_ok "$pkg instalado"
    else
        print_ok "$pkg ya está instalado"
    fi
done

# ============================================================
#  PASO 2: Solicitar datos de configuración
# ============================================================
print_step "Configuración de Cloudflare"
echo ""
echo -e "  Necesito los siguientes datos de tu cuenta Cloudflare."
echo -e "  ${YELLOW}Puedes obtenerlos en: dash.cloudflare.com${NC}"
echo ""

# API Token
while true; do
    echo -e "  ${BOLD}1) API Token de Cloudflare${NC}"
    echo -e "     (Perfil → API Tokens → Crear token con permiso DNS:Edit)"
    read -rp "     Token: " CF_API_TOKEN
    CF_API_TOKEN="${CF_API_TOKEN// /}"  # quitar espacios

    if [ -z "$CF_API_TOKEN" ]; then
        print_error "El token no puede estar vacío."
        continue
    fi

    # Verificar token con la API
    echo -e "  Verificando token..."
    VERIFY=$(curl -s --max-time 10 \
        -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json")

    if echo "$VERIFY" | jq -r '.success' | grep -q "true"; then
        print_ok "Token válido."
        break
    else
        MSG=$(echo "$VERIFY" | jq -r '.errors[0].message' 2>/dev/null)
        print_error "Token inválido: ${MSG}. Inténtalo de nuevo."
    fi
done

echo ""

# Zone ID
while true; do
    echo -e "  ${BOLD}2) Zone ID de tu dominio${NC}"
    echo -e "     (En Cloudflare → tu dominio → panel derecho → Zone ID)"
    read -rp "     Zone ID: " CF_ZONE_ID
    CF_ZONE_ID="${CF_ZONE_ID// /}"

    if [ -z "$CF_ZONE_ID" ]; then
        print_error "El Zone ID no puede estar vacío."
        continue
    fi

    # Verificar que el Zone ID existe
    ZONE_CHECK=$(curl -s --max-time 10 \
        -X GET "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json")

    if echo "$ZONE_CHECK" | jq -r '.success' | grep -q "true"; then
        ZONE_NAME=$(echo "$ZONE_CHECK" | jq -r '.result.name')
        print_ok "Zona encontrada: ${ZONE_NAME}"
        break
    else
        print_error "Zone ID inválido o sin acceso. Inténtalo de nuevo."
    fi
done

echo ""

# Dominio / subdominio
while true; do
    echo -e "  ${BOLD}3) Dominio o subdominio a actualizar${NC}"
    echo -e "     Ejemplos: tvop.site  /  sub.tvop.site"
    read -rp "     Dominio: " CF_DOMAIN
    CF_DOMAIN="${CF_DOMAIN// /}"

    if [ -z "$CF_DOMAIN" ]; then
        print_error "El dominio no puede estar vacío."
        continue
    fi

    # Verificar que existe el registro A
    RECORD_CHECK=$(curl -s --max-time 10 \
        -X GET "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records?type=A&name=${CF_DOMAIN}" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json")

    RECORD_ID=$(echo "$RECORD_CHECK" | jq -r '.result[0].id')
    RECORD_IP=$(echo "$RECORD_CHECK" | jq -r '.result[0].content')

    if [ -z "$RECORD_ID" ] || [ "$RECORD_ID" == "null" ]; then
        print_error "No se encontró un registro A para '${CF_DOMAIN}'. ¿Existe en Cloudflare DNS?"
        read -rp "     ¿Intentar con otro dominio? [s/n]: " RETRY
        if [[ "$RETRY" =~ ^[Nn]$ ]]; then
            break
        fi
        continue
    fi

    print_ok "Registro A encontrado: ${CF_DOMAIN} → ${RECORD_IP}"
    break
done

echo ""

# Intervalo del cron (preconfigurado a 5 min pero preguntamos)
echo -e "  ${BOLD}4) Intervalo de actualización${NC}"
echo -e "     ¿Cada cuántos minutos revisar la IP?"
echo -e "     ${CYAN}[1] 5 min  [2] 10 min  [3] 15 min  [4] 30 min  [5] 60 min${NC}"
read -rp "     Opción [1-5] (por defecto: 1): " INTERVAL_OPT

case "$INTERVAL_OPT" in
    2) CRON_INTERVAL="*/10 * * * *" ; INTERVAL_LABEL="10 minutos" ;;
    3) CRON_INTERVAL="*/15 * * * *" ; INTERVAL_LABEL="15 minutos" ;;
    4) CRON_INTERVAL="*/30 * * * *" ; INTERVAL_LABEL="30 minutos" ;;
    5) CRON_INTERVAL="0 * * * *"    ; INTERVAL_LABEL="60 minutos" ;;
    *) CRON_INTERVAL="*/5 * * * *"  ; INTERVAL_LABEL="5 minutos"  ;;
esac

print_ok "Intervalo: ${INTERVAL_LABEL}"

# ============================================================
#  PASO 3: Guardar configuración
# ============================================================
print_step "Guardando configuración..."

mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"

cat > "${CONFIG_DIR}/config" <<EOF
# Cloudflare DDNS - Configuración
# Generado por install.sh el $(date '+%Y-%m-%d %H:%M:%S')
CF_API_TOKEN="${CF_API_TOKEN}"
CF_ZONE_ID="${CF_ZONE_ID}"
CF_DOMAIN="${CF_DOMAIN}"
EOF

chmod 600 "${CONFIG_DIR}/config"
print_ok "Configuración guardada en ${CONFIG_DIR}/config"

# ============================================================
#  PASO 4: Instalar script principal
# ============================================================
print_step "Instalando script principal..."

cp "$(dirname "$0")/cloudflare_ddns_update.sh" "${INSTALL_DIR}/cloudflare_ddns_update"
chmod +x "${INSTALL_DIR}/cloudflare_ddns_update"
print_ok "Script instalado en ${INSTALL_DIR}/cloudflare_ddns_update"

# Crear archivo de log
touch "$LOG_FILE"
chmod 644 "$LOG_FILE"
print_ok "Log en ${LOG_FILE}"

# ============================================================
#  PASO 5: Configurar systemd timer
# ============================================================
print_step "Configurando systemd timer..."

# Service
cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=Cloudflare DDNS Update - ${CF_DOMAIN}
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=${INSTALL_DIR}/cloudflare_ddns_update
StandardOutput=append:${LOG_FILE}
StandardError=append:${LOG_FILE}
EOF

# Timer
SYSTEMD_INTERVAL=""
case "$INTERVAL_OPT" in
    2) SYSTEMD_INTERVAL="10min" ;;
    3) SYSTEMD_INTERVAL="15min" ;;
    4) SYSTEMD_INTERVAL="30min" ;;
    5) SYSTEMD_INTERVAL="1h"    ;;
    *) SYSTEMD_INTERVAL="5min"  ;;
esac

cat > "/etc/systemd/system/${SERVICE_NAME}.timer" <<EOF
[Unit]
Description=Ejecutar Cloudflare DDNS cada ${INTERVAL_LABEL}
After=network-online.target

[Timer]
OnBootSec=2min
OnUnitActiveSec=${SYSTEMD_INTERVAL}
Unit=${SERVICE_NAME}.service

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now "${SERVICE_NAME}.timer"
print_ok "Systemd timer activo cada ${INTERVAL_LABEL}"

# ============================================================
#  PASO 6: También agregar cron como respaldo
# ============================================================
print_step "Configurando cron de respaldo..."

CRON_LINE="${CRON_INTERVAL} root ${INSTALL_DIR}/cloudflare_ddns_update >> ${LOG_FILE} 2>&1"
CRON_FILE="/etc/cron.d/cloudflare-ddns"

echo "$CRON_LINE" > "$CRON_FILE"
chmod 644 "$CRON_FILE"
print_ok "Cron instalado en ${CRON_FILE}"

# ============================================================
#  PASO 7: Primera ejecución
# ============================================================
print_step "Ejecutando primera actualización..."
"${INSTALL_DIR}/cloudflare_ddns_update"
echo ""

# ============================================================
#  RESUMEN FINAL
# ============================================================
echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║         ✔ Instalación completada         ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  ${BOLD}Dominio:${NC}    ${CF_DOMAIN}"
echo -e "  ${BOLD}Intervalo:${NC}  ${INTERVAL_LABEL}"
echo -e "  ${BOLD}Log:${NC}        ${LOG_FILE}"
echo ""
echo -e "  ${BOLD}Comandos útiles:${NC}"
echo -e "  ${CYAN}Ver logs:${NC}           tail -f ${LOG_FILE}"
echo -e "  ${CYAN}Estado del timer:${NC}   systemctl status ${SERVICE_NAME}.timer"
echo -e "  ${CYAN}Forzar update:${NC}      sudo cloudflare_ddns_update"
echo -e "  ${CYAN}Desinstalar:${NC}        sudo bash uninstall.sh"
echo ""
