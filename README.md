MidnightCC is a World of Warcraft addon for the 12.0 API that reskins cooldown number text on action-bar cooldown frames.

## Changelog
- Profile management, and import/export features 

## What it does
- Changes only the cooldown text font family and font size.
- Does not compare cooldown values, read remaining durations for logic, or perform secret-value comparisons.
- Scans and updates visible `Cooldown` on action bars, so Blizzard-generated cooldown numbers inherit your chosen style.

## In-game options
MidnightCC adds an options panel in the AddOns settings where you can:
- Choose a cooldown font from a predefined list plus any fonts registered through LibSharedMedia-3.0 (if installed).
- Set cooldown text anchor position inside the button (top, center, or bottom).
- Set cooldown font size (8-48).
- Force a full cooldown refresh.

Slash command:
- `/midnightcc` to open the addon settings panel.

## Files
- `MidnightCC.toc`
- `MidnightCC.lua`
- `Options.lua`
