export EFIDROID_MAKE := $(MAKE)

# enable GCC colors by default (if supported)
export GCC_COLORS ?= 1

.PHONY: $(MAKECMDGOALS) all
$(MAKECMDGOALS) all:
	@python -B ./build/core/configure.py $(firstword $(DEVICEID))
	
	@if [ "$(DEVICEID)" == "" ];then \
		$(MAKE) -f out/build_host.mk $(MAKECMDGOALS); \
	else \
		$(MAKE) -f out/build_$(subst /,-,$(DEVICEID)).mk $(MAKECMDGOALS); \
	fi

