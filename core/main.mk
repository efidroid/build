#
# Copyright (C) 2016 The EFIDroid Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Only use EFIDROID_BUILD_SHELL to wrap around bash.
# DO NOT use other shells such as zsh.
ifdef EFIDROID_BUILD_SHELL
SHELL := $(EFIDROID_BUILD_SHELL)
else
# Use bash, not whatever shell somebody has installed as /bin/sh
SHELL := /bin/bash
endif

export EFIDROID_MAKE := $(MAKE)
export EFIDROID_SHELL := $(SHELL)

# enable GCC colors by default (if supported)
export GCC_COLORS ?= 1

# add build/tools to path to force python2
export PATH := $(PWD)/build/tools:$(PATH)
# add dtc build path to PATH so we don't have to use the full path everywhere
export PATH := $(PWD)/out/host/dtc/dtc:$(PATH)

.PHONY: $(MAKECMDGOALS) all
$(MAKECMDGOALS) all: makeforward
	@python ./build/core/configure.py
	
	@echo -n "" > out/buildtime_variables.sh
	@echo -n "" > out/buildtime_variables.py
	
	@ # log start time
	@start_time=$$(date +"%s"); \
	\
	# run build \
	$(MAKE) -f out/build.mk $(MAKECMDGOALS); \
	\
	# compute and show build time \
	ret=$$?; \
	end_time=$$(date +"%s"); \
	tdiff=$$(($$end_time-$$start_time)); \
	hours=$$(($$tdiff / 3600 )); \
	mins=$$((($$tdiff % 3600) / 60)); \
	secs=$$(($$tdiff % 60)); \
	echo; \
	if [ $$ret -eq 0 ] ; then \
		echo -n -e "#### make completed successfully "; \
	else \
		echo -n -e "#### make failed to build some targets "; \
	fi; \
	if [ $$hours -gt 0 ] ; then \
		printf "(%02g:%02g:%02g (hh:mm:ss))" $$hours $$mins $$secs; \
	elif [ $$mins -gt 0 ] ; then \
		printf "(%02g:%02g (mm:ss))" $$mins $$secs; \
	elif [ $$secs -gt 0 ] ; then \
		printf "(%s seconds)" $$secs; \
	fi; \
	echo -e " ####"; \
	echo; \
	exit $$ret;

# MAKEFORWARD
out/host/makeforward: build/tools/makeforward.c
	@mkdir -p out/host
	@gcc -Wall -Wextra -Wshadow -Werror $< -o $@
makeforward: out/host/makeforward
