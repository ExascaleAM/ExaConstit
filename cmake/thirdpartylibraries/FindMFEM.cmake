# We make use of the Serac FindMFEM.cmake file, since their file works better
# than our own.

#Copyright (c) 2019-2020, Lawrence Livermore National Security, LLC.
#All rights reserved.

#Redistribution and use in source and binary forms, with or without
#modification, are permitted provided that the following conditions are met:

#* Redistributions of source code must retain the above copyright notice, this
#  list of conditions and the following disclaimer.

#* Redistributions in binary form must reproduce the above copyright notice,
#  this list of conditions and the following disclaimer in the documentation
#  and/or other materials provided with the distribution.

#* Neither the name of the copyright holder nor the names of its
#  contributors may be used to endorse or promote products derived from
#  this software without specific prior written permission.

#THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
#AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
#IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
#FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
#DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
#SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
#CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
#OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
#OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#------------------------------------------------------------------------------
# Setup MFEM
#
# This file defines:
#  MFEM_FOUND        - If MFEM was found
#  MFEM_INCLUDE_DIRS - The MFEM include directories
#  MFEM_LIBRARY      - The MFEM library
#------------------------------------------------------------------------------

if(NOT MFEM_DIR)
    message(FATAL_ERROR "MFEM support needs explicit MFEM_DIR")
endif()

message(STATUS "Looking for MFEM using MFEM_DIR = ${MFEM_DIR}")

set(_mfem_cmake_config "${MFEM_DIR}/MFEMConfig.cmake")

if(EXISTS ${_mfem_cmake_config})
    # MFEM was built with CMake so use that config file
    message(STATUS "Using MFEM's CMake config file: ${_mfem_cmake_config}")

    include(${_mfem_cmake_config})

    # TODO: This needs to be verified
    set(MFEM_INCLUDE_DIRS  ${MFEM_INCLUDE_DIRS} )
    set(MFEM_LIBRARIES     ${MFEM_LIBRARIES} )

else()
    find_path(
        MFEM_INCLUDE_DIRS mfem.hpp
        PATHS ${MFEM_DIR}/include
        NO_DEFAULT_PATH
        NO_CMAKE_ENVIRONMENT_PATH
        NO_CMAKE_PATH
        NO_SYSTEM_ENVIRONMENT_PATH
        NO_CMAKE_SYSTEM_PATH
    )

    find_library(
        MFEM_LIBRARIES NAMES mfem
        PATHS ${MFEM_DIR}/lib
        NO_DEFAULT_PATH
        NO_CMAKE_ENVIRONMENT_PATH
        NO_CMAKE_PATH
        NO_SYSTEM_ENVIRONMENT_PATH
        NO_CMAKE_SYSTEM_PATH )


    # when MFEM is built w/o cmake, we can get the details
    # of deps from its config.mk file
    find_path(
        MFEM_CFG_DIR config.mk
        PATHS ${MFEM_DIR}/share/mfem/
        NO_DEFAULT_PATH
        NO_CMAKE_ENVIRONMENT_PATH
        NO_CMAKE_PATH
        NO_SYSTEM_ENVIRONMENT_PATH
        NO_CMAKE_SYSTEM_PATH
    )

    if(NOT MFEM_CFG_DIR)
        message(FATAL_ERROR "Failed to find any MFEM build configuration files in ${MFEM_DIR}")
    else()
        message(STATUS "Using MFEM's GNU Make config file: ${MFEM_CFG_DIR}/config.mk")
    endif()

    # read config.mk file
    file(READ "${MFEM_CFG_DIR}/config.mk" mfem_cfg_file_txt)

    # parse include flags
    string(REGEX MATCHALL "MFEM_TPLFLAGS .+\n" mfem_tpl_inc_flags ${mfem_cfg_file_txt})
    string(REGEX REPLACE  "MFEM_TPLFLAGS +=" "" mfem_tpl_inc_flags ${mfem_tpl_inc_flags})
    string(FIND  ${mfem_tpl_inc_flags} "\n" mfem_tpl_inc_flags_end_pos)
    string(SUBSTRING ${mfem_tpl_inc_flags} 0 ${mfem_tpl_inc_flags_end_pos} mfem_tpl_inc_flags)
    string(STRIP ${mfem_tpl_inc_flags} mfem_tpl_inc_flags)

    # remove the " -I" and add them to the include dir list
    separate_arguments(mfem_tpl_inc_flags)
    foreach(_include_flag ${mfem_tpl_inc_flags})
        string(FIND ${_include_flag} "-I" _pos)
        if(_pos EQUAL 0)
            string(SUBSTRING ${_include_flag} 2 -1 _include_dir)
            list(APPEND MFEM_INCLUDE_DIRS ${_include_dir})
        endif()
    endforeach()

    # parse link flags
    string(REGEX MATCHALL "MFEM_EXT_LIBS .+\n" mfem_tpl_lnk_flags ${mfem_cfg_file_txt})
    string(REGEX REPLACE  "MFEM_EXT_LIBS +=" "" mfem_tpl_lnk_flags ${mfem_tpl_lnk_flags})
    string(FIND  ${mfem_tpl_lnk_flags} "\n" mfem_tpl_lnl_flags_end_pos )
    string(SUBSTRING ${mfem_tpl_lnk_flags} 0 ${mfem_tpl_lnl_flags_end_pos} mfem_tpl_lnk_flags)
    string(STRIP ${mfem_tpl_lnk_flags} mfem_tpl_lnk_flags)

    list(APPEND MFEM_LIBRARIES ${mfem_tpl_lnk_flags})
endif()

include(FindPackageHandleStandardArgs)
# handle the QUIETLY and REQUIRED arguments and set MFEM_FOUND to TRUE
# if all listed variables are TRUE
find_package_handle_standard_args(MFEM DEFAULT_MSG
                                  MFEM_LIBRARIES
                                  MFEM_INCLUDE_DIRS )

if(NOT MFEM_FOUND)
    message(FATAL_ERROR "MFEM_FOUND is not a path to a valid MFEM install")
endif()

if(ENABLE_HIP)
    find_package(ROCSPARSE REQUIRED)
    find_package(HIPBLAS REQUIRED)
    find_package(ROCRAND REQUIRED)
endif()

if(ENABLE_CUDA)
    find_package(CUDAToolkit REQUIRED)
endif()

message(STATUS "MFEM Includes: ${MFEM_INCLUDE_DIRS}")
message(STATUS "MFEM Libraries: ${MFEM_LIBRARIES}")