# 🌐 Cloudflare DDNS - Actualización de IP Dinámica

Actualiza automáticamente el registro DNS tipo A en Cloudflare cuando tu IP pública cambia.  
Diseñado para **Debian / Ubuntu**. Usa `systemd timer` + `cron` como respaldo.

---

## ✅ Requisitos

- Debian 10+ o Ubuntu 20.04+
- Acceso `root` o `sudo`
- Dominio configurado en Cloudflare con un registro **A** existente
- Token de API de Cloudflare con permisos `Zone:Read` y `DNS:Edit`

---

## 🚀 Instalación rápida

```bash
git clone https://github.com/noxivo1/DDNS-Cloudflare.git
cd DDNS-Cloudflare
sudo bash install.sh
```

El instalador te pedirá:

| Dato | Dónde encontrarlo |
|------|-------------------|
| **API Token** | [dash.cloudflare.com](https://dash.cloudflare.com) → Perfil → API Tokens |
| **Zone ID** | Panel de tu dominio en Cloudflare → columna derecha |
| **Dominio** | El dominio o subdominio con el registro A (ej: `tvop.site`) |
| **Intervalo** | Cada cuántos minutos revisar la IP (5, 10, 15, 30 o 60) |

> ⚠️ **Nunca compartas tu API Token.** Si lo expones accidentalmente, revócalo de inmediato en el panel de Cloudflare.

---

## 📁 Archivos instalados

| Ruta | Descripción |
|------|-------------|
| `/usr/local/bin/cloudflare_ddns_update` | Script principal |
| `/etc/cloudflare-ddns/config` | Configuración (protegida, solo root) |
| `/var/log/cloudflare-ddns.log` | Registro de actualizaciones |
| `/etc/systemd/system/cloudflare-ddns.*` | Servicio y timer de systemd |
| `/etc/cron.d/cloudflare-ddns` | Cron de respaldo |

---

## 🛠️ Comandos útiles

```bash
# Ver logs en tiempo real
tail -f /var/log/cloudflare-ddns.log

# Forzar una actualización manual
sudo cloudflare_ddns_update

# Ver estado del timer
systemctl status cloudflare-ddns.timer

# Ver próxima ejecución
systemctl list-timers cloudflare-ddns.timer
```

---

## 🗑️ Desinstalar

```bash
sudo bash uninstall.sh
```

---

## 📋 Ejemplo de log

```
[2025-01-15 10:00:01] [OK] IP sin cambios: 85.123.45.67
[2025-01-15 10:05:01] [INFO] Cambio detectado: 85.123.45.67 → 85.123.45.99. Actualizando...
[2025-01-15 10:05:02] [OK] Registro actualizado: tvop.site → 85.123.45.99
```

---

## 📄 Licencia

MIT
