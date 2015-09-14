if(DEFINED CMAKE_TOOLCHAIN_READY)
	return()
endif()

# read dep file into list
string(STRIP "${EFIDROID_PROJECT_DEPS}" PROJECT_DEPS)
string(REGEX REPLACE "[\r\n\t ]" ";" PROJECT_DEPS "${PROJECT_DEPS}")

foreach(dep ${PROJECT_DEPS})
	# set sourcedir variable
	string(TOUPPER "${dep}" dep_srcvar)
	set("${dep_srcvar}_SRC" "${EFIDROID_TOP}/external/${EFIDROID_PROJECT_TYPE}/${dep}")
endforeach(dep)

function(importlib proj name)
	# register lib
	add_library("${name}" STATIC IMPORTED)
	set_target_properties(${name} PROPERTIES
		IMPORTED_LOCATION ${EFIDROID_LIB_DIR}/${proj}/lib${name}.a
	)
endfunction()

# prevent multiple inclusion
set(CMAKE_TOOLCHAIN_READY TRUE)
