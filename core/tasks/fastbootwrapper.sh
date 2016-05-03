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

CompileLinux() {
    cd "$MODULE_OUT" &&
        pyinstaller --onefile "$TOP/build/tools/fastbootwrapper"

    pr_alert "Installing: $MODULE_OUT/dist/fastbootwrapper"
}

CompileW32() {
    export WINEPREFIX="$MODULE_OUT/wine_prefix"
    export WINEARCH=win32
    PYTHON_INSTALLER="$MODULE_OUT/python-2.7.11.msi"
    WINE_PYTHON_PATH="$WINEPREFIX/drive_c/Python27"
    WINE_PYINSTALLER_PATH="$WINE_PYTHON_PATH/Scripts/pyinstaller.exe"

    if [ ! -f "$PYTHON_INSTALLER" ];then
        curl -L -o "$PYTHON_INSTALLER" https://www.python.org/ftp/python/2.7.11/python-2.7.11.msi
    fi

    if [ ! -f "$WINE_PYTHON_PATH" ];then
        wine msiexec /i "$PYTHON_INSTALLER" /qn
    fi

    if [ ! -f "$WINE_PYINSTALLER_PATH" ];then
        wine "$WINE_PYTHON_PATH/python.exe" "$WINE_PYTHON_PATH/Scripts/pip.exe" install pyinstaller
    fi

    cd "$MODULE_OUT" &&
        wine "$WINE_PYINSTALLER_PATH" --onefile "$TOP/build/tools/fastbootwrapper"

    pr_alert "Installing: $MODULE_OUT/dist/fastbootwrapper.exe"
}

Clean() {
    rm -Rf "$MODULE_OUT"
}

DistClean() {
    Clean
}
