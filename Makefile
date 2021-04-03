PROG ?= vera
PREFIX ?= /usr/local
DESTDIR ?=
LIBDIR ?= $(PREFIX)/lib
SYSTEM_EXTENSION_DIR ?= $(LIBDIR)/password-store/extensions
MANDIR ?= $(PREFIX)/share/man

BASHCOMPDIR ?= $(PREFIX)/etc/bash_completion.d
ZSHCOMPDIR ?= $(PREFIX)/share/zsh/site-functions

all:
	@echo "pass-$(PROG) is a shell script and does not need compilation, it can be simply executed."
	@echo ""
	@echo "To install it try \"make install\" instead."
	@echo
	@echo "To run pass $(PROG) one needs to have some tools installed on the system:"
	@echo "     VeraCrypt, pass, and ripgrep"

install:
	@install -v -d "$(DESTDIR)$(MANDIR)/man1"
	@install -v -d "$(DESTDIR)$(SYSTEM_EXTENSION_DIR)/" "$(DESTDIR)$(SYSTEM_EXTENSION_DIR)/vera-resources/"
	@install -v -d "$(DESTDIR)$(BASHCOMPDIR)" "$(DESTDIR)$(ZSHCOMPDIR)"
	@install -v -m 0755 $(PROG).bash "$(DESTDIR)$(SYSTEM_EXTENSION_DIR)/$(PROG).bash"
	@install -v -m 0755 open.bash "$(DESTDIR)$(SYSTEM_EXTENSION_DIR)/open.bash"
	@install -v -m 0755 close.bash "$(DESTDIR)$(SYSTEM_EXTENSION_DIR)/close.bash"
	@install -v -m 0644 pass-$(PROG).1 "$(DESTDIR)$(MANDIR)/man1/pass-$(PROG).1"
	@install -v -m 0744 veratimer.sh "$(DESTDIR)$(SYSTEM_EXTENSION_DIR)/vera-resources/veratimer.sh"
	@install -v -m 0644 "completion/pass-$(PROG).bash" "$(DESTDIR)$(BASHCOMPDIR)/pass-$(PROG)"
	@install -v -m 0644 "completion/pass-$(PROG).zsh" "$(DESTDIR)$(ZSHCOMPDIR)/_pass-$(PROG)"
	@install -v -m 0644 "completion/pass-open.zsh" "$(DESTDIR)$(ZSHCOMPDIR)/_pass-open"
	@install -v -m 0644 "completion/pass-close.zsh" "$(DESTDIR)$(ZSHCOMPDIR)/_pass-close"
	@echo
	@echo "pass-$(PROG) is installed succesfully"
	@echo

uninstall:
	@rm -vrf \
		"$(DESTDIR)$(SYSTEM_EXTENSION_DIR)/$(PROG).bash" \
		"$(DESTDIR)$(SYSTEM_EXTENSION_DIR)/open.bash" \
		"$(DESTDIR)$(SYSTEM_EXTENSION_DIR)/close.bash" \
		"$(DESTDIR)$(MANDIR)/man1/pass-$(PROG).1" \
		"$(DESTDIR)$(LIBDIR)/systemd/system/pass-close@.service" \
		"$(DESTDIR)$(BASHCOMPDIR)/pass-$(PROG)" \
		"$(DESTDIR)$(ZSHCOMPDIR)/_pass-$(PROG)" \
		"$(DESTDIR)$(ZSHCOMPDIR)/_pass-open" \
		"$(DESTDIR)$(ZSHCOMPDIR)/_pass-close"


lint:
	shellcheck -s bash $(PROG).bash open.bash close.bash
	shellcheck -s sh $(PROG)timer.sh

.PHONY: install uninstall lint
