#!/bin/bash
# ============================================================
#  Cloudflare DDNS Update
#  Actualiza el registro A en Cloudflare con la IP pública actual
# ============================================================

CONFIG_FILE="/etc/cloudflare-ddns/config"
LOG_FILE="/var/log/cloudflare-ddns.log"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "[ERROR] No se encontró la configuración. Ejecuta primero: sudo bash install.sh"
    exit 1
fi

source "$CONFIG_FILE"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

for cmd in curl jq; do
    if ! command -v "$cmd" &>/dev/null; then
        log "[ERROR] '$cmd' no está instalado. Instálalo con: sudo apt install $cmd"
        exit 1
    fi
done

CURRENT_IP=$(curl -s --max-time 10 https://api.ipify.org)

if [ -z "$CURRENT_IP" ]; then
    log "[ERROR] No se pudo obtener la IP pública. Verifica tu conexión."
    exit 1
fi

CF_RESPONSE=$(curl -s --max-time 10 \
    -X GET "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records?type=A&name=${CF_DOMAIN}" \
    -H "Authorization: Bearer ${CF_API_TOKEN}" \
    -H "Content-Type: application/json")

CF_SUCCESS=$(echo "$CF_RESPONSE" | jq -r '.success')

if [ "$CF_SUCCESS" != "true" ]; then
    log "[ERROR] Fallo al consultar Cloudflare: $(echo "$CF_RESPONSE" | jq -r '.errors[0].message')"
    exit 1
fi

CF_RECORD_ID=$(echo "$CF_RESPONSE" | jq -r '.result[0].id')
CF_RECORD_IP=$(echo "$CF_RESPONSE" | jq -r '.result[0].content')

if [ -z "$CF_RECORD_ID" ] || [ "$CF_RECORD_ID" == "null" ]; then
    log "[ERROR] No se encontró el registro A para ${CF_DOMAIN} en Cloudflare."
    exit 1
fi

if [ "$CURRENT_IP" == "$CF_RECORD_IP" ]; then
    log "[OK] IP sin cambios: ${CURRENT_IP}"
    exit 0
fi

log "[INFO] Cambio detectado: ${CF_RECORD_IP} → ${CURRENT_IP}. Actualizando..."

UPDATE_RESPONSE=$(curl -s --max-time 10 \
    -X PUT "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records/${CF_RECORD_ID}" \
    -H "Authorization: Bearer ${CF_API_TOKEN}" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"A\",\"name\":\"${CF_DOMAIN}\",\"content\":\"${CURRENT_IP}\",\"ttl\":120,\"proxied\":false}")

UPDATE_SUCCESS=$(echo "$UPDATE_RESPONSE" | jq -r '.success')

if [ "$UPDATE_SUCCESS" == "true" ]; then
    log "[OK] Registro actualizado: ${CF_DOMAIN} → ${CURRENT_IP}"
else
    log "[ERROR] Fallo al actualizar: $(echo "$UPDATE_RESPONSE" | jq -r '.errors[0].message')"
    exit 1
fi
