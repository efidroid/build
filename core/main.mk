export EFIDROID_MAKE := $(MAKE)

.PHONY: $(MAKECMDGOALS) all
$(MAKECMDGOALS) all:
	@python -B ./build/core/configure.py $(firstword $(DEVICEID))
	
	@if [ "$(DEVICEID)" == "" ];then \
		$(MAKE) -f out/build_host.mk $(MAKECMDGOALS); \
	else \
		$(MAKE) -f out/build_$(subst /,-,$(DEVICEID)).mk $(MAKECMDGOALS); \
	fi

