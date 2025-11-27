# TeamKillTracker

A mod for Warhammer 40,000: Darktide that tracks team kills in real time.

## Description

TeamKillTracker displays a permanent team kill counter in the bottom left corner of the screen. The mod shows:
- Total team kill count
- Individual statistics for each player
- Player sorting by kill count (highest to lowest)

## Features

- **Real-time**: Counter updates instantly with each kill
- **Team statistics**: Shows results for all team players
- **Automatic reset**: Counters reset when starting a new mission
- **Hub hiding**: Interface automatically hides in Mourningstar
- **Minimal design**: Compact counter doesn't clutter the screen

## Installation

1. Make sure you have [Darktide Mod Framework](https://github.com/danreeves/dt-mod-framework) installed
2. Download the TeamKillTracker mod
3. Place the `TeamKillTracker` folder in your Darktide mods directory
4. Launch the game and activate the mod in settings

## Interface

The counter displays in format:
```
TEAM KILLS: 125 (56,789) [12,345]
PlayerName1: 45 (15,432) [1,234]
PlayerName2: 38 (12,345) [987]
PlayerName3: 27 (9,876) [654]
PlayerName4: 15 (4,321) [543]
```

**Position**: Bottom left corner of screen  
**Font**: Machine Medium, 16px  
**Color**: White with shadow

## Technical Information

### Main Components

- `TeamKillTracker.lua` - Main kill counting logic
- `HudElementPlayerStats.lua` - UI element for displaying statistics
- `TeamKillTracker_data.lua` - Mod settings
- `TeamKillTracker_localization.lua` - Localization (EN/RU)

### How It Works

The mod uses the `AttackReportManager.add_attack_result` hook to track attack results. When receiving a "died" result for a minion unit, the mod increases the kill counter for the corresponding player.

### Compatibility

- **Game**: Warhammer 40,000: Darktide
- **Framework**: Darktide Mod Framework
- **Version**: Current game version
- **Conflicts**: No known conflicts with other mods

## Settings

The mod supports standard Darktide Mod Framework settings:
- Enable/disable mod
- Ability to reload without game restart

## Support

If you encounter problems:
1. Make sure Darktide Mod Framework is updated to the latest version
2. Check that the mod is properly installed in the mods folder
3. Restart the game after installation

## Versions
1.7.0

## Changelogs
- 1.7.0 – added “everyone except me” display mode and expanded HUD color presets.
- 1.6.1 – last-hit damage now rounds up to the nearest integer.
- 1.6.0 – new display modes (all / only me / team total), last-damage color option, dynamic HUD height and layout tweaks.
- 1.5.0 – added color customization for kills and damage display (8 color presets available).
- 1.4.0 – fixed kill counting and damage calculation.
- 1.3.0 – added HUD Counter Mode setting (dropdown: Kills (Damage), Kills only, Damage only).
- 1.2.0 – added damage tracking and HUD output in "kills (damage)" format; switched to account_id keys; prevented double-counting on death events.
- 1.1.0 – added settings to hide the team total line and per-user lines; prevented counter reset on settings change; updated localization.
- 1.0.0 – first version of the mod


### Current Version
- Tracking kills and damage for all team players (HUD shows kills (damage))
- Automatic hiding in hub
- Sorting by kill count
- Support for Russian and English localization

## License

This mod is distributed as is. Use at your own risk.

---

*Mod created to enhance the gaming experience in Warhammer 40,000: Darktide*

---

# TeamKillTracker (RU)

Мод для Warhammer 40,000: Darktide, который отслеживает убийства команды в реальном времени.

## Описание

TeamKillTracker отображает постоянный счетчик убийств команды в левом нижнем углу экрана. Мод показывает:
- Общее количество убийств команды
- Индивидуальную статистику каждого игрока
- Сортировку игроков по количеству убийств (от большего к меньшему)

## Особенности

- **Реальное время**: Счетчик обновляется мгновенно при каждом убийстве
- **Командная статистика**: Показывает результаты всех игроков в команде
- **Автоматический сброс**: Счетчики обнуляются при начале новой миссии
- **Скрытие в хабе**: Интерфейс автоматически скрывается в Mourningstar
- **Минимальный дизайн**: Компактный счетчик не загромождает экран

## Установка

1. Убедитесь, что у вас установлен [Darktide Mod Framework](https://github.com/danreeves/dt-mod-framework)
2. Скачайте мод TeamKillTracker
3. Поместите папку `TeamKillTracker` в директорию модов Darktide
4. Запустите игру и активируйте мод в настройках

## Интерфейс

Счетчик отображается в формате:
```
TEAM KILLS: 125 (56,789) [12,345]
PlayerName1: 45 (15,432) [1,234]
PlayerName2: 38 (12,345) [987]
PlayerName3: 27 (9,876) [654]
PlayerName4: 15 (4,321) [543]
```

**Позиция**: Левый нижний угол экрана  
**Шрифт**: Machine Medium, 16px  
**Цвет**: Белый с тенью

## Техническая информация

### Основные компоненты

- `TeamKillTracker.lua` - Основная логика подсчета убийств
- `HudElementPlayerStats.lua` - UI элемент для отображения статистики
- `TeamKillTracker_data.lua` - Настройки мода
- `TeamKillTracker_localization.lua` - Локализация (EN/RU)

### Как работает

Мод использует хук `AttackReportManager.add_attack_result` для отслеживания результатов атак. При получении результата "died" для юнита-миньона, мод увеличивает счетчик убийств для соответствующего игрока.

### Совместимость

- **Игра**: Warhammer 40,000: Darktide
- **Фреймворк**: Darktide Mod Framework
- **Версия**: Актуальная версия игры
- **Конфликты**: Нет известных конфликтов с другими модами

## Настройки

Мод поддерживает стандартные настройки Darktide Mod Framework:
- Включение/выключение мода
- Возможность перезагрузки без перезапуска игры

## Поддержка

При возникновении проблем:
1. Убедитесь, что Darktide Mod Framework обновлен до последней версии
2. Проверьте, что мод правильно установлен в папку модов
3. Перезапустите игру после установки

## Версии
1.7.0

## Журнал изменений
- 1.7.0 — добавлен режим отображения «все, кроме меня» и расширен набор цветовых пресетов HUD.
- 1.6.1 — последний удар округляется вверх до ближайшего целого.
- 1.6.0 — новые режимы отображения (всё / только я / только общий счёт), отдельный цвет последнего урона и адаптивная высота HUD.
- 1.5.0 — добавлена настройка цвета для отображения убийств и урона (доступно 8 готовых цветов).
- 1.4.0 — исправлен подсчёт убийств и расчёт урона.
- 1.3.0 — добавлена настройка «Режим счётчика в HUD» (выпадающий список: Убийства (Урон), Только убийства, Только урон).
- 1.2.0 — добавлен подсчёт урона и вывод в HUD в формате «киллы (урон)»; переход на ключи account_id; защита от двойного учёта при смерти.
- 1.1.0 — добавлены настройки скрытия строки Team Kills и строк пользователей; предотвращён сброс счётчика при смене настроек; обновлена локализация.
- 1.0.0 — первая версия мода

### Текущая версия
- Отслеживание убийств и урона всех игроков команды (HUD показывает «киллы (урон)»)
- Автоматическое скрытие в хабе
- Сортировка по количеству убийств
- Поддержка русской и английской локализации

## Лицензия

Данный мод распространяется как есть. Используйте на свой риск.

---

*Мод создан для улучшения игрового опыта в Warhammer 40,000: Darktide*