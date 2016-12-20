cmake_minimum_required(VERSION 2.8)
project(pcre)

set(CMAKE_BUILD_TYPE Release)

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DHAVE_CONFIG_H -Wall -Wextra -Wno-unused-parameter -Wno-unused-const-variable -fPIC")

# main
add_library(pcre STATIC
    $ENV{MODULE_DIR}/pcre_chartables.c
    $ENV{MODULE_DIR}/dist/pcre_byte_order.c
    $ENV{MODULE_DIR}/dist/pcre_compile.c
    $ENV{MODULE_DIR}/dist/pcre_config.c
    $ENV{MODULE_DIR}/dist/pcre_dfa_exec.c
    $ENV{MODULE_DIR}/dist/pcre_exec.c
    $ENV{MODULE_DIR}/dist/pcre_fullinfo.c
    $ENV{MODULE_DIR}/dist/pcre_get.c
    $ENV{MODULE_DIR}/dist/pcre_globals.c
    $ENV{MODULE_DIR}/dist/pcre_jit_compile.c
    $ENV{MODULE_DIR}/dist/pcre_maketables.c
    $ENV{MODULE_DIR}/dist/pcre_newline.c
    $ENV{MODULE_DIR}/dist/pcre_ord2utf8.c
    $ENV{MODULE_DIR}/dist/pcre_refcount.c
    $ENV{MODULE_DIR}/dist/pcre_string_utils.c
    $ENV{MODULE_DIR}/dist/pcre_study.c
    $ENV{MODULE_DIR}/dist/pcre_tables.c
    $ENV{MODULE_DIR}/dist/pcre_ucd.c
    $ENV{MODULE_DIR}/dist/pcre_valid_utf8.c
    $ENV{MODULE_DIR}/dist/pcre_version.c
    $ENV{MODULE_DIR}/dist/pcre_xclass.c
)
set_property(TARGET pcre PROPERTY INCLUDE_DIRECTORIES
    $ENV{MODULE_DIR}
    $ENV{MODULE_DIR}/dist
)
