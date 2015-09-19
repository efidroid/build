cmake_minimum_required(VERSION 2.8)
project(libselinux)

set(CMAKE_BUILD_TYPE Release)
set(CMAKE_C_FLAGS "-DHAVE_CONFIG_H")

# main
add_library(selinux STATIC
    ${MODULE_SRC}/src/booleans.c
    ${MODULE_SRC}/src/canonicalize_context.c
    ${MODULE_SRC}/src/disable.c
    ${MODULE_SRC}/src/enabled.c
    ${MODULE_SRC}/src/fgetfilecon.c
    ${MODULE_SRC}/src/fsetfilecon.c
    ${MODULE_SRC}/src/getenforce.c
    ${MODULE_SRC}/src/getfilecon.c
    ${MODULE_SRC}/src/getpeercon.c
    ${MODULE_SRC}/src/lgetfilecon.c
    ${MODULE_SRC}/src/load_policy.c
    ${MODULE_SRC}/src/lsetfilecon.c
    ${MODULE_SRC}/src/policyvers.c
    ${MODULE_SRC}/src/procattr.c
    ${MODULE_SRC}/src/setenforce.c
    ${MODULE_SRC}/src/setfilecon.c
    ${MODULE_SRC}/src/context.c
    ${MODULE_SRC}/src/mapping.c
    ${MODULE_SRC}/src/stringrep.c
    ${MODULE_SRC}/src/compute_create.c
    ${MODULE_SRC}/src/compute_av.c
    ${MODULE_SRC}/src/avc.c
    ${MODULE_SRC}/src/avc_internal.c
    ${MODULE_SRC}/src/avc_sidtab.c
    ${MODULE_SRC}/src/get_initial_context.c
    ${MODULE_SRC}/src/checkAccess.c
    ${MODULE_SRC}/src/sestatus.c
    ${MODULE_SRC}/src/deny_unknown.c
)
set_property(TARGET selinux PROPERTY INCLUDE_DIRECTORIES
	${MODULE_SRC}/src
	${MODULE_SRC}/include
)
target_link_libraries(selinux pcre)
