#CMAKE_CURRENT_LIST_DIR is the directory containing this file when
#referenced here, at top-level scope, when this file is included.
#From within a macro, CMAKE_CURRENT_LIST_DIR is the directory that
#contains the file being processed and invoking the function.  So,
#to use this files directory within a macro, we need to save it at
#top level scope at include time.
set(THIS_FILE_DIR ${CMAKE_CURRENT_LIST_DIR})

#This macro (currently Windows-only) creates a .RC file that holds all of the application/library's file details. This RC
#file is then appended to the source list for the target.
#
#Parameters:
#PROJECT - The filename of the project (without extension)
#ISLIBRARY - Boolean. If true, this target is a library. If false, it is an application.
#FILE_VER_MAJOR FILE_VER_MINOR FILE_VER_PATCH - Version
#FILE_DESC - Description of the application/library
#FILE_NAME - The full name of the application/library
#RC_APPEND_LIST_NAME - The name of the list to append the RC file to
macro(add_resource_info PROJECT ISLIBRARY FILE_VER_MAJOR FILE_VER_MINOR FILE_VER_PATCH FILE_DESC FILE_NAME RC_APPEND_LIST_NAME)
#If we are creating an RC file for a library, make sure it is a DLL and not a static one. If it's an application, no need to do this check.
set(ISSHAREDLIBRARY FALSE)
if (DEFINED BUILD_SHARED_LIBS)
    set(ISSHAREDLIBRARY ${BUILD_SHARED_LIBS})
endif()

set(IS_APPLICABLE_RESOURCE (NOT ${ISLIBRARY} OR (${ISSHAREDLIBRARY} AND ${ISLIBRARY})))

if(WIN32 AND NOT UNIX AND ${IS_APPLICABLE_RESOURCE})

    if(NOT CMAKE_BUILD_TYPE MATCHES Debug)
        # Finish creating the relevant data for the RC file.
        get_git_head_revision(GIT_REFSPEC GIT_COMMIT_HASH)
    endif()

    string(TIMESTAMP CURRENT_YEAR "%Y")
    if(CMAKE_SIZEOF_VOID_P EQUAL 4)
        set(ARCHITECTURE_DESC "32-bit")
    else()
        set(ARCHITECTURE_DESC "64-bit")
    endif()
    set(FILEATTR_YEAR_RELEASE ${CURRENT_YEAR})
    set(FILE_DESC "${FILE_DESC} (${ARCHITECTURE_DESC})")
    if(ISLIBRARY)
        set(FILEATTR_ORIGINAL_NAME "${PROJECT}.dll ${GIT_COMMIT_HASH}")
    else()
        set(FILEATTR_ORIGINAL_NAME "${PROJECT}.exe ${GIT_COMMIT_HASH}")
    endif()
    
    # The RC file needs explicit variables (as defined in set() statements), because we can't reference macro parameters.
    # Set these as independent variables so that replacement will happen upon calling configure_file()
    if(${CMAKE_PROJECT_NAME}_VERSION_STRING)
        set(PRODUCT_VER_MAJOR ${${CMAKE_PROJECT_NAME}_VERSION_MAJOR})
        set(PRODUCT_VER_MINOR ${${CMAKE_PROJECT_NAME}_VERSION_MINOR})
        set(PRODUCT_VER_PATCH ${${CMAKE_PROJECT_NAME}_VERSION_PATCH})
        set(PRODUCT_VER_EXTRA 0) # TODO: semantic versioning defines additional labels (string), DLL only supports numbers
    else()
        set(PRODUCT_VER_MAJOR ${FILE_VER_MAJOR})
        set(PRODUCT_VER_MINOR ${FILE_VER_MINOR})
        set(PRODUCT_VER_PATCH ${FILE_VER_PATCH})
        set(PRODUCT_VER_EXTRA 0)
    endif()
    set(FILEATTR_VER_MAJOR ${FILE_VER_MAJOR})
    set(FILEATTR_VER_MINOR ${FILE_VER_MINOR})
    set(FILEATTR_VER_PATCH ${FILE_VER_PATCH})
    set(FILEATTR_DESC ${FILE_DESC})
    set(FILEATTR_NAME ${FILE_NAME})
    
    if(CMAKE_COMPILER_IS_MINGW)
        # First we will try to filter out the mingw bin directory using some list operations
        # Make a list
        STRING(REPLACE "/" ";" QT_LIB_DIR_LIST ${QT_LIBRARY_DIR})

        # Remove the last item
        LIST(REMOVE_ITEM QT_LIB_DIR_LIST "lib")
        # Get the length of the list and the last element
        LIST(LENGTH QT_LIB_DIR_LIST len)
        MATH(EXPR previous "${len}-1")
        LIST(GET QT_LIB_DIR_LIST ${previous} MINGW)

        # add resource.o to the source list of the dll or exe
        list(APPEND ${RC_APPEND_LIST_NAME} ${CMAKE_CURRENT_BINARY_DIR}/resource.o)

        # fill in the appropriate information into resource.rc
        configure_file(${THIS_FILE_DIR}/resource.rc.in ${CMAKE_CURRENT_BINARY_DIR}/resource.rc)

        # specify how to convert resource.rc into resource.o, using windres.exe
        add_custom_command(
            OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/resource.o
            COMMAND ${QT_LIBRARY_DIR}/../../../Tools/${MINGW}/bin/windres.exe -i resource.rc -o resource.o
            WORKING_DIRECTORY  ${CMAKE_CURRENT_BINARY_DIR}
            DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/resource.rc
        )
        # More info:
        # * http://www.transmissionzero.co.uk/computing/building-dlls-with-mingw/
        #   section "Adding Version Information and Comments to your DLL"
        # * http://msdn.microsoft.com/en-us/library/aa381058.aspx
    elseif("${CMAKE_CXX_COMPILER_ID}" STREQUAL "MSVC")

        # add resource.rc to the source list of the dll or exe
        list(APPEND ${RC_APPEND_LIST_NAME} ${CMAKE_CURRENT_BINARY_DIR}/resource.rc)

        # fill in the appropriate information into resource.rc
        configure_file(${THIS_FILE_DIR}/resource.rc.in ${CMAKE_CURRENT_BINARY_DIR}/resource.rc)
    endif()
endif(WIN32 AND NOT UNIX AND ${IS_APPLICABLE_RESOURCE})
endmacro()

