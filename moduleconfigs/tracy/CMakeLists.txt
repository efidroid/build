# common
cmake_minimum_required(VERSION 2.8)
project(tracy)
set(CMAKE_BUILD_TYPE Release)

# get architecture
execute_process( COMMAND ${CMAKE_C_COMPILER} -dumpmachine OUTPUT_VARIABLE DUMP_MACHINE OUTPUT_STRIP_TRAILING_WHITESPACE)
string(FIND ${DUMP_MACHINE} "-" DUMP_MACHINE_STRIP)
string(SUBSTRING ${DUMP_MACHINE} 0 ${DUMP_MACHINE_STRIP} ARCHITECTURE)
if("${ARCHITECTURE}" STREQUAL "arm")
  set(ARCH_HEADER "eabi")
  set(ARCH_PATH "arm")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -marm")
endif()

# cflags
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -std=gnu99 -pedantic -Wall -Wextra -Werror -Wno-unused-result -pipe")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fPIC -D_POSIX_SOURCE -D_GNU_SOURCE")
set(CMAKE_C_FLAGS_RELEASE "-O2 -fomit-frame-pointer")
set(CMAKE_C_FLAGS_DEBUG  "-ggdb")

# generate syscall header
execute_process(
	COMMAND ${CMAKE_SOURCE_DIR}/gen_syscall_header ${ARCH_HEADER} ${CMAKE_C_COMPILER} ${CMAKE_BINARY_DIR}/include "${CMAKE_C_FLAGS}"
	OUTPUT_VARIABLE STDOUT
)

# libtracy
add_library(tracy STATIC
	${MODULE_SRC}/src/tracy.c
	${MODULE_SRC}/src/tracy-mem.c
	${MODULE_SRC}/src/tracy-safe-fork.c
	${MODULE_SRC}/src/tracy-modification.c
	${MODULE_SRC}/src/tracy-event.c
	${MODULE_SRC}/src/ll.c
	${MODULE_SRC}/src/trampy.c
	${MODULE_SRC}/src/arch/${ARCH_PATH}/arch.c
)
set_property(TARGET tracy PROPERTY INCLUDE_DIRECTORIES
	${CMAKE_BINARY_DIR}/include
)
target_link_libraries(tracy pthread)
