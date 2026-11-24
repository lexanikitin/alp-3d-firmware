#!/usr/bin/env bash
# ==============================================================================
# Alpaca 3D Farm — Automatic Firmware Boot Sync
# ==============================================================================
# Вызывается службой alp-firmware-sync.service строго ДО запуска klipper.service.
# Безопасно подтягивает эталонные обновления из ветки main с ограничением таймаута.
# ==============================================================================

set -u

# Поиск пути к репозиторию (поддержка обоих путей: alp-3d-firmware и alp-klipper-printers)
REPO_DIR=""
for candidate in "/home/aniki/alp-3d-firmware" "/home/aniki/alp-klipper-printers"; do
    if [ -d "$candidate/.git" ]; then
        REPO_DIR="$candidate"
        break
    fi
done

if [ -z "$REPO_DIR" ]; then
    echo "⚠️ [ALP Boot Sync] Репозиторий прошивки не обнаружен, пропуск."
    exit 0
fi

echo "🚀 [ALP Boot Sync] Проверка обновлений прошивки в: $REPO_DIR"
cd "$REPO_DIR"

# 1. Проверка доступности сети и удаленного origin с жестким таймаутом (8 сек)
if timeout 8 git fetch --quiet origin main 2>/dev/null; then
    LOCAL_HASH=$(git rev-parse HEAD 2>/dev/null || true)
    REMOTE_HASH=$(git rev-parse origin/main 2>/dev/null || true)

    if [ -n "$LOCAL_HASH" ] && [ -n "$REMOTE_HASH" ] && [ "$LOCAL_HASH" != "$REMOTE_HASH" ]; then
        echo "🔄 [ALP Boot Sync] Обнаружены свежие коммиты ($LOCAL_HASH -> $REMOTE_HASH). Применение..."
        git reset --hard origin/main
        echo "✅ [ALP Boot Sync] Репозиторий успешно синхронизирован с origin/main ($REMOTE_HASH)."
    else
        echo "✅ [ALP Boot Sync] Конфигурация актуальна ($LOCAL_HASH)."
    fi
else
    echo "⚠️ [ALP Boot Sync] Сеть недоступна или таймаут ожидания (8s). Запуск Klipper на локальной версии."
fi

exit 0
