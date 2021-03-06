#!/usr/bin/env bash
# pass vera - Password Store Extension (https://www.passwordstore.org/)
# Copyright (C) 2021 Lucas Burns
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.	If not, see <http://www.gnu.org/licenses/>.

# shellcheck disable=SC2015,SC2181

typeset -r VERSION="2.0"

typeset -r RED=$(tput setaf 1) GREEN=$(tput setaf 2) YELLOW=$(tput setaf 3)
typeset -r BLUE=$(tput setaf 4) MAGENTA=$(tput setaf 5) CYAN=$(tput setaf 6)
typeset -r BOLD=$(tput bold) RESET=$(tput sgr0)

# environmental variables
typeset -r VERA="${PASSWORD_STORE_VERA:-veracrypt}"
VERA_FILE="${PASSWORD_STORE_VERA_FILE:-$HOME/.password.vera}"
VERA_KEY="${PASSWORD_STORE_VERA_KEY:-$HOME/.password.vera.key}"
VERA_SIZE="${PASSWORD_STORE_VERA_SIZE:-15}"
conf_dir="${XDG_CONFIG_HOME:-$HOME/.config}/pass-vera"

# important paths used throughout
typeset -r TMP_PATH="/tmp/pass-close${VERA_FILE##*/}.plist"
typeset -r PLIST_FILE="${HOME}/Library/LaunchAgents/${TMP_PATH##*/}"
typeset -r PlistBuddy="/usr/libexec/PlistBuddy"
typeset -r TIMER_FILE="${PREFIX}/${path}/.timer"

typeset -r uid="$(id -u "$USER")"
typeset -r gid="$(id -g "$USER")"

typeset -a VERA_MOUNT_OPTS VERA_CREATE_OPTS

# veracrypt mounting options
VERA_MOUNT_OPTS=( "--text" "--keyfiles" "$VERA_KEY" "--pim=0" "--protect-hidden=no" "--mount" "$VERA_FILE" "${PREFIX}/${path}" )

# veracrypt creating options
VERA_CREATE_OPTS=( "--text" "--volume-type=normal" "--create" "$VERA_FILE" "--size=${VERA_SIZE}M" "--encryption=aes" "--hash=sha-512" "--filesystem=exFAT" "--pim=0" "--keyfiles" "$VERA_KEY" "--random-source=/dev/urandom" )

# add armor to gpg options
GPG_OPTS+=( "--armor" )

_message() { [ "$QUIET" = 0 ] && printf '  %b.%b	%s\n' "$BOLD" "$RESET" "$*" >&2; }
_warning() { [ "$QUIET" = 0 ] && printf '  %bw%b	%b%s%b\n' "${BOLD}${YELLOW}" "$RESET" "$YELLOW" "$*" "$RESET" >&2; }
_success() { [ "$QUIET" = 0 ] && printf ' %b(*)%b %b%s%b\n' "${BOLD}${GREEN}" "$RESET" "$GREEN" "$*" "$RESET" >&2; }
_verbose() { [ "$VERBOSE" = 0 ] || printf '  %b.%b	%bpass%b %s\n' "${BOLD}${MAGENTA}" "$RESET" "$MAGENTA" "$RESET" "$*" >&2; }
_verbose_vera() { [ "$VERBOSE" = 0 ] || printf '	%b.%b  %s\n' "${BOLD}${MAGENTA}" "$RESET" "$*" >&2; }
_error() { printf ' %b[x]%b %bError:%b %s\n' "${BOLD}${RED}" "$RESET" "$BOLD" "$RESET" "$*" >&2; }
_status() { "$VERA" --text --list 2>&1 | rg --color=never -Fq ".password.vera"; }
_dismount() { _status && "$VERA" --text --dismount "$VERA_FILE"; }
_die() { _error "$*" && _dismount; exit 1; }
_in() { [[ $1 =~ (^|[[:space:]])$2($|[[:space:]]) ]] && return 0 || return 1; }

# test for ascii art programs
_test_lolcat() { command -v lolcat >/dev/null && lolcat="lolcat" || lolcat="cat"; }
_test_figlet() { _test_lolcat; command -v figlet >/dev/null && figlet -c "$1" | "$lolcat"; }
_test_toilet() { _test_lolcat; command -v >/dev/null && toilet -f smblock -F border --filter gay "$1" | "$lolcat"; }
_fancy_output() { _test_toilet "$1" || _test_figlet "$1" || _success "$1"; }
_screenlength() { _test_lolcat; printf "%$(tput cols)s%b" | tr " " "=" | "$lolcat" >&2; }

# mime-checker functions
_check_gpg_mime() { file --mime --brief "$VERA_KEY" | rg --color=never -q 'pgp-encrypted'; }
_check_decrypted_mime() { file --mime --brief "$VERA_KEY" | rg --color=never -q 'plain'; }
_check_vera_mime() { file --mime --brief "$VERA_KEY" | rg --color=never -q 'octet-stream'; }

# check dependencies needed to use pass vera
_dependency_check() {
  [[ -x "$(command -v "$VERA")" ]] || _die "veracrypt is not present in \$PATH"
  [[ -x "$(command -v rg)" ]] || _die "ripgrep is not present in \$PATH"
  [[ -x "$(command -v sponge)" ]] || _die "GNU moreutils is not present in \$PATH"
  [[ $(uname) == "Darwin" && -x $PlistBuddy ]] || _die "pass-vera only supports macOS right now"
}

cmd_vera_version() {
	cat <<-_EOF
	${GREEN}${PROGRAM} vera${RESET} ${RED}${VERSION}${RESET} - A pass extension that adds another layer of encryption
								by encrypting the password-store inside a veracrypt drive.
	_EOF
}

cmd_vera_usage() {
	cmd_vera_version
	echo
	cat <<-_EOF
	${YELLOW}Usage:${RESET}
	    ${GREEN}${PROGRAM} vera${RESET} ${MAGENTA}<${RESET}${CYAN}gpg-id${RESET}${MAGENTA}>${RESET} ${MAGENTA}[${RESET}${BLUE}-n${RESET}${MAGENTA}]${RESET} ${MAGENTA}[${RESET}${BLUE}-t${RESET} ${YELLOW}time${RESET}${MAGENTA}]${RESET} ${MAGENTA}[${RESET}${BLUE}-f${RESET}${MAGENTA}]${RESET} ${MAGENTA}[${RESET}${BLUE}-p${RESET} ${YELLOW}subfolder${RESET}${MAGENTA}]${RESET} ${MAGENTA}[${RESET}${BLUE}-y${RESET}${MAGENTA}]${RESET} ${MAGENTA}[${RESET}${BLUE}-s${RESET}${MAGENTA}]${RESET}
	                            ${MAGENTA}[${RESET}${BLUE}-i${RESET} ${MAGENTA}|${RESET} ${BLUE}-k${RESET} ${MAGENTA}|${RESET} ${BLUE}--tmp-key${RESET}${MAGENTA}]${RESET} ${MAGENTA}[${RESET}${BLUE}--for-me${RESET}${MAGENTA}]${RESET} ${MAGENTA}[${RESET}${BLUE}-r${RESET}${MAGENTA}]${RESET} ${MAGENTA}[${RESET}${BLUE}-o${RESET}${MAGENTA}]${RESET}
	                            ${MAGENTA}[${RESET}${BLUE}-u ${YELLOW}[a | c ]${RESET}${RESET}${MAGENTA}]${RESET} ${MAGENTA}[${RESET}${BLUE}-c${RESET} ${YELLOW}[a | c ]${RESET}${MAGENTA}]${RESET} ${MAGENTA}[${RESET}${BLUE}-g${RESET} ${YELLOW}[JSON | YAML ]${RESET}${MAGENTA}]${RESET}
	        Create and initialize a new password vera
	        Use gpg-id for encryption of both vera and passwords

	   ${GREEN}${PROGRAM} open${RESET} ${MAGENTA}[${RESET}${YELLOW}subfolder${RESET}${MAGENTA}]${RESET} ${MAGENTA}[${RESET}${BLUE}-i${RESET}${MAGENTA}]${RESET} ${MAGENTA}[${RESET}${BLUE}-y${RESET}${MAGENTA}]${RESET} ${MAGENTA}[${RESET}${BLUE}-t${RESET} ${YELLOW}time${RESET}${MAGENTA}]${RESET} ${MAGENTA}[${RESET}${BLUE}-c${RESET} ${YELLOW}[a | c ]${RESET}${MAGENTA}]${RESET} ${MAGENTA}[${RESET}${BLUE}-f${RESET}${MAGENTA}]${RESET}
	          Open a password vera

	    ${GREEN}${PROGRAM} close${RESET} ${MAGENTA}[${RESET}${BLUE}-c${RESET} ${YELLOW}[a | c ]${RESET}${MAGENTA}]${RESET} ${MAGENTA}[${RESET}${YELLOW}store${RESET}${MAGENTA}]${RESET}
	        Close a password vera

	${MAGENTA}Options:${RESET}
	    ${BLUE}-n${RESET}, ${BLUE}--no-init${RESET}        Do not initialize the password store
	    ${BLUE}-t${RESET}, ${BLUE}--timer${RESET}          Close the store after a given time
	    ${BLUE}-p${RESET}, ${BLUE}--path${RESET}           Create the store for that specific subfolder
	    ${BLUE}-y${RESET}, ${BLUE}--truecrypt${RESET}      Enable compatibility with truecrypt
	    ${BLUE}-k${RESET}, ${BLUE}--vera-key${RESET}       Create a key with veracrypt instead of GPG
	    ${BLUE}-o${RESET}, ${BLUE}--overwrite-key${RESET}  Overwrite existing key
	    ${BLUE}-i${RESET}, ${BLUE}--invisi-key${RESET}     Create a key that doesn't exist when it's not being used
	        ${BLUE}--tmp-key${RESET}        Generate a one time temporary key
	        ${BLUE}--for-me${RESET}         Copy existing password-store to new one when creating vera
	    ${BLUE}-r${RESET}, ${BLUE}--reencrypt${RESET}      Reencrypt passwords when creating to new vera (use with --for-me)
	    ${BLUE}-f${RESET}, ${BLUE}--force${RESET}          Force operation (i.e. even if mounted volume is active)
	    ${BLUE}-s${RESET}, ${BLUE}--status${RESET}         Show status of pass vera (open or closed)
	    ${BLUE}-u${RESET}, ${BLUE}--usage${RESET}          Show space available and space used on the container
	    ${BLUE}-c${RESET}, ${BLUE}--conf${RESET}           Use configuration file (fzf prompt)
	    ${BLUE}-g${RESET}, ${BLUE}--gen-conf${RESET}       Generate configuration file (JSON or YAML)
	    ${BLUE}-q${RESET}, ${BLUE}--quiet${RESET}          Be quiet
	    ${BLUE}-v${RESET}, ${BLUE}--verbose${RESET}        Be verbose
	    ${BLUE}-d${RESET}, ${BLUE}--debug${RESET}          Debug the launchd agent with a stderr file located in \$HOME folder
	        ${BLUE}--unsafe${RESET}         Speed up vera creation (for testing only)
	    ${BLUE}-V${RESET}, ${BLUE}--version${RESET}        Show version information.
	    ${BLUE}-h${RESET}, ${BLUE}--help${RESET}           Print this help message and exit.

	More information may be found in the ${GREEN}pass-vera${RESET}${RED}(${RESET}${BLUE}1${RESET}${RED})${RESET} man page.
_EOF
}

# ==========================================================================================
# === BEGIN HELPER FUNCTIONS ===============================================================
# ==========================================================================================

# launchctl helper functions
_agent_status() { launchctl list | rg -Fq --color=never "pass-close${VERA_FILE##*/}"; }
_launch() { launchctl "$1" "gui/${uid}" "$PLIST_FILE"; }

# check if email given is associated with a trusted key
# $@: list of all the recipients used to encrypt a vera key
is_valid_recipients() {
  typeset -a recipients
  IFS=" " read -r -a recipients <<< "$@"
  # remove the hyphen if you want all keys to be trusted
  trusted='- m f u w s'

  # all the keys ID must be valid (the public keys must be present in the database)
  for gpg_id in "${recipients[@]}"; do
    trust="$($GPG --with-colons --batch --list-keys "$gpg_id" 2> /dev/null | \
            awk 'BEGIN{FS=":"} /^pub/ {print $2; exit}')"
    if [[ $? -ne 0 ]]; then
      _warning "${gpg_id} is not a valid key ID."
      return 1
    elif ! _in "$trusted" "$trust"; then
      _warning "The key ${gpg_id} is not trusted enough"
      return 1
    elif [[ "$trust" == "-" ]]; then
      _warning "The key ${gpg_id} is not trusted enough but is being used anyway."
      _warning "Check to make sure this is your key."
      while true; do
        printf "%b" "\t${BLUE}Do you wish to use ${gpg_id}? [y/N]${RESET} "
        read -r gpg_continue
        case $gpg_continue in
          [Yy]*) break ;;
          [Nn]*) printf "%b\n" "${RED}To use ${PROGRAM} you'll need to choose a different key${RESET}"; exit 1 ;;
          *) printf "%b\n" "${YELLOW}Please enter ${GREEN}yes${RESET} or ${RED}no${RESET}" ;;
        esac
      done
    fi
  done

  # at least one private key must be present
  for gpg_id in "${recipients[@]}"; do
    $GPG --with-colons --batch --list-secret-keys "$gpg_id" &> /dev/null
    if [[ $? -eq 0 ]]; then
      return 0
    fi
  done
  return 1
}

# convert various time formats (e.g., 1hr vs 1 hour)
# $@: file or variable that needs conversion
_time_conversion() {
  local file=("$@")

  if [[ $(echo "${file[@]}" | awk '{print NF}') != 4 ]]; then
    echo "${file[@]}" \
      | sed -E 's/(hr(s)?)/ \1/; s/(min(s)?)/ \1/' \
      | sed -E 's/\bhrs\b/hours/; s/\bhr\b/hour/; s/\bmins\b/minutes/; s/\bmin\b/minute/'
  else
    echo "${file[@]}" \
      | sed -E 's/\bhrs\b/hours/; s/\bhr\b/hour/; s/\bmins\b/minutes/; s/\bmin\b/minute/'
  fi
}

# $1: delay before running launchctl agent to close password store
# $2: path in the password store to save a timer file (not required)
# return 0 on success, 1 otherwise
_timer() {
  local ret delay="$1" path="$2" delay_hour delay_minute
  delay_hour="$(echo "$delay" | rg --color=never -io '\d+\s?h(ou)?r(s)?')"
  delay_minute="$(echo "$delay" | rg --color=never -io '\d+\s?min(ute)?s?')"
  IFS=" " read -r delay_hour delay_minute <<< "$(date -d "++$(_time_conversion "$delay_hour" "$delay_minute")" "+%R" | awk 'BEGIN{FS=":"} {print $1,$2}')"

  [[ -n "$path" ]] && TIMER_FILE="${TIMER_FILE%/*}/${path}/.timer"

  $PlistBuddy -c "Clear dict" "$TMP_PATH" >/dev/null 2>&1
  $PlistBuddy -c "Add :Label string pass-close${VERA_FILE##*/}" "$TMP_PATH" >/dev/null 2>&1
  $PlistBuddy -c "Add :ServiceDescription string Close pass-vera" "$TMP_PATH"
  $PlistBuddy -c "Add :EnvironmentalVariables dict" "$TMP_PATH"
  $PlistBuddy -c "Add :EnvironmentalVariables:PATH string /usr/local/bin:${EXTENSIONS:-$SYSTEM_EXTENSION_DIR}:/usr/local/bin:$(dirname "$(command -v veracrypt)")" "$TMP_PATH"
  $PlistBuddy -c "Add :Program string ${EXTENSIONS:-$SYSTEM_EXTENSION_DIR}/vera-resources/veratimer.sh" "$TMP_PATH"
  $PlistBuddy -c "Add :RunAtLoad bool false" "$TMP_PATH"
  $PlistBuddy -c "Add :StartCalendarInterval dict" "$TMP_PATH"
  $PlistBuddy -c "Add :StartCalendarInterval:Hour integer $delay_hour" "$TMP_PATH"
  $PlistBuddy -c "Add :StartCalendarInterval:Minute integer $delay_minute" "$TMP_PATH"
  $PlistBuddy -c "Add :UserName string $USER" "$TMP_PATH"
  $PlistBuddy -c "Add :Umask integer 23" "$TMP_PATH"

  # add log files if debug is on
  if [[ $DEBUG -eq 1 ]]; then
    $PlistBuddy -c "Add :StandardOutPath string $HOME/pass-vera-stdout.log" "$TMP_PATH"
    $PlistBuddy -c "Add :StandardErrorPath string $HOME/pass-vera-stderr.log" "$TMP_PATH"
  fi

  local ret=$? hour_check min_check digit_check
  hour_check="$($PlistBuddy -c "Print :StartCalendarInterval:Hour" "$TMP_PATH")"
  min_check="$($PlistBuddy -c "Print :StartCalendarInterval:Minute" "$TMP_PATH")"
  # hour_check="$(rg -A1 -N --color=never 'Hour' "$TMP_PATH" | sed -n '2p' | awk 'BEGIN{FPAT="[0-9]+"} {print $1}')"
  # min_check="$(rg -A1 -N --color=never 'Minute' "$TMP_PATH" | sed -n '2p' | awk 'BEGIN{FPAT="[0-9]+"} {print $1}')"
  digit_check="^[0-9]*$"

  if [[ $ret -eq 0 ]]; then
    [[ ! "${hour_check}" =~ ${digit_check} ]] && _die "Incorrectly entered hour. Enter correct format or don't use timer"
    [[ ! "${min_check}" =~ ${digit_check} ]] && _die "Incorrectly entered minute. Enter correct format or don't use timer"
    if [[ -r "$TIMER_FILE" ]]; then
      [[ $(plutil "$TMP_PATH" | cut -d' ' -f2) == "OK" ]] || _die "File is not a plist"
      [[ ! -e "$PLIST_FILE" ]] && mv "$TMP_PATH" "$PLIST_FILE"
      # process of updating the already existing timer
      local delay_original delay_file_mod new_delay now now_delay
      delay_original=$(date -d "$(_time_conversion "$(cat "$TIMER_FILE")")" "+%s")
      delay_file_mod=$(date -r "$TIMER_FILE" "+%s")
      new_delay=$(date -d "+$(_time_conversion "$delay")" "+%s")
      now=$(date "+%s")

      now_delay=$(( $((delay_original - delay_file_mod)) + $((new_delay - now)) ))
      now_delay=$(bc <<< "scale=2; $now_delay/3600")

      new_delay=$(echo "$now_delay" | awk -F'.' '{printf ("%.0f hour %.0f minute\n", $1, $2/100*60)}')
      IFS=" " read -r hour minute <<< "$(date -d "$new_delay" "+%R" | awk -F: '{print $1, $2}')"
      sed -Ei "/Hour/{n;s/[0-9]+/${hour##0}/g}" "$PLIST_FILE"
      sed -Ei "/Minute/{n;s/[0-9]+/${minute##0}/g}" "$PLIST_FILE"
      _verbose "Updating a timer that already existed"
      echo "$new_delay" | tee "$TIMER_FILE" &> /dev/null
      _launch "bootout" && _launch "bootstrap"
      _success "${PLIST_FILE##*/} timer has been updated"
      echo 0
    else
      mv -f "$TMP_PATH" "$PLIST_FILE"
      if _agent_status; then
        # if somehow launch agent is still loaded, yet no timer file exists
        _verbose "Reloading an already running ${PLIST_FILE##*/}"
        _launch "bootout" && _launch "bootstrap"
        _success "${PLIST_FILE##*/} reloaded"
        echo "$delay" | tee "$TIMER_FILE" &> /dev/null
        echo 0
      else
        _verbose "Loading ${PLIST_FILE##*/}, which was not already running"
        _launch "bootstrap"
        _success "${PLIST_FILE##*/} loaded"
        echo "$delay" | tee "$TIMER_FILE" &> /dev/null
        echo 0
      fi
    fi
  else
    _error "Something horrible went wrong"
    echo 1
  fi

  return $ret
}

# set ownership when mounting a veracrypt drive
# $1: veracrpt path
_set_ownership() {
  local path="$1"
  _verbose "Setting user permissions on $path"
  chown -R "$uid:$gid" "$path" || _die "Unable to set ownership permission on $path."
}

# veracrypt helper function
# $@: all veracrypt commands from VERA_MOUNT_OPTS or VERA_CREATE_OPTS
# shellcheck disable=SC2086
_vera() {
  local ret
  $VERA $TRUECRYPT "$@" $FORCE
  ret=$?

  [[ $ret -eq 0 ]] || _die "Unable to $* the password store"
}

#
# === CONF HELPER FUNCTIONS ===============================================================
#

# fuzzy finder for configuration directory
_fzf_conf() {
  [[ -x "$(command -v fzf)" ]] || _die "fzf is not present in \$PATH"
  cust_conf_file="$(
    fzf --ansi +m \
        --exit-0 \
        --delimiter / \
        --with-nth -1 \
        --prompt="pass-vera> " < <( find "$conf_dir" -type f -regex ".*\.\(yaml\|json\)")
  )"
}

# generate json or yaml configuration file
# $1: file type user generates (either YAML or JSON)
_gen_conf() {
  local ftype="$1"
  mkdir -p "$conf_dir"
  case ${ftype,,} in
    json)
      [[ -x "$(command -v jq)" ]] || _die "jq needed to generate JSON configuration"
      jq --arg key0 "volume-type" \
         --arg value0 'normal' \
         --arg key1   'size' \
         --arg value1 "${VERA_SIZE}M" \
         --arg key2   'create' \
         --arg value2 "$VERA_FILE" \
         --arg key3   'encryption' \
         --arg value3 'aes-twofish-serpent' \
         --arg key4   'hash' \
         --arg value4 'sha-512' \
         --arg key5   'filesystem' \
         --arg value5 'exFAT' \
         --arg key6   'pim' \
         --arg value6 '0' \
         --arg key7   'keyfiles' \
         --arg value7 "$VERA_KEY" \
         --arg key8   'random-source' \
         --arg value8 '/dev/urandom' \
         --arg key9   'truecrypt' \
         --arg value9 '0' \
         --arg key10  'unsafe' \
         --arg value10 '0' \
         --arg key11   'slot' \
         --arg value11 '0' \
       '. | .[$key0]=$value0 | .[$key1]=$value1 | .[$key2]=$value2 | .[$key3]=$value3 | .[$key4]=$value4 | .[$key5]=$value5 | .[$key6]=$value6 | .[$key7]=$value7 | .[$key8]=$value8 | .[$key9]=$value9 | .[$key10]=$value10 | .[$key11]=$value11' \
       <<<'{}' > "${conf_dir}/vera.json"
      _success "Configuration example created: ${conf_dir}/vera.json"
       ;;
    yaml)
      [[ -x "$(command -v yq)" ]] || _die "yq is needed to generate YAML configuration"
      echo "\
        volume-type: normal
        create: ${PASSWORD_STORE_VERA_FILE:-$HOME/.password.vera}
        size: 15M
        encryption: aes-twofish-serpent
        hash: sha-512
        filesystem: exFAT
        pim: 0
        keyfiles: ${PASSWORD_STORE_VERA_KEY:-$HOME/.password.vera.key}
        random-source: /dev/urandom
        truecrypt: 0
        unsafe: 0
        slot: 0" \
          | yq e -n > "${conf_dir}/vera.yaml"
      _success "Configuration example created: ${conf_dir}/vera.yaml"
      ;;
    *) _error "Specify filetype: JSON or YAML"
      ;;
  esac
}


# determine configuration file type (JSON vs YAML) for auto config
_conf_file_type() {
  local files cust_ext
  # function to count file type in conf_dir
  _lsdir() {
    /bin/ls -1A "$conf_dir" | rg --color=never "${@}" | wc -l
  }

  files="$(_lsdir "\.json$|\.yaml$")"

  if [[ -n "${PASSWORD_STORE_VERA_CONF}" ]]; then
    VERA_CONF="${PASSWORD_STORE_VERA_CONF}"
    _message "Using \$PASSWORD_STORE_VERA_CONF"
  elif [[ $files -gt 1 ]]; then
    _warning "More than one configuration..."
    while true; do
      printf "%b" "\t${BLUE}Do you wish to choose a configuration? [y/N]${RESET} "
      read -r choose_conf
      case $choose_conf in
        [Yy]*) break ;;
        [Nn]*)
          _warning "Do one of the following:"
          _warning "${RED}(1)${RESET} Have only one configuration in the folder"
          _warning "${RED}(2)${RESET} Do not use the auto command"
          _warning "${RED}(3)${RESET} Set \$PASSWORD_STORE_VERA_CONF"
          exit 1
          ;;
        *) printf "%b\n" "${YELLOW}Please enter ${GREEN}yes${RESET} or ${RED}no${RESET}" ;;
      esac
    done
    _fzf_conf
    cust_conf_file="${cust_conf_file##*/}"
    cust_ext=${cust_conf_file#*.}
    [[ ! "${cust_ext,,}" =~ (yaml|json) ]] && _die "Filetype must be JSON or YAML"
    # PASSWORD_STORE_VERA_CONF:+ is there as a precaution
    _message "Using ${cust_ext^^} configuration: ${CYAN}${cust_conf_file}${RESET} ${PASSWORD_STORE_VERA_CONF:+ -- NOTE: \$PASSWORD_STORE_VERA_CONF is set, using that instead}"
    VERA_CONF="${conf_dir}/${cust_conf_file}"
  elif [[ $(_lsdir "\.json$") -eq 1 ]]; then
    _message "Using JSON configuration: ${CYAN}vera.json${RESET} ${PASSWORD_STORE_VERA_CONF:+ -- NOTE: \$PASSWORD_STORE_VERA_CONF is set, using that instead}"
    VERA_CONF="${PASSWORD_STORE_VERA_CONF:-$conf_dir/vera.json}"
  elif [[ $(_lsdir "\.yaml$") -eq 1 ]]; then
    _message "Using YAML configuration: ${CYAN}vera.yaml${RESET} ${PASSWORD_STORE_VERA_CONF:+ -- NOTE: \$PASSWORD_STORE_VERA_CONF is set, using that instead}"
    VERA_CONF="${PASSWORD_STORE_VERA_CONF:-$conf_dir/vera.yaml}"
  fi
}

# parse configuration file
# $1: user input of custom config or auto config
_check_conf() {
  local conf_type="$1"
  case "${conf_type}" in
    c|custom)
      # choose custom configuration with fzf
      _fzf_conf
      VERA_CONF="${conf_dir}/${cust_conf_file}"
      ;;
    a|auto)
      # automatically choose the one configuration
      _conf_file_type
      ;;
    *) _die "Choose a|auto or c|custom"
      ;;
  esac
  if [[ -e $VERA_CONF ]]; then
    check_sneaky_paths "$VERA_CONF"
    typeset -A VERA_CREATE_CONF
    VERA_CREATE_CONF=()
    if [[ ${VERA_CONF: -4} == "yaml" ]]; then
      while read -r l; do
        if echo "$l" | rg --color=never -F '=' &>/dev/null; then
          vname=$(echo "$l" | cut -d '=' -f1)
          VERA_CREATE_CONF[$vname]=$(echo "$l" | cut -d '=' -f2-)
        fi
      done < <(sed -e '/^#/d; s/:[^:]/=/g; s/= */=/g;'  "$VERA_CONF")
    elif [[ ${VERA_CONF: -4} == "json" ]]; then
      VERA_CREATE_CONF[volume-type]=$(jq -r '."volume-type"' "$VERA_CONF")
      VERA_CREATE_CONF[create]=$(jq -r '.create' "$VERA_CONF")
      VERA_CREATE_CONF[size]=$(jq -r '.size' "$VERA_CONF")
      VERA_CREATE_CONF[encryption]=$(jq -r '.encryption' "$VERA_CONF")
      VERA_CREATE_CONF[hash]=$(jq -r '.hash' "$VERA_CONF")
      VERA_CREATE_CONF[filesystem]=$(jq -r '.filesystem' "$VERA_CONF")
      VERA_CREATE_CONF[pim]=$(jq -r '.pim' "$VERA_CONF")
      VERA_CREATE_CONF[keyfiles]=$(jq -r '.keyfiles' "$VERA_CONF")
      VERA_CREATE_CONF[random-source]=$(jq -r '."random-source"' "$VERA_CONF")
      VERA_CREATE_CONF[truecrypt]=$(jq -r '.truecrypt' "$VERA_CONF")
      VERA_CREATE_CONF[unsafe]=$(jq -r '.unsafe' "$VERA_CONF")
      VERA_CREATE_CONF[slot]=$(jq -r '.slot' "$VERA_CONF")
    fi
      [[ "${VERA_CREATE_CONF[truecrypt]}" -eq 0 ]] && unset 'VERA_CREATE_CONF[truecrypt]'
      [[ "${VERA_CREATE_CONF[unsafe]}" -eq 0 ]] && unset 'VERA_CREATE_CONF[unsafe]'
      [[ "${VERA_CREATE_CONF[slot]}" -eq 0 ]] && unset 'VERA_CREATE_CONF[slot]'
      VERA_FILE="${VERA_CREATE_CONF[create]}" && unset 'VERA_CREATE_CONF[create]'
      VERA_SIZE="${VERA_CREATE_CONF[size]%M}"
      VERA_KEY="${VERA_CREATE_CONF[keyfiles]}"

      VERA_CREATE_OPTS=()
      IFS=" " read -r -a VERA_CREATE_OPTS <<< "$(
      for x in "${!VERA_CREATE_CONF[@]}"; do
        if [[ $x == 'truecrypt' || $x = 'unsafe' ]]; then
          printf "%s " "--${x}"
        elif [[ $x == 'keyfiles' ]]; then
          printf "%s " "--${x}"
          printf "%s " "${VERA_CREATE_CONF[$x]}"
        else
          printf "%s=%s " "--${x}" "${VERA_CREATE_CONF[$x]// /-}"
        fi
      done
      )"

      VERA_CREATE_OPTS=( "--text" "--create" "$VERA_FILE" "${VERA_CREATE_OPTS[@]}" )
      VERA_MOUNT_OPTS=( "--text" "--keyfiles" "$VERA_KEY" "--pim=0" "--protect-hidden=no" "--mount" "$VERA_FILE" "${PREFIX}/${path}" )
  fi
}

#
# === KEY HELPER FUNCTIONS ================================================================
#

# add recipients to gpg encryption
_gen_key_recipients() {
  KEY_RECIPIENTS=( )
  for key_id in "${RECIPIENTS[@]}"; do
    KEY_RECIPIENTS+=( "-r" "$key_id" )
  done
}

# gerate the gpg key
_gpg_key() {
  _gen_key_recipients
  [[ ! -f $VERA_KEY || $OVERWRITE_KEY -eq 1 ]] && ${EDITOR:-vim} "$VERA_KEY"
  [[ -f $VERA_KEY ]] || _die "No phrase was entered"
  # sponge absorbs the file contents beforew writing to it, otherwise it is no decryptable
  # alternative is to use a temporary file
  $GPG -o- "${GPG_OPTS[@]}" "${KEY_RECIPIENTS[@]}" -e "$VERA_KEY" | sponge "$VERA_KEY" ||
    _die "Could not encrypt phrase"
}

# generate the temporary key (never accessible again)
_tmp_key() {
  _gen_key_recipients
  tmpdir
  tmp_vera="$(mktemp -u "$SECURE_TMPDIR/XXXXXXXXXXXXXXXXXXXX")"
  ${EDITOR:-vim} "$tmp_vera"
  [[ -f $tmp_vera ]] || _die "No phrase was entered"
  # encrypt key & overwrite it so it can never be decrypted
  $GPG -o "$tmp_vera" "${GPG_OPTS[@]}" "${KEY_RECIPIENTS[@]}" -e "$tmp_vera" ||
    _die "Could not encrypt phrase"
}

# generate the key that deletes itself but is reusable
_invisi_key() {
  _gen_key_recipients
  tmpdir
  invisi_vera="$SECURE_TMPDIR/.invisi.key"
  ${EDITOR:-vim} "$invisi_vera"
  [[ -f $invisi_vera ]] || _die "No phrase was entered"
}

# function that uses the above functions to create a key
_create_key() {
  if [[ $MAKE_VERAKEY -eq 1 ]]; then
    _vera --text --create-keyfile "$VERA_KEY" --random-source=/dev/urandom
    _fancy_output "Verakey created"
  elif [[ $TMP_KEY -eq 1 ]]; then
    _tmp_key && _fancy_output "Temp key created"
  elif [[ $INVISI_KEY -eq 1 ]]; then
    _invisi_key && _fancy_output "Invisible key created"
  else
    _gpg_key && _fancy_output "GPG key created"
  fi
}

_check_key() {
  if [[ ! -e "$VERA_KEY" ]]; then
    _create_key
    _verbose "Creating a key for the first time"
  elif [[ -e "$VERA_KEY" && "$OVERWRITE_KEY" -eq 1 ]]; then
    yesno "You are overwriting an existing key and existing pass-vera file. Continue?"
    rm -rf "$VERA_KEY" && rm -rf "$VERA_FILE"
    _create_key
    _warning "Overwriting an existing setup"
  else
    _die "The vera key $VERA_KEY already exists. It won't be overwritten"
  fi
}

# get the available space on any vera container
_show_usage() {
  local all size used use
  local cust_vera="$1"
  _status || _die "pass-vera not mounted"
  case "${cust_vera}" in
    c|custom)
      all="$(
      df -h "$(
        "$VERA" --text --list \
        | fzf --ansi +m \
              --exit-0 \
              --delimiter / \
              --with-nth -2,-1 \
              --prompt="vera containers> " \
          | rev | cut -d ' ' -f1 | rev
          )"
        )"
      ;;
    a|auto)
      all=$(df -h "$("$VERA" --text --list | grep 'password.vera' | rev | cut -d ' ' -f1 | rev)")
      ;;
    *) _die "Chose a|auto or c|custom"
        ;;
  esac
  size=$(awk 'NR==2{print $2}' <<< "$all")
  used=$(awk 'NR==2{print $3}' <<< "$all")
  use=$(awk 'NR==2{print $5}' <<< "$all")
  # convert kilobyte to megabyte if need be
  [[ ${used: -1} == "K" ]] && used="$(bc <<< "scale=2; ${used%?} / 1000")"

  if [[ ${use%?} -gt 80 ]]; then
    local COLOR="${GREEN}"
  elif [[ ${use%?} -ge 50 && ${use%?} -le 80 ]]; then
    local COLOR="${YELLOW}"
  else
    local COLOR="${RED}"
  fi

  printf "  %b  %b %s/%s %b %s %b\n" "${BOLD}.${RESET}" "${CYAN}pass-vera usage:${RESET} ${BLUE}[${RESET}${COLOR}" "$used" "$size" "${RESET}${BLUE}] [${RESET}${COLOR}" "$use"  "${RESET}${BLUE}]${RESET}"
}

# =========================================================================================
# === END HELPER FUNCTIONS ================================================================
# =========================================================================================

# open a password vera
# $1: subfolder path to mount veracrypt to
cmd_open() {
  local path="$1"; shift;

  # precautions
  check_sneaky_paths "$path" "$VERA_FILE" "$VERA_KEY"
  [[ -e "$VERA_FILE" ]] || _die "There is no password vera to open."
  [[ -e "$VERA_KEY" ]] || [[ $INVISI_KEY -eq 1 ]] || _die "There is no password vera key."
  [[ -n "$path" ]] && VERA_MOUNT_OPTS=("${VERA_MOUNT_OPTS[@]/${PREFIX}/${PREFIX}/${path}}")
  [[ $CONF -eq 1 ]] && _check_conf "$CUST_CONF"

  # open the password vera
  _status
  if [[ $? -ne 0 ]]; then
    if [[ $INVISI_KEY -eq 1 ]]; then
      _invisi_key && VERA_MOUNT_OPTS[2]=$invisi_vera
      _verbose "Opening the password vera ${CYAN}$VERA_FILE${RESET} using the key ${CYAN}$invisi_vera${RESET}"
    else
      _verbose "Opening the password vera ${CYAN}$VERA_FILE${RESET} using the key ${CYAN}$VERA_KEY${RESET}"
    fi

    # if key is encrypted, decrypt it
    _check_gpg_mime &&
      $GPG -o "$VERA_KEY" "${GPG_OPTS[@]}" -d "$VERA_KEY"

    _vera "${VERA_MOUNT_OPTS[@]}"

    # if key is decrypted, encrypt it
    _check_decrypted_mime &&
      $GPG -o- "${GPG_OPTS[@]}" "${KEY_RECIPIENTS[@]}" -e "$VERA_KEY" | sponge "$VERA_KEY"

    _set_ownership "${PREFIX}/${path}"
  else
    _warning "The veracrypt drive is already mounted, not opening"
  fi

  # read, initialize and start the timer
  local -i timed=1
  if [[ -z "$TIMER" ]]; then
    [[ -r "$TIMER_FILE" ]] && rm -f "$TIMER_FILE"
  else
    timed="$(_timer "$TIMER" "$path")"
  fi

  # command executed as planned
  [[ -n $VERA_CONF ]] && _message "Your conf is: ${CYAN}${VERA_CONF}${RESET}"
  _success "Your password vera has been opened in ${PREFIX}/${path}."
  _message "You can now use pass as usual."
  # _show_usage
  if [[ $timed -eq 0 ]]; then
    # if the addition to original time is under an hour
    if rg --color=never -q "^0" "$TIMER_FILE"; then
      TIMER=$(awk '{print $3,$4}' "$TIMER_FILE")
      _verbose "Updating timer that is under an hour"
    # if the addition to original time is above an hour
    elif [[ $(awk '{print NF}' "$TIMER_FILE") -eq 4 ]]; then
      TIMER="$TIMER_FILE"
      _verbose "Updating timer that is above an hour"
    fi
    _message "This password store will be closed in: ${RED}${TIMER}${RESET}"
  else
    _message "When finished, close the password vera using '${BLUE}pass close${RESET}'."
  fi
  return 0
}

# close a password vera
# $1: file in which veracrypt is associated with that will be closed
cmd_close() {
  local _vera_name _vera_file="$1"
  [[ $CONF -eq 1 ]] && _check_conf "$CUST_CONF"

  [[ -z "$_vera_file" ]] && _vera_file="$VERA_FILE"

  # precautions
  check_sneaky_paths "$_vera_file"
  _vera_name="${_vera_file##*/}"
  _vera_name="${_vera_name%.*}"
  [[ -z "$_vera_name" ]] && _die "There is no password vera."

  _verbose "Closing the password vera $_vera_file"
  [[ -e "$TIMER_FILE" ]] && rm -f "$TIMER_FILE" && _message "Your timer has been removed"
  _dismount || _die "The password store is not mounted."
  if _agent_status; then
    _launch "bootout" && _success "Your launch agent has been unloaded"
  fi

  _success "Your password vera has been closed"
  [[ -n $VERA_CONF ]] && _message "Your conf is: ${CYAN}${VERA_CONF}${RESET}"
  _message "Your passwords remain present in ${BLUE}$_vera_file${RESET}"
  return 0
}

# create a new password vera and initialize the password repository
# $1: path subfolder
# $@: gpg-ids
cmd_vera() {
  # if status is passed, return only that (has to be above rest)
  if [[ $STATUS -eq 1 ]]; then
    _status
    [[ $? -eq 0 ]] && _fancy_output "password-vera is open" || _fancy_output "password-vera is closed"
    exit 1
  fi

  local path="$1"; shift;
  typeset -a RECIPIENTS
  [[ -z "$*" ]] && _die "${GREEN}$PROGRAM $COMMAND${RESET} <gpg-id> [-n] [-t time] [-f] [-p subfolder] [-c] [-k|--tmp-key|-i] [-o] [-s] [-r] [-g] [--for-me]"
  IFS=" " read -r -a RECIPIENTS <<< "$@"

  _finish_for_me() {
    [[ $DIFM -eq 2 && -e "${PREFIX}/${path}" ]] &&
      find "$tmp_dir" -mindepth 1 -maxdepth 1 -exec mv -t "${PREFIX}/${path}" '{}' + &&
      rm -rf "$tmp_dir"
  }

  [[ $CONF -eq 1 ]] && _check_conf "$CUST_CONF"

  # precautions
  check_sneaky_paths "$path" "$VERA_FILE" "$VERA_KEY"
  if ! is_valid_recipients "${RECIPIENTS[@]}"; then
    _die "You set an invalid GPG ID."
  elif [[ -e "$VERA_FILE" ]]; then
    _die "The password vera $VERA_FILE already exists. It won't be overwritten."
  elif [[ "$VERA_SIZE" -lt 15 ]]; then
    _die "A password vera cannot be smaller than 15 MB."
  fi

  _check_key

  [[ -n "$path" ]] &&
    VERA_MOUNT_OPTS=("${VERA_MOUNT_OPTS[@]/${PREFIX}/${PREFIX}/${path}}") &&
    mkdir -p "${PREFIX}/${path}"

  if [[ $UNSAFE -ne 0 ]]; then
    _warning "Using unsafe mode to speed up vera generation."
    _warning "Only use it for testing purposes."
    local unsafe=( "--quick" )
    # check in case it was used in a custom config
    if [[ ! "${VERA_CREATE_OPTS[*]}" =~ ${unsafe[*]} ]]; then
      VERA_CREATE_OPTS=( "${VERA_CREATE_OPTS[@]:0:1}" "${unsafe[@]}" "${VERA_CREATE_OPTS[@]:1}" )
    fi
  fi

  _verbose "Creating a password vera with the GPG key(s): ${RECIPIENTS[*]}"

  if [[ $DIFM -eq 1 ]]; then
    if [[ -e "${PREFIX}/${path}" ]]; then
      [[ $(du -sh "${PREFIX}/${path}" | cut -f1 | tr -d '[:upper:]') -lt $VERA_SIZE ]] || _die "${PREFIX}/${path} is ${RED}larger${RESET} than $VERA_SIZE"
      local tmp_dir="${PREFIX%/*}/tmp"
      mkdir -p "$tmp_dir"
      printf "  %b\n\t\t%b%s%b\n" "${CYAN}Automatically transferring password store:${RESET}" "${RED}[ ${RESET}${GREEN}" "${PREFIX}/${path}" "${RESET}${RED} ]${RESET}"
      find "${PREFIX}/${path}" -mindepth 1 -maxdepth 1 ! -name '.gpg-id' -exec mv -t "$tmp_dir" '{}' +
      rm -rf "${PREFIX:?}/${path}"
      DIFM=2
    else
      _warning "${PREFIX}/${path} does not exist, continuing anyway"
    fi
  fi

  # if key is encrypted, decrypt it
  _check_gpg_mime &&
    $GPG -o "$VERA_KEY" "${GPG_OPTS[@]}" -d "$VERA_KEY"

  # if invisi key or tmp key was passed, create vera with that key type
  for f in $invisi_vera $tmp_vera; do
    [[ -e "$f" ]] &&
    for i in "${!VERA_CREATE_OPTS[@]}"; do
      if [[ "${VERA_CREATE_OPTS[$i]}" = "--keyfiles" ]]; then
        VERA_CREATE_OPTS[(($i + 1))]="$f"
      fi
    done
  done

  _vera "${VERA_CREATE_OPTS[@]}"

  # if ivisi-key was passed, change vera_key to an invisible one
  [[ -e "$invisi_vera" ]] && VERA_MOUNT_OPTS[2]=$invisi_vera
  [[ -e "$tmp_vera" ]] && VERA_MOUNT_OPTS[2]=$tmp_vera

  _fancy_output "mounting now"

  _vera "${VERA_MOUNT_OPTS[@]}"

  # if key is decrypted, encrypt it
  _check_decrypted_mime &&
    $GPG -o- "${GPG_OPTS[@]}" "${KEY_RECIPIENTS[@]}" -e "$VERA_KEY" | sponge "$VERA_KEY"

  [[ $REENCRYPT -eq 1 ]] && _finish_for_me

  _set_ownership "${PREFIX}/${path}"

  # use the same recipients to initialize the password store
  local ret path_cmd=()
  if [[ $NOINIT -eq 0 ]]; then
    [[ -z "$path" ]] || path_cmd=("--path=${path}")
    ret="$(cmd_init "${RECIPIENTS[@]}" "${path_cmd[@]}")"
    if [[ ! -e "${PREFIX}/${path}/.gpg-id" ]]; then
      _warning "$ret"
      _die "Unable to initialize the password store."
    fi
  fi

  [[ $REENCRYPT -ne 1 ]] && _finish_for_me

  # initialization of timer
  local timed=1
  [[ -z "$TIMER" ]] || timed="$(_timer "$TIMER" "$path")"

  # command executed as planned
  _success "Your password vera has been created and opened in: ${CYAN}${PREFIX}/${path}${RESET}"
  [[ -z "$ret" ]] || _success "$ret"
  _message "Your vera is: ${CYAN}${VERA_FILE}${RESET}"
  [[ -n $VERA_CONF ]] && _message "Your conf is: ${CYAN}${VERA_CONF}${RESET}"

  for f in $invisi_vera $tmp_vera $VERA_KEY; do
    [[ -e "$f" ]] && _message "Your vera key is: ${CYAN}${f}${RESET}"
  done

  if [[ -z "$ret" ]]; then
    _message "You need to initialize the store with 'pass init gpg-id...'."
  else
    _message "You can now use pass as usual."
  fi

  if [[ $timed -eq 0 ]]; then
    # if the addition to original time is under an hour
    if rg --color=never -q "^0" "$TIMER_FILE"; then
      TIMER=$(awk '{print $3,$4}' "$TIMER_FILE")
    # if the addition to original time is above an hour
    elif [[ $(awk '{print NF}' "$TIMER_FILE") -eq 4 ]]; then
      TIMER="$TIMER_FILE"
    fi
    _message "This password store will be closed in: ${RED}${TIMER}${RESET}"
  else
    _message "When finished, close the password vera using '${BLUE}pass close${RESET}'."
  fi
  return 0
}

_dependency_check

# global options
UNSAFE=0
VERBOSE=0
DEBUG=0
QUIET=0
FORCE=""
NOINIT=0
TIMER=""
OVERWRITE_KEY=0
MAKE_VERAKEY=0
INVISI_KEY=0
TMP_KEY=0
TRUECRYPT=""
STATUS=0
DIFM=0 # do it for me
REENCRYPT=0
CONF=0
CUST_CONF=""

# program arguments using GNU getopt
small_arg="vhVdokrg:yc:isp:qnt:fu:"
long_arg="verbose,help,debug,version,overwrite-key,vera-key,path:,truecrypt,unsafe,quiet,no-init,timer:,force,status,tmp-key,for-me,reencrypt,invisi-key,usage:,conf:,gen-conf:"
opts="$($GETOPT -o $small_arg -l $long_arg -n "$PROGRAM $COMMAND" -- "$@")"
err=$?
eval set -- "$opts"
while true; do case $1 in
  -q|--quiet) QUIET=1; VERBOSE=0; shift ;;
  -v|--verbose) VERBOSE=1; shift ;;
  -o|--overwrite-key) OVERWRITE_KEY=1; shift ;;
  -u|--usage) _show_usage "$2"; shift; exit 0 ;;
  -k|--vera-key) MAKE_VERAKEY=1; shift ;;
  -i|--invisi-key) INVISI_KEY=1; shift ;;
  -g|--gen-conf) _gen_conf "$2"; shift 2; exit 0 ;;
  -c|--conf) CUST_CONF="$2"; CONF=1; shift 2 ;;
  --tmp-key) TMP_KEY=1; shift ;;
  --for-me) DIFM=1; shift ;;
  -r|--reencrypt) REENCRYPT=1; shift ;;
  -f|--force) FORCE="--force"; shift ;;
  -h|--help) shift; cmd_vera_usage; exit 0 ;;
  -V|--version) shift; cmd_vera_version; exit 0 ;;
  -p|--path) id_path="$2"; shift 2 ;;
  -t|--timer) TIMER="$2"; shift 2 ;;
  -n|--no-init) NOINIT=1; shift ;;
  -y|--truecrypt) TRUECRYPT="--truecrypt"; shift ;;
  -s|--status) STATUS=1; shift ;;
  -d|--debug) DEBUG=1; shift ;;
  --unsafe) UNSAFE=1; shift ;;
  --) shift; break ;;
esac done

[[ -z "$TIMER" ]] || [[ -x "$(command -v launchctl)" ]] || _die "launchctl is not present"
[[ $err -ne 0 ]] && cmd_vera_usage && exit 1
[[ "$COMMAND" == "vera" ]] && cmd_vera "$id_path" "$@"
