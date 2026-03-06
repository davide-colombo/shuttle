PREFIX ?= $(HOME)/.local

BIN_DIR := $(PREFIX)/bin
LIB_DIR := $(PREFIX)/lib/shuttle
SHARE_DIR := $(PREFIX)/share/shuttle

.PHONY: install uninstall init-config

install:
	mkdir -p "$(BIN_DIR)" "$(LIB_DIR)" "$(SHARE_DIR)"
	cp bin/shuttle "$(BIN_DIR)/shuttle"
	chmod +x "$(BIN_DIR)/shuttle"
	cp -R lib/. "$(LIB_DIR)/"
	cp -R share/shuttle/. "$(SHARE_DIR)/"

uninstall:
	rm -f "$(BIN_DIR)/shuttle"
	rm -rf "$(LIB_DIR)"
	rm -rf "$(SHARE_DIR)"

init-config:
	@config_home="$${XDG_CONFIG_HOME:-$$HOME/.config}"; \
	conf_dir="$$config_home/shuttle"; \
	conf_file="$$conf_dir/credentials.env"; \
	mkdir -p "$$conf_dir"; \
	if [ ! -f "$$conf_file" ]; then \
		printf '%s\n' \
			'# shuttle global credentials' \
			'REMOTE_HOST =' \
			'REMOTE_USER =' \
			'SSH_PORT = 22' \
			'# SSH_KEY =' > "$$conf_file"; \
		chmod 600 "$$conf_file"; \
		echo "Created $$conf_file"; \
	else \
		chmod 600 "$$conf_file"; \
		echo "Already exists: $$conf_file"; \
	fi
