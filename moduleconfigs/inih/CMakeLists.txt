cmake_minimum_required(VERSION 2.8)
project(inih)

set(CMAKE_BUILD_TYPE Release)

# main
add_library(inih STATIC
    $ENV{MODULE_DIR}/ini.c
)
set_property(TARGET inih PROPERTY INCLUDE_DIRECTORIES
    $ENV{MODULE_DIR}
)
