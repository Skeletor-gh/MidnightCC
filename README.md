MidnightCC (Forever edition) is a World of Warcraft: Forever addon that reskins cooldown number text on action-bar cooldown frames.

This branch targets the WoW: Forever client (build 1.60.1, `## Interface: 16001`, game type `camelot`, `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT`). Features and design are identical to the Midnight (12.x) version; only the API usage was adapted to the Forever client.

## Forever API notes
- Interface version set to `16001` (client 1.60.1).
- Secret-value guard uses the documented `issecretvalue()` FrameScript API (Midnight-style addon restrictions are active in Forever).
- Cooldown text is styled through the documented `Cooldown:GetCountdownFontString()` method, with region scanning kept as a fallback.
- Adds Forever's shaman totem bar buttons (`MultiCastActionButton1-12`, `MultiCastSummonSpellButton`, `MultiCastRecallSpellButton`) to the recognised action buttons.

## Changelog
- v1.1 - Added guardrails for secret value comparison in NamePlates and other parts of the UI protected by Blizzard
- v1.2 - Added profile management and import/export features
- v1.2-forever - Port to the World of Warcraft: Forever API (interface 16001)

## What it does
- Changes only the cooldown text font family and font size.
- Does not compare cooldown values, read remaining durations for logic, or perform secret-value comparisons.
- Scans and updates visible `Cooldown` frames on action bars (including the Forever totem bar), so Blizzard-generated cooldown numbers inherit your chosen style.

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
