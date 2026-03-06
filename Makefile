PREFIX ?= $(HOME)/.local

BIN_DIR := $(PREFIX)/bin
LIB_DIR := $(PREFIX)/lib/rmt
SHARE_DIR := $(PREFIX)/share/rmt

.PHONY: install uninstall init-config

install:
	mkdir -p "$(BIN_DIR)" "$(LIB_DIR)" "$(SHARE_DIR)"
	cp bin/rmt "$(BIN_DIR)/rmt"
	chmod +x "$(BIN_DIR)/rmt"
	cp -R lib/. "$(LIB_DIR)/"
	cp -R share/rmt/. "$(SHARE_DIR)/"

uninstall:
	rm -f "$(BIN_DIR)/rmt"
	rm -rf "$(LIB_DIR)"
	rm -rf "$(SHARE_DIR)"

init-config:
	@config_home="${XDG_CONFIG_HOME:-$$HOME/.config}"; \
	conf_dir="$$config_home/rmt"; \
	conf_file="$$conf_dir/credentials.env"; \
	mkdir -p "$$conf_dir"; \
	if [ ! -f "$$conf_file" ]; then \
		printf '%s\n' \
			'# rmt global credentials' \
			'RMT_REMOTE_HOST=' \
			'RMT_REMOTE_USER=' \
			'RMT_SSH_PORT=22' \
			'# RMT_SSH_KEY=/path/to/id_ed25519' > "$$conf_file"; \
		chmod 600 "$$conf_file"; \
		echo "Created $$conf_file"; \
	else \
		chmod 600 "$$conf_file"; \
		echo "Already exists: $$conf_file"; \
	fi
