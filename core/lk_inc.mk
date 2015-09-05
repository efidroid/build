# add our modules
MODULES += \
	$(EFIDROID_TOP)/uefi/lkmodules/uefiapi

# enable the UEFIAPI
WITH_KERNEL_UEFIAPI := 1
DEFINES += WITH_KERNEL_UEFIAPI=1

DEFINES += LCD_DENSITY=$(LCD_DENSITY)
