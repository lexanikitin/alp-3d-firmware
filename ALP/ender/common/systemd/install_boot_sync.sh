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

echo "===================================================================="
echo "🚀 [Alpaca 3D Farm] Установка службы alp-firmware-sync.service"
echo "===================================================================="

# 1. Обеспечение совместимости симлинка
if [ -d "/home/aniki/alp-klipper-printers" ] && [ ! -e "/home/aniki/alp-3d-firmware" ]; then
    echo "🔗 Создание симлинка alp-3d-firmware -> alp-klipper-printers..."
    ln -s /home/aniki/alp-klipper-printers /home/aniki/alp-3d-firmware
elif [ -d "/home/aniki/alp-3d-firmware" ] && [ ! -e "/home/aniki/alp-klipper-printers" ]; then
    echo "🔗 Создание симлинка alp-klipper-printers -> alp-3d-firmware..."
    ln -s /home/aniki/alp-3d-firmware /home/aniki/alp-klipper-printers
fi

# 2. Права на исполнение скрипта
chmod +x "${SCRIPT_DIR}/sync_firmware_on_boot.sh"

# 3. Копирование и регистрация systemd службы
cp "${SCRIPT_DIR}/alp-firmware-sync.service" /etc/systemd/system/alp-firmware-sync.service
systemctl daemon-reload
systemctl enable alp-firmware-sync.service

echo "🔍 Проверка тестового прогона службы..."
sudo -u aniki bash "${SCRIPT_DIR}/sync_firmware_on_boot.sh"

echo "===================================================================="
echo "✅ Служба alp-firmware-sync успешно установлена и активирована!"
echo "   Статус службы: systemctl status alp-firmware-sync"
echo "   Лог запусков:  journalctl -u alp-firmware-sync"
echo "===================================================================="
