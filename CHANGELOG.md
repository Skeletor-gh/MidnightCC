# Changelog

## 1.3.0 (2026-11-13)

Updated for **World of Warcraft: Midnight 12.1.5** (Interface `120105`). The TOC also lists the 12.1.7 PTR (`120107`).

### Fixed
- **Duplicate countdown numbers on charge spells.** The addon forced numbers on for every cooldown on a button, including Blizzard's charge and loss-of-control cooldowns, which are meant to stay number-less. It now only forces numbers on the button's main cooldown.
- **Secret-value guard didn't work.** Earlier versions checked an `issecret()` function that doesn't exist, so the check never ran. It now uses Midnight's real `issecretvalue()` / `canaccessvalue()` APIs.
- **"Show numbers" was undone by Blizzard.** Changing Blizzard's *Show Numbers for Cooldowns* option, or a button reinitialising, could hide the numbers again. The override now holds.
- Action buttons created after login (bar addons, new bars enabled in Edit Mode) are now picked up as soon as their first cooldown starts.
- If a SharedMedia font is uninstalled, text falls back to the default font instead of disappearing.
- Imported or corrupted settings (out-of-range size or offsets, unknown style or anchor) are now clamped or reset instead of being applied as-is.
- The options panel now updates after you load, import or reset settings.

### Changed
- **Much lighter on performance.** Dragging a slider used to rescan every frame in the UI on each tick. Setting changes now restyle only the cooldowns the addon already tracks, and the full UI scan runs only at login, on loading screens, or when you click *Refresh*.
- LibSharedMedia updates restyle text only when the font you're using is registered, not for every piece of media another addon registers.
- Options panel rebuilt with Blizzard's current controls: the new dropdown menus, the modern sliders (`OptionsSliderTemplate` is deprecated in 12.x), and inline preset naming instead of a shared StaticPopup, which removes another taint risk.
- Settings now initialise on `ADDON_LOADED` instead of `PLAYER_LOGIN`.
- Removed the unused `groupProfiles` data and the pre-Dragonflight `InterfaceOptions` fallbacks.

### Added
- **Thick Outline** font format.
- **Always show cooldown numbers** option, on by default as before. Untick it to follow Blizzard's own setting.
- Live preview in the options panel.
- **Reset to Defaults** button.
- Status messages for preset save, load, delete, import and export.
- Addon Compartment (minimap addon menu) entry that opens the options.
- `/mcc` short slash command, plus `/mcc refresh`, `/mcc reset` and `/mcc help`.

### Compatibility
- Saved settings and presets from 1.2.x carry over automatically. Export strings from 1.2.x can still be imported.

## 1.2.1.3 (2026-08-19)
- Interface version update for 12.1.0.

## 1.2.1.2 (2026-06-22)
- Interface version update for 12.0.7.

## 1.2.1 (2026-04-22)
- Interface version update for 12.0.5.

## 1.2 (2026-03-22)
- Added preset management (save, load, delete) and import/export strings.
- Fixed a taint error in the preset name popup.

## 1.1 (2026-03-10)
- Added guardrails against secret values on nameplates and other Blizzard-protected UI.

## 1.0 (2026-02-15)
- Initial release for Midnight.
