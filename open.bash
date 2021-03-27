#!/usr/bin/env bash

if [[ -x "${PASSWORD_STORE_EXTENSIONS_DIR}/vera.bash" ]]; then
	source "${PASSWORD_STORE_EXTENSIONS_DIR}/vera.bash"
elif [[ -x "${SYSTEM_EXTENSION_DIR}/vera.bash" ]]; then
	source "${SYSTEM_EXTENSION_DIR}/vera.bash"
else
	die "Unable to load the pass vera extension."
fi

cmd_open "$@"
