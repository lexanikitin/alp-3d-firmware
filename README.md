# Alpaca 3D Farm — Klipper Fleet Firmware & Configurations

Централизованный репозиторий прошивок, конфигураций железа, макросов и сетевых настроек **Klipper + Moonraker** для парка 3D-принтеров **Alpaca 3D Farm**.

Связанный репозиторий слайсера и профилей: [lexanikitin/alp-3d-lab](https://github.com/lexanikitin/alp-3d-lab)

---

## 🖨️ Состав парка и текущий статус

| Принтер | Модель | Сопло | Статус | Архитектурный паттерн |
| :--- | :--- | :---: | :---: | :--- |
| **Ender 3 S1 Pro (A)** | Creality Ender-3 S1 Pro | 0.4 мм | 🟢 **ACTIVE** | Общее ядро `ender/common` + оверрайды A |
| **Ender 3 S1 Pro (B)** | Creality Ender-3 S1 Pro | 0.4 мм | 🟡 **ASSEMBLY** | Общее ядро `ender/common` + оверрайды B |
| **Ender 3 S1 Pro (C)** | Creality Ender-3 S1 Pro | 0.4 мм | 🟡 **ASSEMBLY** | Общее ядро `ender/common` + оверрайды C |
| **Voron 2.4 350 (D)** | Voron 2.4 350 CoreXY | 0.6 мм CHT | 🟢 **ACTIVE** | Изолированная конфигурация `voron_d` |
| **Voron 2.4 350 (A)** | Voron 2.4 350 CoreXY | 0.4 мм | 🟡 **ASSEMBLY** | Изолированная конфигурация `voron_a` |
| **Voron 2.4 350 (B)** | Voron 2.4 350 CoreXY | 0.4 мм | 🟡 **ASSEMBLY** | Изолированная конфигурация `voron_b` |
| **Voron 2.4 350 (C)** | Voron 2.4 350 CoreXY | 0.4 мм | 🟡 **ASSEMBLY** | Изолированная конфигурация `voron_c` |

---

## 🏛️ Принципы организации кода

### 1. Семейство Ender-3 S1 Pro: «Общее ядро + Оверрайды»
* Принтеры построены на **одинаковой аппаратной базе** (плата Creality, Direct Sprite, кинематика Bedslinger).
* Весь базовый код вынесен в `ALP/ender/common/` (`hardware/`, `macros/`, KAMP, Demon Essentials).
* Индивидуальные файлы принтеров содержат только инклуд общего ядра и уникальные калибровки:
  - Серийный номер порта MCU (`/dev/serial/by-id/...`)
  - Индивидуальный `[probe] z_offset`
  - Индивидуальные PID стола и экструдера
  - Настройки `moonraker.conf`

### 2. Семейство Voron 2.4: «Полная изоляция станка»
* Принтеры собираются с **различными комплектующими** (разные CAN-платы EBB/Nitehawk, хотэнды Rapido/Dragon, датчики Tap/Cartographer, сопла 0.4 vs 0.6 CHT).
* Каждый Ворон изолирован в своей папке (`voron_a`, `voron_b`, `voron_c`, `voron_d`).
* Изменение в конфигурации одного Ворона гарантированно не затронет рабочий `voron_d`.

---

## 🔄 Автообновление через Moonraker Update Manager

Каждый принтер отслеживает этот репозиторий через Moonraker. В `moonraker.conf` хоста прописан блок:

```ini
[update_manager alp-klipper-printers]
managed_services: klipper
origin: https://github.com/lexanikitin/alp-klipper-printers.git
path: /home/aniki/alp-klipper-printers
primary_branch: main
type: git_repo
```

При обновлении ветки `main` в веб-интерфейсе Mainsail загорается кнопка **Update**, по нажатию которой Klipper обновляет макросы и перезапускает службу.

---

## 📜 Контракт макросов G-Code

Все принтеры реализуют стандартизированный интерфейс `PRINT_START` для вызова из OrcaSlicer:
```gcode
PRINT_START EXTRUDER=[nozzle_temperature_initial_layer] BED=[bed_temperature_initial_layer_single] CHAMBER=[chamber_temperature] NOZZLE_SIZE=[nozzle_diameter] FILAMENT_TYPE=[filament_type]
```

