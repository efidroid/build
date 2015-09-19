export EFIDROID_MAKE := $(MAKE)

# enable GCC colors by default (if supported)
export GCC_COLORS ?= 1

.PHONY: $(MAKECMDGOALS) all
$(MAKECMDGOALS) all: makeforward makeforward_pipes
	@python -B ./build/core/configure.py $(firstword $(DEVICEID))
	
	@echo -n "" > out/buildtime_variables.sh
	@echo -n "" > out/buildtime_variables.py

	@if [ "$(DEVICEID)" == "" ];then \
		$(MAKE) -f out/build_host.mk $(MAKECMDGOALS); \
	else \
		$(MAKE) -f out/build_$(subst /,-,$(DEVICEID)).mk $(MAKECMDGOALS); \
	fi

# MAKEFORWARD
out/host/makeforward: build/tools/makeforward.c
	@mkdir -p out/host
	@gcc -Wall -Wextra -Wshadow -Werror $< -o $@
makeforward: out/host/makeforward

# MAKEFORWARD_PIPES
out/host/makeforward_pipes: build/tools/makeforward_pipes.c
	@mkdir -p out/host
	@gcc -Wall -Wextra -Wshadow -Werror $< -o $@
makeforward_pipes: out/host/makeforward_pipes
