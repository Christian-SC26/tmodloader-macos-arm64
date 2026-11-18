#!/usr/bin/env bash
# tmodloader-macos-arm64: let Steam launch tModLoader natively on Apple Silicon.
# Usage:
#   install.sh              patch the launcher and download the arm64 .NET runtime
#   install.sh --uninstall  restore the original launcher and delete the arm64 runtime
# Set TML_DIR to point at a tModLoader install that is not in a Steam library.
set -euo pipefail

MARKER="tmodloader-macos-arm64"
STEAM_ROOT="$HOME/Library/Application Support/Steam"
LAUNCH_LINE='./LaunchUtils/ScriptCaller.sh "$@" &'

say() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

find_tml() {
	if [ -n "${TML_DIR:-}" ]; then
		printf '%s\n' "$TML_DIR"
		return
	fi
	local vdf="$STEAM_ROOT/steamapps/libraryfolders.vdf" lib
	{
		printf '%s\n' "$STEAM_ROOT"
		[ -f "$vdf" ] && sed -n 's/^[[:space:]]*"path"[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$vdf"
	} | while IFS= read -r lib; do
		if [ -f "$lib/steamapps/common/tModLoader/tModLoader.dll" ]; then
			printf '%s\n' "$lib/steamapps/common/tModLoader"
			break
		fi
	done
}

patch_launcher() {
	local f="$1/start-tModLoader.sh"
	[ -f "$f" ] || die "$f not found"
	if grep -q "$MARKER" "$f"; then
		say "Launcher already patched"
		return
	fi
	grep -qxF "$LAUNCH_LINE" "$f" ||
		die "start-tModLoader.sh does not contain the expected launch line. tModLoader may have changed its launcher; please open an issue."
	cp -p "$f" "$f.orig"
	local block
	block=$(
		cat <<'EOF'
# >>> tmodloader-macos-arm64 >>>
# Steam starts this script under Rosetta with DYLD_INSERT_LIBRARIES=steamloader.dylib. That dylib has
# no arm64e slice, so the "arch -arm64" re-exec in ScriptCaller.sh aborts in dyld. Drop the variable here;
# EnvironmentFix.sh sets it again from STEAM_DYLD_INSERT_LIBRARIES for the game process.
if [ "$(uname)" = Darwin ]; then
	for a in "$@"; do [[ "$a" == "-arm64" || "$a" == "-arm" ]] && unset DYLD_INSERT_LIBRARIES; done
fi
# <<< tmodloader-macos-arm64 <<<
EOF
	)
	local l
	while IFS= read -r l || [ -n "$l" ]; do
		[ "$l" = "$LAUNCH_LINE" ] && printf '%s\n' "$block"
		printf '%s\n' "$l"
	done <"$f.orig" >"$f.tmp"
	grep -q "$MARKER" "$f.tmp" || { rm -f "$f.tmp"; die "failed to patch start-tModLoader.sh"; }
	cat "$f.tmp" >"$f" # keep the file's permissions
	rm -f "$f.tmp"
	say "Patched start-tModLoader.sh (original saved as start-tModLoader.sh.orig)"
}

install_dotnet() {
	# Use tModLoader's own scripts so the runtime version matches tModLoader.runtimeconfig.json.
	say "Installing the arm64 .NET runtime into dotnet_arm64 (about 30 MB download on first run)"
	env -u DYLD_INSERT_LIBRARIES arch -arm64 /bin/bash -c '
		set -e
		cd "$1/LaunchUtils"
		. ./BashUtils.sh
		LogFile=/dev/null
		. ./DotNetVersion.sh >/dev/null
		bash ./InstallDotNet.sh 2>&1 | grep -vE "skipping (destruction|dealloc)" | tail -n 3
	' _ "$1"
	file "$1/dotnet_arm64/dotnet" 2>/dev/null | grep -q arm64 ||
		die "the arm64 .NET runtime did not install. Check your connection and run the installer again."
}

uninstall() {
	local tml="$1" f="$1/start-tModLoader.sh"
	if [ -f "$f.orig" ]; then
		mv "$f.orig" "$f"
		say "Restored the original start-tModLoader.sh"
	elif grep -q "$MARKER" "$f"; then
		sed -i '' "/# >>> $MARKER >>>/,/# <<< $MARKER <<</d" "$f"
		say "Removed the patch from start-tModLoader.sh"
	else
		say "Launcher is not patched"
	fi
	rm -rf "$tml/dotnet_arm64"
	say "Deleted dotnet_arm64. Remove -arm64 from the Steam launch options."
}

main() {
	[ "$(uname)" = Darwin ] || die "this fix is for macOS only"
	[ "$(sysctl -n hw.optional.arm64 2>/dev/null)" = 1 ] || die "this Mac has an Intel CPU; tModLoader already runs natively on it"

	local tml
	tml=$(find_tml || true)
	[ -n "$tml" ] && [ -f "$tml/tModLoader.dll" ] ||
		die "tModLoader not found in your Steam libraries. Install it from Steam, or run with TML_DIR=/path/to/tModLoader"
	say "tModLoader: $tml"

	if [ "${1:-}" = "--uninstall" ]; then
		uninstall "$tml"
		return
	fi

	patch_launcher "$tml"
	install_dotnet "$tml"

	printf '%s' "-arm64" | pbcopy 2>/dev/null || true
	cat <<'EOF'

Done. One step left, in Steam:
  Library > right-click tModLoader > Properties > General > Launch Options
  add:  -arm64      (already copied to your clipboard)

A tModLoader update or "Verify integrity of game files" restores the original
launcher. Run this installer again after either one.
EOF
}

main "$@"
