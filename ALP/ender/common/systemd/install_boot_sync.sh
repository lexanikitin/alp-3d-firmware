#!/usr/bin/env bash
# ==============================================================================
# Alpaca 3D Farm — Установщик службы автосинхронизации прошивки при загрузке
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: скрипт должен быть запущен с правами root (sudo $0)" >&2
    exit 1
fi

TARGET_USER="${SUDO_USER:-$(stat -c '%U' "${SCRIPT_DIR}")}"
if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
    TARGET_USER="aniki"
fi
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

echo "===================================================================="
echo "🚀 [Alpaca 3D Farm] Установка службы alp-firmware-sync.service (${TARGET_USER})"
echo "===================================================================="

# 1. Обеспечение совместимости симлинка
if [ -d "${TARGET_HOME}/alp-klipper-printers" ] && [ ! -e "${TARGET_HOME}/alp-3d-firmware" ]; then
    echo "🔗 Создание симлинка alp-3d-firmware -> alp-klipper-printers..."
    ln -s "${TARGET_HOME}/alp-klipper-printers" "${TARGET_HOME}/alp-3d-firmware"
elif [ -d "${TARGET_HOME}/alp-3d-firmware" ] && [ ! -e "${TARGET_HOME}/alp-klipper-printers" ]; then
    echo "🔗 Создание симлинка alp-klipper-printers -> alp-3d-firmware..."
    ln -s "${TARGET_HOME}/alp-3d-firmware" "${TARGET_HOME}/alp-klipper-printers"
fi

# 2. Права на исполнение скрипта
chmod +x "${SCRIPT_DIR}/sync_firmware_on_boot.sh"

# 3. Генерация и регистрация systemd службы под целевого пользователя
sed -e "s|User=aniki|User=${TARGET_USER}|g" \
    -e "s|Group=aniki|Group=${TARGET_USER}|g" \
    -e "s|/home/aniki|${TARGET_HOME}|g" \
    "${SCRIPT_DIR}/alp-firmware-sync.service" > /etc/systemd/system/alp-firmware-sync.service
systemctl daemon-reload
systemctl enable alp-firmware-sync.service

echo "🔍 Проверка тестового прогона службы..."
sudo -u "${TARGET_USER}" HOME="${TARGET_HOME}" bash "${SCRIPT_DIR}/sync_firmware_on_boot.sh"

echo "===================================================================="
echo "✅ Служба alp-firmware-sync успешно установлена и активирована!"
echo "   Статус службы: systemctl status alp-firmware-sync"
echo "   Лог запусков:  journalctl -u alp-firmware-sync"
echo "===================================================================="
