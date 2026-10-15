# Quick Pause

Freeze or slow the game with Escape or a hotkey, without opening the pause menu.

Part of the [Speedrun modpack](https://thunderstore.io/c/hades-ii/p/adamantSpeedrun/Speedrun_Modpack/).

## What It Does

Quick Pause is a practice and routing tool. Instead of the pause menu, it applies the game's own simulation-speed slowdown, so the world stops (or slows) while the screen stays clear.

- **Pause hotkey:** a key (F1 to F12, optionally with Ctrl, Shift or Alt; F9 by default) that toggles the freeze. The key is managed by ModpackLib: you set it under Hotkeys at the top of the module's settings, which tells you if another module or the Hell2Modding overlay already uses it. ModpackLib's Hotkeys page lists every module's keys. It starts a freeze during plain gameplay only, not over boon screens, the codex or the trait tray, or while you are dead, and it can always end one.
- **Speed while paused:** a percentage of normal game speed. 0 is a full freeze.
- **Block actions while paused:** stops attacks and dashes from queueing up.
- **PAUSED indicator:** a small badge in the top-left corner while paused. It is drawn by the mod overlay, not the game HUD, so it shows at any speed, including a full freeze.

The freeze is released when the module is disabled, when a new run starts and when you enter a room. If something in the game removes the freeze while you are paused, Quick Pause puts it back.

## Notes

- This is not the game's pause menu. Timers that run on real time, such as a real-time timer, keep running while you are frozen, and some effects that ignore game speed (UI, some visual effects) keep animating.
- The module is off by default. Enable it in the Speedrun modpack window. With Debug Mode on, it logs every change to the game's speed requests while paused.

## Installation

Install via r2modman.

This module is usually installed as part of the full [Speedrun modpack](https://thunderstore.io/c/hades-ii/p/adamantSpeedrun/Speedrun_Modpack/), where it appears in the shared Speedrun UI with the other speedrun-focused modules.
