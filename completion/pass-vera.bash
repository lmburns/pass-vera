# pass-vera completion file for bash

PASSWORD_STORE_EXTENSION_COMMANDS+=(vera open close)

_pass_complete_veras() {
  local veras="$(veracrypt -t -l | grep 'password.vera' | cut -d ' ' -f2)"
	COMPREPLY+=($(compgen -W "${veras}" -- ${cur}))
}

__password_store_extension_complete_vera() {
	local args=(-h --help -n --no-init -t --timer -p --path -f --force
		-c --truecrypt -k --vera-key --tmp-key -o -i --invisi-key --for-me
		--overwrite-key -s --status --for-me -r --reencrypt -q --quiet
		-v --verbose -d --debug --unsafe -V --version)
	local lastarg="${COMP_WORDS[$COMP_CWORD-1]}"
	if [[ $lastarg == "-p" || $lastarg == "--path" ]]; then
		_pass_complete_folders
		compopt -o nospace
	else
		COMPREPLY+=($(compgen -W "${args[*]}" -- ${cur}))
		_pass_complete_keys
    fi
}

__password_store_extension_complete_open() {
	local args=(-h --help -t --timer -f --force -v --verbose -d --debug
		-q --quiet -V --version -c --truecrypt -i --invisi-key)
	COMPREPLY+=($(compgen -W "${args[*]}" -- ${cur}))
	_pass_complete_entries
	compopt -o nospace
}

__password_store_extension_complete_close() {
	local args=(-f --force -h --help -v --verbose -d --debug
		-q --quiet -V --version)
	COMPREPLY+=($(compgen -W "${args[*]}" -- ${cur}))
	_pass_complete_veras
	compopt -o nospace
}
