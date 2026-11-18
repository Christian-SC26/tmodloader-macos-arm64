# tmodloader-macos-arm64

Launch [tModLoader](https://store.steampowered.com/app/1281930/tModLoader/) from Steam as a native Apple Silicon app instead of through Rosetta 2.

[Русская версия](README.ru.md)

**Status:** experimental. Tested on one Mac (M3 Pro, macOS 27.2.1, tModLoader v2026.9.3.1, 38 mods including Calamity and Fargo's Souls). If it breaks on your setup, please [open an issue](../../issues) and include `tModLoader-Logs/Launch.log`.

## Install

Paste into Terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/Christian-SC26/tmodloader-macos-arm64/main/install.sh | bash
```

Then in Steam: **Library → right-click tModLoader → Properties → General → Launch Options**, and add `-arm64`. The installer copies `-arm64` to your clipboard.

You need an Apple Silicon Mac and tModLoader installed through Steam. For a tModLoader folder outside your Steam libraries, run the installer with `TML_DIR=/path/to/tModLoader`.

## The problem

On Apple Silicon, tModLoader runs its x86_64 .NET runtime under Rosetta 2. tModLoader's launcher has a `-arm64` flag that switches to an arm64 runtime, but the game exits about two seconds after you press Play in Steam, with no window and no error.

The cause: Steam starts `start-tModLoader.sh` as an x86_64 process and sets `DYLD_INSERT_LIBRARIES` to Steam's `steamloader.dylib`. With `-arm64`, `LaunchUtils/ScriptCaller.sh` re-executes itself through `arch -arm64`. `arch` is an arm64e system binary, `steamloader.dylib` ships only i386, x86_64 and arm64 slices, and dyld aborts:

```
dyld: terminating because inserted dylib '.../steamloader.dylib' could not be loaded:
  (fat file, but missing compatible architecture (have 'i386,x86_64,arm64', need 'arm64e'))
```

Forum posts suggest editing `arm_flag` in `ScriptCaller.sh`. That flag only selects the runtime; the crash above still happens.

## What the installer changes

1. Adds a short block to `start-tModLoader.sh` that unsets `DYLD_INSERT_LIBRARIES` when you pass `-arm64`. tModLoader's `EnvironmentFix.sh` sets it again from `STEAM_DYLD_INSERT_LIBRARIES` before starting the game, so Steam still detects the running game and injects its overlay library. The original file stays next to it as `start-tModLoader.sh.orig`.
2. Downloads the arm64 .NET runtime into `tModLoader/dotnet_arm64` with tModLoader's own `InstallDotNet.sh`, so the version matches `tModLoader.runtimeconfig.json`.

It touches nothing outside the tModLoader folder. Without `-arm64` in the launch options, tModLoader starts under Rosetta as before.

## Check that it worked

Start the game from Steam, open Activity Monitor, and find the `dotnet` process. The **Kind** column says **Apple** for native and **Intel** for Rosetta.

## After a tModLoader update

Steam replaces `start-tModLoader.sh` when tModLoader updates or when you run **Verify integrity of game files**. The game then fails to start with `-arm64` again. Run the install command again.

## Limits

- The installer removes Rosetta from the picture. Heavy content mods still cost frame time, and this repository includes no FPS measurements.
- Graphics stay on the MoltenVK 1.1.10 that tModLoader bundles. Swapping in MoltenVK 1.4.2 broke rendering in testing, so the installer leaves it alone.
- Intel Macs already run tModLoader natively and need nothing from here.

## Uninstall

```sh
curl -fsSL https://raw.githubusercontent.com/Christian-SC26/tmodloader-macos-arm64/main/install.sh | bash -s -- --uninstall
```

This restores `start-tModLoader.sh`, deletes `dotnet_arm64`, and asks you to remove `-arm64` from the launch options.

## License

[MIT](LICENSE). Not affiliated with the tModLoader team, Re-Logic, or Valve.
