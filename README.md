# MidnightCC

MidnightCC is a World of Warcraft: Midnight addon that restyles the countdown numbers on your action-bar cooldowns: font, size, outline and position.

**Compatible with:** Retail patch **12.1.5** (Interface `120105`) · Current version: **1.3.0**

## What it does
- Changes how cooldown numbers look on Blizzard's action bars and on bar addons built on secure action buttons (Bartender4, Dominos, ElvUI and similar).
- Never reads, compares or acts on cooldown values. It only restyles the text Blizzard already draws, so it stays clear of Midnight's secret-value restrictions.
- Leaves nameplates and other protected or forbidden frames alone.
- Keeps charge and loss-of-control cooldowns number-less, the way Blizzard designed them.

## Options
Open with `/mcc`, from the Addon Compartment (the minimap addon menu), or under **Options › AddOns › MidnightCC**.

- **Cooldown font**: built-in fonts plus any LibSharedMedia-3.0 font, if a SharedMedia addon is installed.
- **Font format**: Normal, Outline, Thick Outline, Shadow, Shadow + Outline.
- **Position on button**: top, center or bottom, with horizontal and vertical offsets (-10 to 10 px).
- **Font size**: 8 to 48.
- **Always show cooldown numbers**: shows numbers even when Blizzard's *Show Numbers for Cooldowns* option is off. Untick it to follow Blizzard's setting.
- **Presets**: save, load and delete named presets, and export or import them as a string to share.
- Live preview, **Refresh Cooldowns** and **Reset to Defaults**.

## Slash commands
| Command | Effect |
| --- | --- |
| `/mcc` or `/midnightcc` | Open the options panel |
| `/mcc refresh` | Rescan and restyle all action-bar cooldowns |
| `/mcc reset` | Restore default settings |
| `/mcc help` | List commands |

## Installation
Extract the `MidnightCC` folder into `World of Warcraft/_retail_/Interface/AddOns/`.

## Files
- `MidnightCC.toc`: addon metadata
- `MidnightCC.lua`: cooldown detection, styling, presets and slash commands
- `Options.lua`: settings panel
- `icon.tga`: addon icon

## Changelog
See [CHANGELOG.md](CHANGELOG.md). Latest: **1.3.0**, which updates the addon for 12.1.5, fixes duplicate numbers on charge spells and the secret-value guard, improves performance, and modernises the options panel.

## Development
A headless test harness with WoW API stubs lives in `tests/` (excluded from packages via `.pkgmeta`):

```sh
lua5.3 tests/harness.lua .   # or texlua
```
