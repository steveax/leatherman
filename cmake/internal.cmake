# This file contains the macros used to add and manage leatherman
# libraries. If you are adding a new library to leatherman, this is
# probably the place to go for documentation. If you're just using
# Leatherman, you should check out the README for information on its
# interface.

####
# Macros for use by leatherman libraries
#
# These are the API that libraries use to build themselves as
# "standard" leatherman components"
####

# Usage: add_leatherman_deps(${DEP1_LIB} ${DEP2_LIB})
#
# Append to the LEATHERMAN_<LIBRARY>_DEPS variable.
macro(add_leatherman_deps)
    list(APPEND ${deps_var} ${ARGV})
    export_var(${deps_var})
endmacro()

# Usage: leatherman_dependency("libname")
#
# Automatically handle include directories and library linking for the
# given leatherman library.
#
# Will throw a fatal error if the dependency cannot be found.
macro(leatherman_dependency library)
    string(MAKE_C_IDENTIFIER "${library}" id)
    string(TOUPPER "${id}" name)
    set(option "LEATHERMAN_USE_${name}")
    set(dep_lib "LEATHERMAN_${name}_LIB")
    set(dep_deps "LEATHERMAN_${name}_DEPS")
    set(dep_include "LEATHERMAN_${name}_INCLUDE")

    if(${${option}})
	debug("Found ${library} as ${name}, using it in current context")
	if (NOT "" STREQUAL "${${dep_deps}}")
	    debug("Adding ${${dep_deps}} to deps for ${dirname}")
	    list(APPEND ${deps_var} ${${dep_deps}})
	    export_var(${deps_var})
	endif()
	if (NOT "" STREQUAL "${${dep_lib}}")
	    debug("Adding ${${dep_lib}} to deps for ${dirname}")
	    list(APPEND ${deps_var} ${${dep_lib}})
	    export_var(${deps_var})
	endif()
	if (NOT "" STREQUAL "${${dep_include}}")
	    debug("Adding ${${dep_include}} to include directories for ${dirname}")
	    include_directories(${${dep_include}})
	endif()
    else()
	message(FATAL_ERROR "${library} not found as a dependency for ${dirname}")
    endif()
endmacro()

# Usage: add_leatherman_library(${SOURCES} [OPTS])
#
# Creates a static CMake library built from the provided sources. Sets
# LETHERMAN_<LIBRARY>_LIB to the name of this library.
#
# This macro directly calls add_library, so any add_library options
# can be passed along with the sources.
#
# This macro cannot be invoked multiple times
macro(add_leatherman_library)
    include_directories(${${include_var}})
    add_library(${libname} STATIC ${ARGV})
    set_target_properties(${libname} PROPERTIES COMPILE_FLAGS "${LEATHERMAN_CXX_FLAGS} ${LEATHERMAN_LIBRARY_FLAGS}")
    set(${lib_var} "${libname}" PARENT_SCOPE)
endmacro()

# Usage: add_leatherman_test(${SOURCES} [OPTS])
#
# Creates a static CMake library that will be linked into the
# leatherman test binary.
#
# This macro directly calls add_library, so any add_library options
# can be passed along with the sources.
#
# This macro cannot be invoked multiple times.
macro(add_leatherman_test)
    if(LEATHERMAN_ENABLE_TESTING)
	leatherman_dependency(catch)
	add_library(${testlibname} STATIC ${ARGV})
	set_target_properties(${testlibname} PROPERTIES COMPILE_FLAGS ${LEATHERMAN_CXX_FLAGS})
	set(${testlib_var} "${testlibname}" PARENT_SCOPE)
    endif()
endmacro()

####
# Macros for use in the top-level leatherman CMakeLists.txt
#
# These macros are used to build up the variables which are passed
# into whatever project is including leatherman
####

# Usage: add_leatherman_dir(subdir [EXCLUDE_FROM_VARS])
#
# Creates all of the CMake variables intended to be used by consumers
# of leatherman, including the ENABLE flag.
#
# If the enable flag is set, also sets up the variables used by the
# library API macros and adds the named subdirectory to the CMake
# project.
#
# If EXCLUDE_FROM_VARS is present, this library will not be added to
# the LEATHERMAN_LIBRARIES and LEATHERMAN_INCLUDE variables. The
# LEATHERMAN_<LIBRARY>_<FIELD> variables will still be set.
macro(add_leatherman_dir dir)
    debug("Setting up leatherman library for ${dir}")
    string(MAKE_C_IDENTIFIER "${dir}" id)
    string(TOUPPER "${id}" id_upper)
    set(dirname "${dir}") # Used by other macros to know our human-readable name
    set(option "LEATHERMAN_USE_${id_upper}")
    set(include_dir "${CMAKE_CURRENT_SOURCE_DIR}/${dir}/inc")
    set(libname "leatherman_${id}")
    set(testlibname "${libname}_test")

    defoption(${option} "Should ${dir} be built and used?" ${LEATHERMAN_DEFAULT_ENABLE})
    if (${${option}})
	set(include_var "LEATHERMAN_${id_upper}_INCLUDE")
	set(lib_var "LEATHERMAN_${id_upper}_LIB")
	set(deps_var "LEATHERMAN_${id_upper}_DEPS")
	set(testlib_var "LEATHERMAN_${id_upper}_TESTLIB")
 
	set(${include_var} ${include_dir})
	set(${lib_var} "") # if library is built, this will be set automatically
	set(${testlib_var} "") # if tests are specified, this will be set automatically

	# By adding the subdirectory after setting all variables, but
	# before exporting, we give the library an opportunity to
	# munge them (for example, to add vendor dirs)
	add_subdirectory("${dir}")

	# We set this one afterwards because it doesn't need
	# overriding
	#
	# We put deps before libs. This is backwards on purpose. We
	# later reverse the entire libraries list in order to ensure
	# proper link order. Ideally we could put things in the
	# correct order directly, but CMake de-duplicates link lines
	# in ways that just make this a sad, sad process.
	set(libs_var "LEATHERMAN_${id_upper}_LIBS")
	set(${libs_var} ${${deps_var}} ${${lib_var}})

	if(NOT "${ARGV1}" STREQUAL EXCLUDE_FROM_VARS)
	    debug("Appending values for ${id_upper} to common vars")
	    list(APPEND LEATHERMAN_INCLUDE_DIRS ${${include_var}})
	    list(APPEND LEATHERMAN_LIBRARIES ${${libs_var}})
	    list(APPEND LEATHERMAN_TESTLIBS ${${testlib_var}})
	else()
	    debug("Excluding values for ${id_upper} from common vars")
	endif()


	# Put our link line into the right order.
        if("${${libs_var}}")
            list(REVERSE ${libs_var})
        endif()

	export_var(${include_var})
	export_var(${lib_var})
	export_var(${libs_var})
	export_var(${deps_var})

	# Enable cppcheck on this library	
	list(APPEND CPPCHECK_DIRS "${CMAKE_SOURCE_DIR}/${dir}")
    endif()
endmacro(add_leatherman_dir)

####
# Helper Macros
####

# Usage: debug("Something cool is happening")
#
# Print message if LEATHERMAN_DEBUG is set. Used to introspect macro
# logic.
macro(debug str)
    if (LEATHERMAN_DEBUG)
	message(STATUS ${str})
    endif()
endmacro(debug)

# Usage: export_var("foobar")
#
# Sets variable "foobar" in the parent scope to the same value as
# "foobar" in the invoking scope. Remember that a macro does not
# create a new scope, but a function does.
macro(export_var varname)
    if (NOT "${CMAKE_CURRENT_SOURCE_DIR}" STREQUAL "${CMAKE_SOURCE_DIR}")
	debug("Exporting ${varname}")
	set(${varname} ${${varname}} PARENT_SCOPE)
    else()
	debug("Skipping export of ${varname} because I'm top-level")
    endif()
    debug("It's value is: ${${varname}}")
endmacro(export_var)

# Usage: defoption(VARNAME "Documentation String" ${DEFAULT_VALUE}")
#
# Define an option that will only be set to DEFAULT_VALUE if it does
# not already exist in this scope. If the variable is available in the
# scope, the option will keep the current value. This works around a
# weird CMake behavior where set(OPTION_VAR TRUE) does not cause
# option() to ignore its default.
macro(defoption name doc default)
    if(DEFINED ${name})
	debug("${name} is already set, using it")
	set(enabled ${${name}})
    else()
	debug("${name} unset, using default")
	set(enabled ${default})
    endif()
    option(${name} ${doc} ${enabled})
endmacro()