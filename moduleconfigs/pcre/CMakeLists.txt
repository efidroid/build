cmake_minimum_required(VERSION 2.8)
project(pcre)

set(CMAKE_BUILD_TYPE Release)

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DHAVE_CONFIG_H -Wall -Wextra -Wno-unused-parameter -Wno-unused-const-variable -fPIC")

# main
add_library(pcre STATIC
    ${MODULE_SRC}/pcre_chartables.c
    ${MODULE_SRC}/dist/pcre_byte_order.c
    ${MODULE_SRC}/dist/pcre_compile.c
    ${MODULE_SRC}/dist/pcre_config.c
    ${MODULE_SRC}/dist/pcre_dfa_exec.c
    ${MODULE_SRC}/dist/pcre_exec.c
    ${MODULE_SRC}/dist/pcre_fullinfo.c
    ${MODULE_SRC}/dist/pcre_get.c
    ${MODULE_SRC}/dist/pcre_globals.c
    ${MODULE_SRC}/dist/pcre_jit_compile.c
    ${MODULE_SRC}/dist/pcre_maketables.c
    ${MODULE_SRC}/dist/pcre_newline.c
    ${MODULE_SRC}/dist/pcre_ord2utf8.c
    ${MODULE_SRC}/dist/pcre_refcount.c
    ${MODULE_SRC}/dist/pcre_string_utils.c
    ${MODULE_SRC}/dist/pcre_study.c
    ${MODULE_SRC}/dist/pcre_tables.c
    ${MODULE_SRC}/dist/pcre_ucd.c
    ${MODULE_SRC}/dist/pcre_valid_utf8.c
    ${MODULE_SRC}/dist/pcre_version.c
    ${MODULE_SRC}/dist/pcre_xclass.c
)
set_property(TARGET pcre PROPERTY INCLUDE_DIRECTORIES
    ${MODULE_SRC}
    ${MODULE_SRC}/dist
)
