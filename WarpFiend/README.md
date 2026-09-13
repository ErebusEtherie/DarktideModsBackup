# WarpFiend - Advanced Psyker DPS Optimization Mod

## Overview
**WarpFiend** is an advanced DPS optimization mod for Psyker basic attack gameplay in Warhammer 40,000: Darktide. Unlike safety-focused mods, WarpFiend implements an intelligent **decision-tree algorithm** to maximize damage output while maintaining optimal peril management.

## Features

### 🎯 6-Action Decision Tree
The mod evaluates your combat state and executes one of six actions:

| Action | Trigger Condition | Response |
|--------|------------------|----------|
| **ACTION 1** | Peril ≥ 97% + Shriek Ready | Emergency Shriek to prevent explosion |
| **ACTION 2** | Peril ≥ 97% + Shriek on CD | Emergency Quell, block primary fire |
| **ACTION 3** | Peril < 83.33% | Continuous primary fire ramp-up |
| **ACTION 4** | 83.33% ≤ Peril < 97% + Shriek CD | Burst fire + micro-quell cycles |
| **ACTION 5** | 83.33% ≤ Peril < 97% + Shriek Ready + Good Targets | Execute optimal Venting Shriek |
| **ACTION 6** | 83.33% ≤ Peril < 97% + Shriek Ready + Low Density | Hold Shriek + maintain with micro-quells |

### 📊 Buff Monitoring
- **Becalming Eruption**: Tracks stacks (up to 25) and allows continuous firing during active buff
- **Warp Siphon**: Monitors damage multiplier stacks (4-6 stacks)
- **Psykinetic's Aura**: Detects elite/specialist kill cooldown reduction
- **Just a Dream**: Tracks 97% peril damage conversion state

### ⚙️ Input Modes
Choose your preferred control scheme:
- **Auto-Cast**: Mod automatically triggers abilities (aggressive automation)
- **Input Blocking**: Mod blocks unwanted inputs, you press buttons (more control)

## Installation

1. Copy the `WarpFiend` folder to your Darktide mods directory:
   ```
   %APPDATA%\Darktide\mods\
   ```

2. Ensure Darktide Mod Framework (DMF) is installed

3. Enable the mod in DMF settings

## Configuration

### Peril Management
- **Peak Window Threshold** (0.5 - 0.95, default 0.8333)
- **Emergency Threshold** (0.90 - 1.0, default 0.97)
- **Micro-Quell Duration** (0.1 - 1.0s, default 0.4s)

### Venting Shriek
- **Auto Venting Shriek** (checkbox, default ON)
- **Target Density Threshold** (1-10, default 3)
- **Hold Shriek for Better Value** (checkbox, default ON)
- **Elite/Specialist Priority** (checkbox, default ON)

### Weapon Profile
- **Staff Type**: Trauma / Purgatus / Surge / Voidstrike
- **Custom Peril Cost** (override, default 0 = use preset)

### Debug
- **Enable Debug Logging** (checkbox, default OFF)

## Usage Tips

1. **Select Your Staff**: Always set the correct staff type for accurate peril calculations
2. **Adjust Density Threshold**: Lower to 2 for frequent Shrieks, raise to 4+ for hordes
3. **Use Auto-Cast for Learning**: Start with Auto-Cast, then switch to Input Blocking
4. **Enable Debug Logging**: Watch which actions are selected to understand the logic

## Known Limitations

- **Empyric Shock Tracking**: Enemy debuff detection is simplified
- **Target Density**: Uses simple distance/angle checks
- **Burst Counter**: Simplified implementation

## Version History

### 1.0.0 (Initial Release)
- ✅ Modular architecture (buff monitor + decision tree)
- ✅ 6-action decision tree implementation
- ✅ Dual input modes (Auto-Cast and Input Blocking)
- ✅ Comprehensive buff state tracking
- ✅ Configurable peril thresholds
- ✅ Staff-specific peril cost profiles

## Credits
- Game: Warhammer 40,000: Darktide by Fatshark
- Mod Framework: Darktide Mod Framework (DMF)
- Reference: WarpGod mod

## License
This mod is provided as-is for educational purposes. Use at your own risk.