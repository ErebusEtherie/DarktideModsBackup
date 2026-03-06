# Mission Progress

A Darktide mod that displays a customizable progress bar showing mission completion, medicae station locations, collectibles, respawn beacons, and distance to extraction.

## Features

- **Progress Bar** - Visual bar showing mission completion (vertical or horizontal)
- **Medicae Markers** - Shows healing station locations and remaining charges
- **Respawn Beacons** - Shows respawn beacon positions along your route
- **Grimoire Markers** - Shows grimoire pickup locations
- **Scripture Markers** - Shows scripture/tome pickup locations
- **Distance Display** - Remaining distance to extraction
- **Percentage Display** - Current mission progress percentage
- **15 Theme Presets** - Choose from a variety of visual styles
- **Full Customization** - Create your own theme with custom colors and dimensions
- **Flexible Layout** - Vertical/horizontal, left/right, invert direction, swap sides

## Theme Presets

| Theme | Description |
|-------|-------------|
| **Default** | Subtle dark theme that blends with the HUD |
| **Custom** | Unlock individual color and dimension settings |
| **Minimal** | Thin bar with minimal visual noise |
| **Neon Cyber** | Hot pink and electric blue synthwave vibes |
| **Imperium** | Gold and crimson, for the Emperor |
| **Mechanicus** | Red and teal, praise the Omnissiah |
| **Inquisition** | Pure white and blood red, holy purity |
| **Chaos** | Dark purple corruption of the warp |
| **Veteran** | Military olive and khaki, standard issue |
| **Zealot** | Orange flames, burn the heretic |
| **Ogryn** | Big and bold, for da big uns |
| **Psyker** | Warp energy blue and purple |
| **Stealth** | Nearly invisible until you need it |
| **Hive World** | Polluted amber industrial grime |
| **Void Born** | Deep space cold blue |
| **Death Guard** | Sickly green, Grandfather Nurgle's gifts |

## Requirements

- Darktide Mod Framework (DMF)

## Installation

1. Extract `mission_progress` folder to your `mods` directory
2. Add `mission_progress` to `mod_load_order.txt`
3. Launch the game

## Configuration

Open the mod menu to configure:

### Position & Layout
- Orientation (vertical/horizontal)
- Screen edge (left/right or top/bottom)
- Invert direction (flip 0%/100% ends)
- Invert tags (swap percentage text and medicae marker sides)

### Size & Appearance
- Bar width and height
- Edge distance and position offset
- Opacity (10-100%)

### Text Settings
- Font size (also scales marker tick sizes)
- Decimal precision for percentage
- Show/hide distance and percentage

### Markers
- Toggle visibility for: progress bar, medicae, beacons, grimoires, scriptures

### Marker Color Overrides
- Override marker colors for any theme

### Custom Theme
- Full RGB control over bar background, fill, and border colors
- Custom dimensions when using Custom preset

### Keybind
- Set a key to toggle visibility

## Version History

- **2.0.0** - Major update: 15 theme presets, horizontal mode, grimoire/scripture/beacon markers, layout controls, font size scaling
- **1.1.0** - Added theme presets and customization options
- **1.0.0** - Initial release
