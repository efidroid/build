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


define pr_error
    $(info $(shell source $(EFIDROID_TOP)/build/core/compilescript_inc.sh && pr_error "$(1)"))
endef
define pr_fatal
    $(info $(shell source $(EFIDROID_TOP)/build/core/compilescript_inc.sh && pr_error "$(1)"))
    $(error FATAL ERROR)
endef
define pr_info
    $(info $(shell source $(EFIDROID_TOP)/build/core/compilescript_inc.sh && pr_info "$(1)"))
endef
define pr_warning
    $(info $(shell source $(EFIDROID_TOP)/build/core/compilescript_inc.sh && pr_warning "$(1)"))
endef
define pr_notice
    $(info $(shell source $(EFIDROID_TOP)/build/core/compilescript_inc.sh && pr_notice "$(1)"))
endef
define pr_alert
    $(info $(shell source $(EFIDROID_TOP)/build/core/compilescript_inc.sh && pr_alert "$(1)"))
endef
