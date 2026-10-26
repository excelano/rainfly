#!/bin/sh
# The App Store screenshots, as recipes. shots-appstore builds the app for the
# simulator, boots each simulator ship.toml names, installs the iPhone app or
# the embedded watch app, and calls this with the simulator, the language and
# where the frames go; this file is the half that is Zeltwetter's: which screens,
# from the nights and camps a Debug build sets up when launched with --demo.
#
#     ./packaging/ios/shots.sh --app <Zeltwetter.app> --device <udid> --lang en-us --outdir <dir>
#
# Author: David M. Anderson
# Built with AI assistance (Claude, Anthropic)
set -eu
app= device= lang= outdir=
while [ $# -gt 0 ]; do
    case "$1" in
        --app) app=$2; shift 2 ;;
        --device) device=$2; shift 2 ;;
        --lang) lang=$2; shift 2 ;;
        --outdir) outdir=$2; shift 2 ;;
        *) echo "shots.sh: unknown argument $1" >&2; exit 2 ;;
    esac
done
[ -n "$app" ] && [ -n "$device" ] && [ -n "$lang" ] && [ -n "$outdir" ] || { echo "shots.sh: --app, --device, --lang and --outdir are all required" >&2; exit 2; }
case "$lang" in
    en|en-us|en-US) languages='(en)'; locale=en_US ;;
    *) echo "shots.sh: no set is written for $lang" >&2; exit 2 ;;
esac
case "$(xcrun simctl list devices | grep -F "($device)" | head -1)" in
    *Watch*) kind=watch; plist=$(echo "$app"/Watch/*.app/Info.plist) ;;
    *iPhone*) kind=phone; plist=$app/Info.plist ;;
    *) echo "shots.sh: no set is written for $device" >&2; exit 2 ;;
esac
bundle=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$plist")
mkdir -p "$outdir"
settle=12
shot() {
    name=$1
    shift
    xcrun simctl launch --terminate-running-process "$device" "$bundle" \
        -AppleLanguages "$languages" -AppleLocale "$locale" "$@" >/dev/null
    sleep "$settle"
    xcrun simctl io "$device" screenshot --type=png "$outdir/$name.png" >/dev/null
    echo "$name"
}
case $kind in
    watch)
        shot 01-fly-on --demo dew
        shot 02-checks --demo rain --open detail
        shot 03-fly-off --demo clear
        shot 04-storm --demo storm
        shot 05-camps --demo clear --open camps
        shot 06-settings --demo clear --open settings
        ;;
    phone)
        shot 01-fly-on --demo dew
        shot 02-rain --demo rain
        shot 03-fly-off --demo clear
        shot 04-storm --demo storm
        shot 05-trip --demo rain --open camps
        shot 06-settings --demo clear --open settings
        ;;
esac
xcrun simctl terminate "$device" "$bundle" >/dev/null 2>&1 || true
