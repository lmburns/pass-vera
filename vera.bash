#!/usr/bin/env bash

readonly VERA="${PASSWORD_STORE_VERA:-veracrypt}"
readonly VERA_FILE="${PASSWORD_STORE_VERA_FILE:-$HOME/.password.vera}"
readonly VERA_KEY="${PASSWORD_STORE_VERA_KEY:-$HOME/.password.vera.key}"
readonly VERA_SIZE="${PASSWORD_STORE_VERA_SIZE:-10}"

readonly TMP_PATH="/tmp/pass-close$(basename "$VERA_FILE").plist"
readonly PLIST_PATH="$HOME/Library/LaunchAgents/${TMP_PATH##*/}"

readonly VERSION="1.0"

# Common colors and functions
readonly green='\e[0;32m' yellow='\e[0;33m' magenta='\e[0;35m'
readonly Bred='\e[1;31m' Bgreen='\e[1;32m' Byellow='\e[1;33m'
readonly Bmagenta='\e[1;35m' Bold='\e[1m' reset='\e[0m'
readonly RED=$(tput setaf 1) GREEN=$(tput setaf 2) YELLOW=$(tput setaf 3)
readonly BLUE=$(tput setaf 4) MAGENTA=$(tput setaf 5) CYAN=$(tput setaf 6)
readonly BOLD=$(tput bold) RESET=$(tput sgr0) UNDERLINE=$(tput smul)

_message() { [ "$QUIET" = 0 ] && printf '  %b.%b  %s\n' "$Bold" "$reset" "$*" >&2; }
_warning() { [ "$QUIET" = 0 ] && printf '  %bw%b  %b%s%b\n' "$Byellow" "$reset" "$yellow" "$*" "$reset" >&2; }
_success() { [ "$QUIET" = 0 ] && printf ' %b(*)%b %b%s%b\n' "$Bgreen" "$reset" "$green" "$*" "$reset" >&2; }
_verbose() { [ "$VERBOSE" = 0 ] || printf '  %b.%b  %bpass%b %s\n' "$Bmagenta" "$reset" "$magenta" "$reset" "$*" >&2; }
_verbose_vera() { [ "$VERBOSE" = 0 ] || printf '  %b.%b  %s\n' "$Bmagenta" "$reset" "$*" >&2; }
_error() { printf ' %b[x]%b %bError:%b %s\n' "$Bred" "$reset" "$Bold" "$reset" "$*" >&2; }
_dismount() { if ! veracrypt -t -l 2>&1 | rg --color=never "Error" >/dev/null; then "$VERA" --text --dismount "$VERA_FILE"; fi }
_screenlength() { screenlength=$(printf "%$(tput cols)s%b" | tr " " "="); printf "%b%s%b\n" "$(tput setaf 5)" "$screenlength" "$(tput sgr0)" >&2; }
_die() { _error "$*" && _dismount; exit 1; }
_in() { [[ $1 =~ (^|[[:space:]])$2($|[[:space:]]) ]] && return 0 || return 1; }

# pass vera depends on veracrypt
_ensure_dependencies() {
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

# $1: Delay before to run the pass-close service
# $2: Path in the password store to save the delay (may be empty)
# return 0 on success, 1 otherwise
_timer() {
	local ret ii delay="$1" path="$2" file_hours file_mins
  local timer_file="$PREFIX/$path/.timer"
  local delay_hour="$(echo "$delay" | rg --color=never -io '\d+\s?h(ou)?r(s)?')"
  local delay_minute="$(echo "$delay" | rg --color=never -io '\d+\s?min(ute)?s?')"
  IFS=" " read -r delay_hour delay_minute <<< $(date -d "++$(_time_conversion "$delay_hour" "$delay_minute")" "+%R" | awk 'BEGIN{FS=":"} {print $1,$2}')

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
  </dict>
</plist>
_EOF

  ret=$?

  local hour_check="$(rg -A1 -N --color=never 'Hour' "$TMP_PATH" | sed -n '2p' | awk 'BEGIN{FPAT="[0-9]+"} {print $1}')"
  local min_check="$(rg -A1 -N --color=never 'Minute' "$TMP_PATH" | sed -n '2p' | awk 'BEGIN{FPAT="[0-9]+"} {print $1}')"
  local digit_check="^[0-9]*$"

  if [[ $ret == 0 ]]; then
    [[ ! "${hour_check}" =~ ${digit_check} ]] && _warning "Incorrectly entered hour"; echo 1
    [[ ! "${min_check}" =~ ${digit_check} ]] && _warning "Incorrectly entered minute"; echo 1
    if [[ -r "$timer_file" ]]; then
      local delay_original=$(date -d "$(_time_conversion "$(cat "$timer_file")")" "+%s")
      local delay_file_mod=$(date -r "$timer_file" "+%s")
      local new_delay=$(date -d "+$(_time_conversion $delay)" "+%s")
      local now=$(date "+%s")

      local now_delay=$(( $((delay_original - delay_file_mod)) + $((new_delay - now)) ))
      local now_delay=$(bc <<< "scale=2; $now_delay/3600")

      new_delay=$(echo "$now_delay" | awk -F'.' '{print $1 " hour", $2 " minute"}')
      IFS=" " read -r hour minute <<< $(date -d "$new_delay" "+%R" | awk -F: '{print $1, $2}')
      sed -Ei "/Hour/{n;s/[0-9]+/${hour##0}/g}" "$HOME/projects/github/pass-vera/pass-close.password.vera.plist"
      sed -Ei "/Minute/{n;s/[0-9]+/${minute##0}/g}" "$HOME/projects/github/pass-vera/pass-close.password.vera.plist"
      echo "$new_delay" | tee "$timer_file" &> /dev/null
      _screenlength
      _success "${PLIST_PATH##*/} timer has been updated"
      echo 0
    else
      mv "$TMP_PATH" "$PLIST_PATH"
      if launchctl list | rg -q --color=never "${PLIST_PATH##*/}"; then
        _screenlength
        launchctl unload "$PLIST_PATH" && launchctl load "$PLIST_PATH"
        _success "${PLIST_PATH##*/} reloaded"
        echo "$delay" | tee "$timer_file" &> /dev/null
        echo 0
      else
        _screenlength
        launchctl load "$PLIST_PATH"
        _success "${PLIST_PATH##*/} loaded"
        echo "$delay" | tee "$timer_file" &> /dev/null
        echo 0
      fi
    fi
  else
    _error "Something horrible went wrong"
    echo 1
  fi

  return $ret
}

_tmp_create() {
	local tfile
  tmpdir
	tfile="$(mktemp -u "$SECURE_TMPDIR/XXXXXXXXXXXXXXXXXXXX")" # Temporary file

	[[ $? == 0 ]] || _die "Fatal error setting permission umask for temporary files."
	[[ -r "$tfile" ]] && echo "Someone is messing up with us trying to hijack temporary files."

	touch "$tfile"
	[[ $? == 0 ]] || echo "Fatal error creating temporary file: $tfile."

	TMP="$tfile"
	return 0
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
	    -n, --no-init  Do not initialise the password store
	    -t, --timer    Close the store after a given time
	    -p, --path     Create the store for that specific subfolder
	    -f, --force    Force operation (i.e. even if swap is active)
	    -q, --quiet    Be quiet
	    -v, --verbose  Be verbose
	        --unsafe   Speed up vera creation (for testing only)
	    -V, --version  Show version information.
	    -h, --help     Print this help message and exit.

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
  local mountcheck="$("$VERA" --text --list 2>&1 | rg --color=never -Fq ".password.vera" )"

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
    _warning "The veracrypt drive is already mounted"
    _screenlength
  fi

	# Read, initialise and start the timer
	local timed=1
  [[ -z "$TIMER" ]] || timed="$(_timer "$TIMER" "$path")"

	# Success!
	_success "Your password vera has been opened in $PREFIX/."
	_message "You can now use pass as usual."
	if [[ $timed == 0 ]]; then
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

	[[ -z "$_vera_file" ]] && _vera_file="$VERA_FILE"

	# Sanity checks
	check_sneaky_paths "$_vera_file"
	_vera_name="${_vera_file##*/}"
	_vera_name="${_vera_name%.*}"
	[[ -z "$_vera_name" ]] && _die "There is no password vera."

	_verbose "Closing the password vera $_vera_file"
	_vera --text --dismount "$VERA_FILE"
  if launchctl list | rg -q --color=never "${PLIST_PATH##*/}"; then
    _screenlength
    launchctl unload "$PLIST_PATH" && _success "Your launch agent has been unloaded"
  else
    _screenlength
    _warning "${PLIST_PATH##*/} not loaded"
  fi
  _success "Your password vera has been closed"
	_message "Your passwords remain present in $_vera_file."
  _screenlength
	return 0
}

_create_key() {
  if [[ $MAKE_VERAKEY == 1 ]]; then
    _vera --text --create-keyfile "$VERA_KEY" --random-source=/dev/urandom
  else
    gpg --fingerprint "$recipients_arg" | rg --color=never 'fingerprint' \
      | awk 'BEGIN{FS="="} {print $2}' | sed -n '1p' | tr -d ' ' | tee "$VERA_KEY" &> /dev/null
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

# Create a new password vera and initialise the password repository.
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

	# Use the same recipients to initialise the password store
	local ret path_cmd=()
	if [[ $NOINIT -eq 0 ]]; then
		[[ -z "$path" ]] || path_cmd=("--path=${path}")
		ret="$(cmd_init "${RECIPIENTS[@]}" "${path_cmd[@]}")"
		if [[ ! -e "$PREFIX/$path/.gpg-id" ]]; then
			_warning "$ret"
			_die "Unable to initialise the password store."
		fi
	fi

	# Initialise the timer
	local timed=1
	[[ -z "$TIMER" ]] || timed="$(_timer "$TIMER" "$path")"

	# Success!
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
    _message "This password store will be closed in: ${GREEN}${TIMER}${RESET}"
    _screenlength
	else
		_message "When finished, close the password vera using 'pass close'."
    _screenlength
	fi
	return 0
}

# Check dependencies are present or bail out
_ensure_dependencies

# Global options
UNSAFE=0
VERBOSE=0
QUIET=0
FORCE=""
NOINIT=0
TIMER=""
OVERWRITE_KEY=0
MAKE_VERAKEY=0
TRUECRYPT=""

# Getopt options
small_arg="vhVokrp:qnt:f"
long_arg="verbose,help,version,overwrite-key,vera-key,path:,truecrypt,unsafe,quiet,no-init,timer:,force"
opts="$($GETOPT -o $small_arg -l $long_arg -n "$PROGRAM $COMMAND" -- "$@")"
err=$?
eval set -- "$opts"
while true; do case $1 in
	-q|--quiet) QUIET=1; VERBOSE=0; shift ;;
	-v|--verbose) VERBOSE=1; shift ;;
  -o|--overwrite-key) OVERWRITE_KEY=1; shift ;;
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
