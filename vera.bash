#!/usr/bin/env bash

readonly VERA="${PASSWORD_STORE_VERA:-veracrypt}"
readonly VERA_FILE="${PASSWORD_STORE_VERA_FILE:-$HOME/.password.vera}"
readonly VERA_KEY="${PASSWORD_STORE_VERA_KEY:-$HOME/.password.vera.key}"
readonly VERA_SIZE="${PASSWORD_STORE_VERA_SIZE:-10}"

readonly TMP_PATH="/tmp/pass-close${VERA_FILE##*/}.plist"
readonly PLIST_FILE="${HOME}/Library/LaunchAgents/${TMP_PATH##*/}"
readonly TIMER_FILE="${PREFIX}/.timer"

readonly VERSION="1.0"

readonly RED=$(tput setaf 1) GREEN=$(tput setaf 2) YELLOW=$(tput setaf 3)
readonly BLUE=$(tput setaf 4) MAGENTA=$(tput setaf 5) CYAN=$(tput setaf 6)
readonly BOLD=$(tput bold) RESET=$(tput sgr0) UNDERLINE=$(tput smul)

_message() { [ "$QUIET" = 0 ] && printf '  %b.%b  %s\n' "$BOLD" "$RESET" "$*" >&2; }
_warning() { [ "$QUIET" = 0 ] && printf '  %bw%b  %b%s%b\n' "${BOLD}${YELLOW}" "$RESET" "$YELLOW" "$*" "$RESET" >&2; }
_success() { [ "$QUIET" = 0 ] && printf ' %b(*)%b %b%s%b\n' "${BOLD}${GREEN}" "$RESET" "$GREEN" "$*" "$RESET" >&2; }
_verbose() { [ "$VERBOSE" = 0 ] || printf '  %b.%b  %bpass%b %s\n' "${BOLD}${MAGENTA}" "$RESET" "$MAGENTA" "$RESET" "$*" >&2; }
_verbose_vera() { [ "$VERBOSE" = 0 ] || printf '  %b.%b  %s\n' "${BOLD}${MAGENTA}" "$RESET" "$*" >&2; }
_error() { printf ' %b[x]%b %bError:%b %s\n' "${BOLD}${RED}" "$RESET" "$BOLD" "$RESET" "$*" >&2; }
_dismount() { if ! veracrypt -t -l 2>&1 | rg --color=never "Error" &>/dev/null; then "$VERA" --text --dismount "$VERA_FILE"; fi }
_screenlength() { screenlength=$(printf "%$(tput cols)s%b" | tr " " "="); printf "%b%s%b\n" "$MAGENTA" "$screenlength" "$RESET" >&2; }
_die() { _error "$*" && _dismount; exit 1; }
_in() { [[ $1 =~ (^|[[:space:]])$2($|[[:space:]]) ]] && return 0 || return 1; }

# pass vera depends on veracrypt
_dependency_check() {
	command -v "$VERA" &> /dev/null || _die "veracrypt is not present in your \$PATH"
	command -v rg &> /dev/null || _die "ripgrep is not present \$PATH"
  command -v getopt &> /dev/null || _die "getopt is not present \$PATH, install 'GNU coreutils'"
}

# $@ is the list of all the recipient used to encrypt a vera key
is_valid_recipients() {
	typeset -a recipients
	IFS=" " read -r -a recipients <<< "$@"
  # Remove the hyphen if you want all keys to be trusted
	trusted='- m f u w s'

	# All the keys ID must be valid (the public keys must be present in the database)
	for gpg_id in "${recipients[@]}"; do
		trust="$(gpg --with-colons --batch --list-keys "$gpg_id" 2> /dev/null | \
				    awk 'BEGIN { FS=":" } /^pub/ { print $2; exit}')"
		if [[ $? != 0 ]]; then
			_warning "${gpg_id} is not a valid key ID."
			return 1
		elif ! _in "$trusted" "$trust"; then
			_warning "The key ${gpg_id} is not trusted enough"
			return 1
    elif [[ "$trust" == "-" ]]; then
      _warning "The key ${gpg_id} is not trusted enough but is being used anyway. Check to make sure this is your key."
      while true; do
        printf "%b\n> " "${BLUE}Do you wish to use ${gpg_id}?${RESET}"
        read -r gpg_continue
        case $gpg_continue in
          [Yy]*) break ;;
          [Nn]*) printf "%b\n" "${RED}To use ${PROGRAM} you'll need to choose a different key${RESET}"; exit 1 ;;
            *) printf "%b\n" "${YELLOW}Please enter ${GREEN}yes${RESET} or ${RED}no${RESET}" ;;
        esac
      done
		fi
	done

	# At least one private key must be present
	for gpg_id in "${recipients[@]}"; do
		gpg --with-colons --batch --list-secret-keys "$gpg_id" &> /dev/null
		if [[ $? = 0 ]]; then
			return 0
		fi
	done
	return 1
}

_time_conversion() {
  local file="$@"

  if [[ $(echo "$file" | awk '{print NF}') != 4 ]]; then
    echo "$file" \
      | sed -E 's/(hr(s)?)/ \1/; s/(min(s)?)/ \1/' \
      | sed -E 's/\bhrs\b/hours/; s/\bhr\b/hour/; s/\bmins\b/minutes/; s/\bmin\b/minute/'
  else
    echo "$file" \
      | sed -E 's/\bhrs\b/hours/; s/\bhr\b/hour/; s/\bmins\b/minutes/; s/\bmin\b/minute/'
  fi
}

_agent_status() { launchctl list | rg -Fq --color=never "${PLIST_FILE##*/}"; }
_launch() { launchctl "$1" "gui/${uid}" "$PLIST_FILE"; }

# $1: Delay before to run the pass-close service
# $2: Path in the password store to save the delay (may be empty)
# return 0 on success, 1 otherwise
_timer() {
	local ret delay="$1" path="$2"
  local uid=$(id -u)
  local delay_hour="$(echo "$delay" | rg --color=never -io '\d+\s?h(ou)?r(s)?')"
  local delay_minute="$(echo "$delay" | rg --color=never -io '\d+\s?min(ute)?s?')"
  IFS=" " read -r delay_hour delay_minute <<< $(date -d "++$(_time_conversion "$delay_hour" "$delay_minute")" "+%R" | awk 'BEGIN{FS=":"} {print $1,$2}')

  local launch_debug=""
  if [[ "$DEBUG" == 1 ]]; then
    launch_debug="<key>StandardErrorPath</key>
      <string>$HOME/pass-vera-stderr.log</string>
    <key>StandardOutPath</key>
      <string>$HOME/pass-vera-stdout.log</string>"
  fi

  cat <<-_EOF | tee "$TMP_PATH" &> /dev/null
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>${TMP_PATH##*/}</string>
    <key>ServiceDescription</key>
    <string>Close pass-vera</string>
    <key>EnvironmentalVariables</key>
    <dict>
      <key>PATH</key>
      <string>/usr/local/bin:${PASSWORD_STORE_EXTENSIONS_DIR:-$PASSWORD_STORE_DIR/.extensions}:/usr/local/bin:$(dirname $(command -v veracrypt))</string>
    </dict>
    <key>ProgramArguments</key>
    <array>
      <string>/bin/sh</string>
      <string>${PASSWORD_STORE_EXTENSIONS_DIR:-$PASSWORD_STORE_DIR/.extensions}/vera-resources/veratimer</string>
    </array>
    <key>RunAtLoad</key>
      <false/>
    <key>StartCalendarInterval</key>
    <dict>
      <key>Hour</key>
      <integer>$delay_hour</integer>
      <key>Minute</key>
      <integer>$delay_minute</integer>
    </dict>
    <key>UserName</key>
      <string>$USER</string>
    <key>Umask</key>
      <integer>23</integer>
    $launch_debug
  </dict>
</plist>
_EOF

  local ret=$?
  local hour_check="$(rg -A1 -N --color=never 'Hour' "$TMP_PATH" | sed -n '2p' | awk 'BEGIN{FPAT="[0-9]+"} {print $1}')"
  local min_check="$(rg -A1 -N --color=never 'Minute' "$TMP_PATH" | sed -n '2p' | awk 'BEGIN{FPAT="[0-9]+"} {print $1}')"
  local digit_check="^[0-9]*$"

  if [[ $ret == 0 ]]; then
    [[ ! "${hour_check}" =~ ${digit_check} ]] && _error "Incorrectly entered hour" && exit 1
    [[ ! "${min_check}" =~ ${digit_check} ]] && _error "Incorrectly entered minute" && exit 1
    if [[ -r "$TIMER_FILE" ]]; then
      [[ ! -e "$PLIST_FILE" ]] && mv "$TMP_PATH" "$PLIST_FILE"
      local delay_original=$(date -d "$(_time_conversion "$(cat "$TIMER_FILE")")" "+%s")
      local delay_file_mod=$(date -r "$TIMER_FILE" "+%s")
      local new_delay=$(date -d "+$(_time_conversion $delay)" "+%s")
      local now=$(date "+%s")

      local now_delay=$(( $((delay_original - delay_file_mod)) + $((new_delay - now)) ))
      local now_delay=$(bc <<< "scale=2; $now_delay/3600")

      new_delay=$(echo "$now_delay" | awk -F'.' '{printf ("%.0f hour %.0f minute\n", $1, $2/100*60)}')
      IFS=" " read -r hour minute <<< $(date -d "$new_delay" "+%R" | awk -F: '{print $1, $2}')
      sed -Ei "/Hour/{n;s/[0-9]+/${hour##0}/g}" "$PLIST_FILE"
      sed -Ei "/Minute/{n;s/[0-9]+/${minute##0}/g}" "$PLIST_FILE"
      echo "$new_delay" | tee "$TIMER_FILE" &> /dev/null
      _screenlength
      _launch "bootout" && _launch "bootstrap"
      _success "${PLIST_FILE##*/} timer has been updated"
      echo 0
    else
      mv "$TMP_PATH" "$PLIST_FILE"
      if _agent_status; then
        _screenlength
        _launch "bootout" && _launch "bootstrap"
        _success "${PLIST_FILE##*/} reloaded"
        echo "$delay" | tee "$TIMER_FILE" &> /dev/null
        echo 0
      else
        _screenlength
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

# Set ownership when mounting a veracrypt drive
# $1: Veracrpt path
_set_ownership() {
	local _uid _gid path="$1"
	_uid="$(id -u "$USER")"
	_gid="$(id -g "$USER")"
	_verbose "Setting user permissions on $path"
	chown -R "$_uid:$_gid" "$path" || _die "Unable to set ownership permission on $path."
}

cmd_vera_version() {
	cat <<-_EOF
	${GREEN}${PROGRAM} vera${RESET} ${RED}${VERSION}${RESET} - A pass extension that helps to keep the whole tree of
	                password encrypted inside veracrypt.
	_EOF
}

cmd_vera_usage() {
	cmd_vera_version
	echo
	cat <<-_EOF
  ${YELLOW}Usage:${RESET}
	    ${GREEN}${PROGRAM} vera${RESET} [-n] [-t time] [-f] [-p subfolder] gpg-id...
	        Create and initialise a new password vera
	        Use gpg-id for encryption of both vera and passwords

	    ${GREEN}${PROGRAM} open${RESET} [subfolder] [-t time] [-f]
	        Open a password vera

	    ${GREEN}${PROGRAM} close${RESET} [store]
	        Close a password vera

  ${MAGENTA}Options:${RESET}
	    -n, --no-init        Do not initialise the password store
	    -t, --timer          Close the store after a given time
	    -p, --path           Create the store for that specific subfolder
      -r, --truecrypt      Enable compatibility with truecrypt
      -k, --vera-key       Create a key with veracrypt instead of GPG
      -o, --overwrite-key  Overwrite existing key
	    -f, --force          Force operation (i.e. even if swap is active)
	    -q, --quiet          Be quiet
	    -v, --verbose        Be verbose
      -d, --debug          Debug the launchctl agent with a stderr file located in \$HOME folder
	        --unsafe         Speed up vera creation (for testing only)
	    -V, --version        Show version information.
	    -h, --help           Print this help message and exit.

	More information may be found in the ${GREEN}pass-vera${RESET}${RED}(${RESET}${BLUE}1${RESET}${RED})${RESET} man page.
	_EOF
}

_vera() {
  local ret
  local cmd="$@"
  $VERA $TRUECRYPT $cmd $FORCE
  ret=$?

  [[ $ret == 0 ]] || _die "Unable to $cmd the password store"
}

# Open a password vera
cmd_open() {
	local path="$1"; shift;

	# Sanity checks
	check_sneaky_paths "$path" "$VERA_FILE" "$VERA_KEY"
	[[ -e "$VERA_FILE" ]] || _die "There is no password vera to open."
	[[ -e "$VERA_KEY" ]] || _die "There is no password vera key."

	# Open the password vera
  if ! "$VERA" --text --list 2>&1 | rg --color=never -Fq ".password.vera"; then
    _verbose "Opening the password vera $VERA_FILE using the key $VERA_KEY"
    _vera --text --keyfiles "$VERA_KEY" --pim=0 --protect-hidden=no --mount "$VERA_FILE" "${PASSWORD_STORE_DIR:-$HOME/.password-store}"
    _set_ownership "$PREFIX/$path"
  else
    _warning "The veracrypt drive is already mounted, not opening"
  fi

	# Read, initialise and start the timer
	local timed=1

  if [[ -z "$TIMER" ]]; then
    [[ -r "$TIMER_FILE" ]] && rm -f "$TIMER_FILE"
  else
    timed="$(_timer "$TIMER" "$path")"
  fi

	# Success!
	_success "Your password vera has been opened in $PREFIX/."
	_message "You can now use pass as usual."
	if [[ $timed == 0 ]]; then
    if rg --color=never -q "^0" "$TIMER_FILE"; then
      TIMER=$(awk '{print $3,$4}' "$TIMER_FILE")
    elif [[ $(awk '{print NF}' "$TIMER_FILE") == 4 ]]; then
      TIMER="$TIMER_FILE"
    fi
    _message "This password store will be closed in: ${GREEN}${TIMER}${RESET}"
    _screenlength
	else
		_message "When finished, close the password vera using 'pass close'."
    _screenlength
	fi
	return 0
}

# Close a password vera
cmd_close() {
	local _vera_name _vera_file="$1"
  local uid=$(id -u)

	[[ -z "$_vera_file" ]] && _vera_file="$VERA_FILE"

	# Sanity checks
	check_sneaky_paths "$_vera_file"
	_vera_name="${_vera_file##*/}"
	_vera_name="${_vera_name%.*}"
	[[ -z "$_vera_name" ]] && _die "There is no password vera."

	_verbose "Closing the password vera $_vera_file"
  _screenlength
  [[ -e "$TIMER_FILE" ]] && rm -f "$TIMER_FILE" && _message "Your timer has been removed"
	_vera --text --dismount "$VERA_FILE"
  if _agent_status; then
    _launch "bootout" && _success "Your launch agent has been unloaded"
  fi

  _success "Your password vera has been closed"
	_message "Your passwords remain present in $_vera_file."
  _screenlength
	return 0
}

_create_key() {
  if [[ $MAKE_VERAKEY == 1 ]]; then
    _vera --text --create-keyfile "$VERA_KEY" --random-source=/dev/urandom
    _message "Verakey created"
  else
    gpg --fingerprint "$recipients_arg" | rg --color=never 'fingerprint' \
      | awk 'BEGIN{FS="="} {print $2}' | sed -n '1p' | tr -d ' ' | tee "$VERA_KEY" &> /dev/null
    _message "GPG key created"
  fi
}

_test_key() {
  if [[ ! -e "$VERA_KEY" ]]; then
    _create_key
  elif [[ -e "$VERA_KEY" ]] && [[ "$OVERWRITE_KEY" == 1 ]]; then
    _create_key
  else
    _die "The vera key $VERA_KEY already exists. I won't overwrite it."
  fi
}

# Create a new password vera and initialise the password repository
# $1: path subfolder
# $@: gpg-ids
cmd_vera() {
	local path="$1"; shift;
	typeset -a RECIPIENTS
	[[ -z "$*" ]] && _die "$PROGRAM $COMMAND [-n] [-t time] [-p subfolder] gpg-id..."
	IFS=" " read -r -a RECIPIENTS <<< "$@"

	# Sanity checks
	check_sneaky_paths "$path" "$VERA_FILE" "$VERA_KEY"
	if ! is_valid_recipients "${RECIPIENTS[@]}"; then
		_die "You set an invalid GPG ID."
	elif [[ -e "$VERA_KEY" ]]; then
    _test_key
	elif [[ -e "$VERA_FILE" ]]; then
		_die "The password vera $VERA_FILE already exists. I won't overwrite it."
	elif [[ "$VERA_SIZE" -lt 10 ]]; then
		_die "A password vera cannot be smaller than 10 MB."
	fi

	if [[ $UNSAFE -ne 0 ]]; then
		_warning "Using unsafe mode to speed up vera generation."
		_warning "Only use it for testing purposes."
		local unsafe=(--quick)
	fi

	# Sharing support
	local recipients_arg tmp_arg
	if [ "${#RECIPIENTS[@]}" -gt 1 ]; then
		tmp_arg="${RECIPIENTS[*]}"
		recipients_arg=${tmp_arg// /,}
	else
		recipients_arg="${RECIPIENTS[0]}"
	fi

  _test_key

	# Create the password vera
	_verbose "Creating a password vera with the GPG key(s): ${RECIPIENTS[*]}"
  _vera --text "${unsafe[@]}" --volume-type=normal --create "$VERA_FILE" --size="${VERA_SIZE}"M --encryption=aes --hash=sha-512 --filesystem=exFAT --pim=0 --keyfiles $VERA_KEY --random-source=/dev/urandom

  _vera --text --keyfiles "$VERA_KEY" --pim=0 --protect-hidden=no --mount "$VERA_FILE" "${PASSWORD_STORE_DIR:-$HOME/.password-store}"
	_set_ownership "$PREFIX/$path"

	# use the same recipients to initialize the password store
	local ret path_cmd=()
	if [[ $NOINIT -eq 0 ]]; then
		[[ -z "$path" ]] || path_cmd=("--path=${path}")
		ret="$(cmd_init "${RECIPIENTS[@]}" "${path_cmd[@]}")"
		if [[ ! -e "$PREFIX/$path/.gpg-id" ]]; then
			_warning "$ret"
			_die "Unable to initialise the password store."
		fi
	fi

	# initialization of timer
	local timed=1
	[[ -z "$TIMER" ]] || timed="$(_timer "$TIMER" "$path")"

	# command succeeded
  _screenlength
	_success "Your password vera has been created and opened in $PREFIX."
	[[ -z "$ret" ]] || _success "$ret"
	_message "Your vera is: $VERA_FILE"
	_message "Your vera key is: $VERA_KEY"
	if [[ -z "$ret" ]]; then
		_message "You need to initialise the store with 'pass init gpg-id...'."
	else
		_message "You can now use pass as usual."
	fi

	if [[ $timed == 0 ]]; then
    # if the addition to original time is under an hour
    if rg --color=never -q "^0" "$TIMER_FILE"; then
      TIMER=$(awk '{print $3,$4}' "$TIMER_FILE")
    # if the addition to original time is above an hour
    elif [[ $(awk '{print NF}' "$TIMER_FILE") == 4 ]]; then
      TIMER="$TIMER_FILE"
    fi
    _message "This password store will be closed in: ${GREEN}${TIMER}${RESET}"
    _screenlength
	else
		_message "When finished, close the password vera using 'pass close'."
    _screenlength
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
TRUECRYPT=""

# program arguments using GNU getopt
small_arg="vhVdokrp:qnt:f"
long_arg="verbose,help,debug,version,overwrite-key,vera-key,path:,truecrypt,unsafe,quiet,no-init,timer:,force"
opts="$($GETOPT -o $small_arg -l $long_arg -n "$PROGRAM $COMMAND" -- "$@")"
err=$?
eval set -- "$opts"
while true; do case $1 in
	-q|--quiet) QUIET=1; VERBOSE=0; shift ;;
	-v|--verbose) VERBOSE=1; shift ;;
  -o|--overwrite-key) OVERWRITE_KEY=1; shift ;;
  -d|--debug) DEBUG=1; shift ;;
  -k|--vera-key) MAKE_VERAKEY=1; shift ;;
	-f|--force) FORCE="--force"; shift ;;
	-h|--help) shift; cmd_vera_usage; exit 0 ;;
	-V|--version) shift; cmd_vera_version; exit 0 ;;
	-p|--path) id_path="$2"; shift 2 ;;
	-t|--timer) TIMER="$2"; shift 2 ;;
	-n|--no-init) NOINIT=1; shift ;;
  -r|--truecrypt) TRUECRYPT="--truecrypt"; shift ;;
	--unsafe) UNSAFE=1; shift ;;
	--) shift; break ;;
esac done

[[ -z "$TIMER" ]] || command -v launchctl &> /dev/null || _die "launchctl is not present."
[[ $err -ne 0 ]] && cmd_vera_usage && exit 1
[[ "$COMMAND" == "vera" ]] && cmd_vera "$id_path" "$@"
