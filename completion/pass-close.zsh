#compdef pass-close
#description Close a password vera

_pass-close() {
	_arguments : \
		{-h,--help}'[display help information]' \
		{-V,--version}'[display version information]' \
    {-f,--force}'[force dismount]' \
		{-q,--quiet}'[be quiet]' \
		{-v,--verbose}'[be verbose]' \
		{-d,--debug}'[print Veracrypt debug messages]'

	_pass_complete_entries_vera
}

_pass_complete_entries_vera() {
  local veras="$(veracrypt -t -l | grep 'password.vera' | cut -d ' ' -f2)"
	_values -C 'veras' "$veras"
}

_pass-close "$@"
