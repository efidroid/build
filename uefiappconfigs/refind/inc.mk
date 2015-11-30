ifeq ($(ARCH),armv7l)
  ARCH_C_FLAGS = -DEFIARM -mthumb -march=armv7-a -mlittle-endian -mfloat-abi=soft -mfpu=neon -D__ARM_PCS_VFP
  ARCHDIR = Arm
  UC_ARCH = ARM
  FILENAME_CODE = arm
  LD_CODE = armelf_linux_eabi
endif
