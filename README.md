MidnightCC is a World of Warcraft: Midnight addon that reskins cooldown number text on action-bar cooldown frames.

**Compatible with:** Patch 12.1.5 (Interface `120105`, also loads on 12.1.0 / `120100`) — last updated 2026-10-30.

## Changelog
- v1.1 - Added guardrails for secret value comparison in NamePlates and other parts of the UI protected by Blizzard
- v1.2 - Added profile management and import/export features
- v1.3 (2026-10-30) - Updated for Patch 12.1.5 (Interface 120105)
  - Options dropdowns now use the modern Blizzard Menu system (`WowStyle1DropdownTemplate`), with a fallback to the deprecated `UIDropDownMenu` API
  - Secret-value guard now uses Midnight's `issecretvalue()` API
  - Options panel controls now refresh after loading or importing a preset and whenever the panel is reopened
  - Imported presets are validated (font size, offsets, anchor and font style are clamped to supported values)
  - Saving a preset with surrounding spaces now selects it correctly
  - Preset name dialog Enter/Escape handling no longer depends on internal StaticPopup button fields
  - Removed pre-Dragonflight `InterfaceOptions` fallbacks

## What it does
- Changes only the cooldown text font family and font size.
- Does not compare cooldown values, read remaining durations for logic, or perform secret-value comparisons.
- Scans and updates visible `Cooldown` frames on action bars, so Blizzard-generated cooldown numbers inherit your chosen style.

## In-game options
MidnightCC adds an options panel in the AddOns settings where you can:
- Save, load, delete, export and import presets.
- Choose a cooldown font from a predefined list plus any fonts registered through LibSharedMedia-3.0 (if installed).
- Set cooldown text anchor position inside the button (top, center, or bottom).
- Choose a font format (Normal, Outline, Shadow, Shadow + Outline).
- Set cooldown font size (8-48).
- Nudge cooldown text with X/Y offsets (-10 to 10 px).
- Force a full cooldown refresh.

Slash command:
- `/midnightcc` to open the addon settings panel.

## Files
- `MidnightCC.toc`
- `MidnightCC.lua`
- `Options.lua`
