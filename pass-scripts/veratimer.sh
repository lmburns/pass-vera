#!/bin/sh

export PATH="/usr/local/bin:/usr/bin:/bin:/Users/${USER}/.local/bin:$PATH"
readonly VERA_FILE="${PASSWORD_STORE_VERA_FILE:-$HOME/.password.vera}"
readonly devices="$(veracrypt --text --list | rg --color=never 'pass' | awk '{print $2}')"
readonly launchagent="${HOME}/Library/LaunchAgents/pass-close.password.vera.plist"
readonly uid=$(id -u)

_agent_status() { launchctl list | rg -Fq --color=never "pass-close${VERA_FILE##*/}"; }

rm -f "${PASSWORD_STORE_DIR:-$HOME/.password-store}/.timer"
veracrypt --text --dismount "$devices"

_agent_status && w="Launch Agent unloaded" || w=""
osascript -e "display notification \"Timer Removed\\n${w}\" with title \"pass vera closed\""

_agent_status && launchctl bootout "gui/${uid}" "$launchagent"
rm -f "$launchagent"
