#!/bin/sh

export PATH="/usr/local/bin:/usr/bin:/bin:/Users/${USER}/.local/bin:$PATH"

devices="$(veracrypt --text --list | rg --color=never 'pass' | awk '{print $2}')"
launchagent="${HOME}/Library/LaunchAgents/pass-close.password.vera.plist"
uid=$(id -u)

rm -f "${PASSWORD_STORE_DIR:-$HOME/.password-store}/.timer"
veracrypt --text --dismount "$devices"
osascript -e "display notification \"Launch Agent unloaded\\nTimer Removed\" with title \"pass vera closed\""

launchctl bootout "gui/${uid}" "$launchagent"
rm -f "$launchagent"
