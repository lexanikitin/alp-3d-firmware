#!/usr/bin/env bash
# ==============================================================================
# Alpaca 3D Farm — KlipperScreen & Real-Time Isolation Installer for Ender C
# ==============================================================================
# Скрипт развертывания единого сенсорного интерфейса KlipperScreen на хосте Ender C
# с жестким разграничением ресурсов CPU/RAM (FMEA & RT Safety).
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_HOME="/home/aniki"
CONFIG_DIR="${USER_HOME}/printer_data/config"

echo "===================================================================="
echo "🚀 [Alpaca 3D Farm] Старт развертывания интерфейса на Ender C"
echo "===================================================================="

# 1. Проверка прав
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: скрипт должен быть запущен с правами root (sudo $0)" >&2
    exit 1
fi

# 2. Настройка ZRAM и sysctl (защита от свопа на MicroSD)
echo "📦 [1/6] Настройка ZRAM и параметров виртуальной памяти..."
if ! command -v zramswap >/dev/null 2>&1; then
    apt-get update -qq
    apt-get install -y -qq zram-tools
fi

# Настройка размера zram (512 МБ сжатой памяти)
if [ -f /etc/default/zramswap ]; then
    sed -i 's/^#*ALLOCATION=.*/ALLOCATION=512/' /etc/default/zramswap
    sed -i 's/^#*ALGO=.*/ALGO=lz4/' /etc/default/zramswap
    systemctl restart zramswap || true
fi

# Применение sysctl (swappiness=10)
cp "${SCRIPT_DIR}/systemd/99-klipper-zram.conf" /etc/sysctl.d/99-klipper-zram.conf
sysctl -p /etc/sysctl.d/99-klipper-zram.conf >/dev/null 2>&1 || true

# 3. Настройка изоляции systemd (CPU Affinity & Slice)
echo "🔒 [2/6] Применение изоляции ресурсов systemd (Core CPU vs UI)..."

# Создание слайса farm-ui
cp "${SCRIPT_DIR}/systemd/farm-ui.slice" /etc/systemd/system/farm-ui.slice

# Drop-in для klipper.service (CPU 0, 1, Nice -10)
mkdir -p /etc/systemd/system/klipper.service.d
cp "${SCRIPT_DIR}/systemd/klipper-priority.conf" /etc/systemd/system/klipper.service.d/priority.conf

# Drop-in для moonraker.service (CPU 0, 1, Nice -5)
mkdir -p /etc/systemd/system/moonraker.service.d
cp "${SCRIPT_DIR}/systemd/moonraker-priority.conf" /etc/systemd/system/moonraker.service.d/priority.conf

# Drop-in для KlipperScreen.service (CPU 2, 3, Nice +5, OOM 700)
mkdir -p /etc/systemd/system/KlipperScreen.service.d
cp "${SCRIPT_DIR}/systemd/klipperscreen-limits.conf" /etc/systemd/system/KlipperScreen.service.d/limits.conf

systemctl daemon-reload
echo "🔄 Перезапуск служб печати с новыми приоритетами..."
systemctl restart klipper moonraker

# 4. Установка минимального графического стека Xorg
echo "🖥️  [3/6] Проверка и установка пакетов Xorg & GTK..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    xserver-xorg-core \
    xinit \
    xinput \
    x11-xserver-utils \
    libgtk-3-0 \
    python3-virtualenv \
    virtualenv \
    git \
    libgirepository1.0-dev \
    gcc \
    libcairo2-dev \
    pkg-config \
    python3-dev

# 5. Установка KlipperScreen
echo "📱 [4/6] Установка KlipperScreen..."
if [ ! -d "${USER_HOME}/KlipperScreen" ]; then
    sudo -u aniki git clone https://github.com/KlipperScreen/KlipperScreen.git "${USER_HOME}/KlipperScreen"
fi

# Запуск официального скрипта инсталляции под пользователем aniki (non-interactive, no reboot)
sudo -u aniki env SERVICE=y BACKEND=X NETWORK=n START=0 bash "${USER_HOME}/KlipperScreen/scripts/KlipperScreen-install.sh"

# 6. Конфигурация мультипринтерного шлюза
echo "📝 [5/6] Развертывание KlipperScreen.conf для фермы..."
mkdir -p "${CONFIG_DIR}"
ln -sf "${SCRIPT_DIR}/KlipperScreen.conf" "${CONFIG_DIR}/KlipperScreen.conf"

# Перезапуск KlipperScreen
systemctl daemon-reload
systemctl enable KlipperScreen.service || true
systemctl restart KlipperScreen.service || true

# 7. Отчет проверки (Health Check)
echo "===================================================================="
echo "✅ [6/6] Развертывание завершено! Проверка параметров системы:"
echo "===================================================================="
echo "• Статус Klipper PID: $(pgrep -f 'klippy.py' || echo 'не найден')"
if pgrep -f 'klippy.py' >/dev/null; then
    KLIPPER_PID=$(pgrep -f 'klippy.py' | head -n1)
    echo "  - CPU Affinity Klipper: $(taskset -cp ${KLIPPER_PID} 2>/dev/null || echo 'N/A')"
    echo "  - Nice Klipper: $(ps -o ni= -p ${KLIPPER_PID} 2>/dev/null || echo 'N/A')"
fi

echo "• Статус ZRAM Swap:"
swapon --show || true

echo "• Свободная память:"
free -h

echo "===================================================================="
echo "🎉 Готово! Экран Ender C настроен для управления Ender A, B и C."
echo "===================================================================="

