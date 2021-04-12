#compdef pass-open
#description Open a password vera

_pass-open () {
	_arguments : \
		{-h,--help}'[display help information]' \
		{-V,--version}'[display version information]' \
		{-t,--timer}'[close the store after a given time]' \
		{-y,--truecrypt}'[enable TrueCrypt compatibility mode]' \
		{-c,--conf}'[use a configuration file (auto | *)]' \
		{-i,--invisi-key}'[use the key that deletes itself]' \
		{-f,--force}'[force mounting (i.e. even if operations are happening)]' \
		{-q,--quiet}'[be quiet]' \
		{-v,--verbose}'[be verbose]' \
		{-d,--debug}'[print VeraCrypt debug messages]'

	_pass_complete_entries_with_dirs
}

_pass_complete_entries_with_dirs () {
	_pass_complete_entries_helper -type d
}

_pass-open "$@"
