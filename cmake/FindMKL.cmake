# Forked from PyTorch Repository: https://raw.githubusercontent.com/pytorch/pytorch/master/cmake/Modules/FindMKL.cmake
# Extract MKL libraries from $MKLROOT variable - mgwoo added

# - Find INTEL MKL library
#
# This module sets the following variables:
#  MKL_FOUND - set to true if a library implementing the CBLAS interface is found
#  MKL_VERSION - best guess of the found mkl version
#  MKL_INCLUDE_DIR - path to include dir.
#  MKL_LIBRARIES - list of libraries for base mkl
#  MKL_OPENMP_TYPE - OpenMP flavor that the found mkl uses: GNU or Intel
#  MKL_OPENMP_LIBRARY - path to the OpenMP library the found mkl uses
#  MKL_LAPACK_LIBRARIES - list of libraries to add for lapack
#  MKL_SCALAPACK_LIBRARIES - list of libraries to add for scalapack
#  MKL_SOLVER_LIBRARIES - list of libraries to add for the solvers
#  MKL_CDFT_LIBRARIES - list of libraries to add for the solvers

# Do nothing if MKL_FOUND was set before!
IF (NOT MKL_FOUND)

SET(MKL_VERSION)
SET(MKL_INCLUDE_DIR)
SET(MKL_LIBRARIES)
SET(MKL_OPENMP_TYPE)
SET(MKL_OPENMP_LIBRARY)
SET(MKL_LAPACK_LIBRARIES)
SET(MKL_SCALAPACK_LIBRARIES)
SET(MKL_SOLVER_LIBRARIES)
SET(MKL_CDFT_LIBRARIES)

# Includes
INCLUDE(CheckTypeSize)
INCLUDE(CheckFunctionExists)

# Intel Compiler Suite
SET(INTEL_COMPILER_DIR "/opt/intel" CACHE STRING
  "Root directory of the Intel Compiler Suite (contains ipp, mkl, etc.)")
SET(INTEL_MKL_DIR "/opt/intel/mkl" CACHE STRING
  "Root directory of the Intel MKL (standalone)")
SET(INTEL_MKL_DIR_ENV $ENV{MKLROOT} CACHE PATH 
  "Folder contains MKL")

SET(INTEL_MKL_SEQUENTIAL OFF CACHE BOOL
  "Force using the sequential (non threaded) libraries")

# Checks
CHECK_TYPE_SIZE("void*" SIZE_OF_VOIDP)
IF ("${SIZE_OF_VOIDP}" EQUAL 8)
  SET(mklvers "intel64")
  SET(iccvers "intel64")
  SET(mkl64s "_lp64")
ELSE ("${SIZE_OF_VOIDP}" EQUAL 8)
  SET(mklvers "32")
  SET(iccvers "ia32")
  SET(mkl64s)
ENDIF ("${SIZE_OF_VOIDP}" EQUAL 8)
IF(CMAKE_COMPILER_IS_GNUCC)
  SET(mklthreads "mkl_gnu_thread" "mkl_intel_thread")
  SET(mklifaces  "intel" "gf")
  SET(mklrtls "gomp" "iomp5")
ELSE(CMAKE_COMPILER_IS_GNUCC)
  SET(mklthreads "mkl_intel_thread")
  SET(mklifaces  "intel")
  SET(mklrtls "iomp5" "guide")
  IF (MSVC)
    SET(mklrtls "libiomp5md")
  ENDIF (MSVC)
ENDIF (CMAKE_COMPILER_IS_GNUCC)

# Kernel libraries dynamically loaded
SET(mklkerlibs "mc" "mc3" "nc" "p4n" "p4m" "p4m3" "p4p" "def")
SET(mklseq)

# Paths
SET(saved_CMAKE_LIBRARY_PATH ${CMAKE_LIBRARY_PATH})
SET(saved_CMAKE_INCLUDE_PATH ${CMAKE_INCLUDE_PATH})
IF(WIN32)
  # Set default MKLRoot for Windows
  IF($ENV{MKLProductDir})
    SET(INTEL_COMPILER_DIR $ENV{MKLProductDir})
  ELSE()
    SET(INTEL_COMPILER_DIR
     "C:/Program Files (x86)/IntelSWTools/compilers_and_libraries/windows")
  ENDIF()
  # Change mklvers and iccvers when we are using MSVC instead of ICC
  IF(MSVC AND NOT CMAKE_CXX_COMPILER_ID STREQUAL "Intel")
    SET(mklvers "${mklvers}_win")
    SET(iccvers "${iccvers}_win")
  ENDIF()
# Mac path
ELSEIF (APPLE)
  SET(mklvers "")
ENDIF()


IF (EXISTS ${INTEL_COMPILER_DIR})
  # TODO: diagnostic if dir does not exist
  SET(CMAKE_LIBRARY_PATH ${CMAKE_LIBRARY_PATH}
    "${INTEL_COMPILER_DIR}/lib/${iccvers}")
  IF(MSVC)
    SET(CMAKE_LIBRARY_PATH ${CMAKE_LIBRARY_PATH}
      "${INTEL_COMPILER_DIR}/compiler/lib/${iccvers}")
  ENDIF()
  IF (NOT EXISTS ${INTEL_MKL_DIR})
    SET(INTEL_MKL_DIR "${INTEL_COMPILER_DIR}/mkl")
  ENDIF()
ENDIF()
IF (EXISTS ${INTEL_MKL_DIR})
  # TODO: diagnostic if dir does not exist
  SET(CMAKE_INCLUDE_PATH ${CMAKE_INCLUDE_PATH}
    "${INTEL_MKL_DIR}/include")
  SET(CMAKE_LIBRARY_PATH ${CMAKE_LIBRARY_PATH}
    "${INTEL_MKL_DIR}/lib/${mklvers}")
  IF (MSVC)
    SET(CMAKE_LIBRARY_PATH ${CMAKE_LIBRARY_PATH}
      "${INTEL_MKL_DIR}/lib/${iccvers}")
  ENDIF()
# get MKL directory from $MKLROOT
ELSEIF(EXISTS ${INTEL_MKL_DIR_ENV})
  SET(CMAKE_INCLUDE_PATH ${CMAKE_INCLUDE_PATH}
    "${INTEL_MKL_DIR_ENV}/include")
  SET(CMAKE_LIBRARY_PATH ${CMAKE_LIBRARY_PATH}
    "${INTEL_MKL_DIR_ENV}/lib/${mklvers}")
  IF (MSVC)
    SET(CMAKE_LIBRARY_PATH ${CMAKE_LIBRARY_PATH}
      "${INTEL_MKL_DIR_ENV}/lib/${iccvers}")
  ENDIF()
ENDIF()

# Try linking multiple libs
MACRO(CHECK_ALL_LIBRARIES LIBRARIES OPENMP_TYPE OPENMP_LIBRARY _name _list _flags)
  # This macro checks for the existence of the combination of libraries given by _list.
  # If the combination is found, this macro checks whether we can link against that library
  # combination using the name of a routine given by _name using the linker
  # flags given by _flags.  If the combination of libraries is found and passes
  # the link test, LIBRARIES is set to the list of complete library paths that
  # have been found.  Otherwise, LIBRARIES is set to FALSE.
  # N.B. _prefix is the prefix applied to the names of all cached variables that
  # are generated internally and marked advanced by this macro.
  SET(_prefix "${LIBRARIES}")
  # start checking
  SET(_libraries_work TRUE)
  SET(${LIBRARIES})
  SET(${OPENMP_TYPE})
  SET(${OPENMP_LIBRARY})
  SET(_combined_name)
  SET(_openmp_type)
  SET(_openmp_library)
  SET(_paths)
  IF (NOT MKL_FIND_QUIETLY)
    set(_str_list)
    foreach(_elem ${_list})
      if(_str_list)
        set(_str_list "${_str_list} - ${_elem}")
      else()
        set(_str_list "${_elem}")
      endif()
    endforeach(_elem)
    message(STATUS "Checking for [${_str_list}]")
  ENDIF ()
  FOREACH(_library ${_list})
    SET(_combined_name ${_combined_name}_${_library})
    UNSET(${_prefix}_${_library}_LIBRARY)
    IF(_libraries_work)
      IF(${_library} MATCHES "omp")
        IF(_openmp_type)
          MESSAGE(FATAL_ERROR "More than one OpenMP libraries appear in the MKL test: ${_list}")
        ELSEIF(${_library} MATCHES "gomp")
          SET(_openmp_type "GNU")
          # Use FindOpenMP to find gomp
          FIND_PACKAGE(OpenMP QUIET)
          IF(OPENMP_FOUND)
            # Test that none of the found library names contains "iomp" (Intel
            # OpenMP). This doesn't necessarily mean that we have gomp... but it
            # is probably good enough since on gcc we should already have
            # OpenMP_CXX_FLAGS="-fopenmp" and OpenMP_CXX_LIB_NAMES="".
            SET(_found_gomp true)
            FOREACH(_lib_name ${OpenMP_CXX_LIB_NAMES})
              IF (_found_gomp AND "${_lib_name}" MATCHES "iomp")
                SET(_found_gomp false)
              ENDIF()
            ENDFOREACH()
            IF(_found_gomp)
              SET(${_prefix}_${_library}_LIBRARY ${OpenMP_CXX_FLAGS})
              SET(_openmp_library "${${_prefix}_${_library}_LIBRARY}")
            ENDIF()
          ENDIF(OPENMP_FOUND)
        ELSEIF(${_library} MATCHES "iomp")
          SET(_openmp_type "Intel")
          IF(${_library} MATCHES "mkl")
            FIND_LIBRARY(${_prefix}_${_library}_LIBRARY NAMES lib${_library}.a)
          ELSE()
            FIND_LIBRARY(${_prefix}_${_library}_LIBRARY NAMES ${_library})
          ENDIF()
          SET(_openmp_library "${${_prefix}_${_library}_LIBRARY}")
        ELSE()
          MESSAGE(FATAL_ERROR "Unknown OpenMP flavor: ${_library}")
        ENDIF()
      ELSE(${_library} MATCHES "omp")
        IF(${_library} MATCHES "mkl")
          FIND_LIBRARY(${_prefix}_${_library}_LIBRARY NAMES lib${_library}.a)
        ELSE()
          FIND_LIBRARY(${_prefix}_${_library}_LIBRARY NAMES ${_library})
        ENDIF()
      ENDIF(${_library} MATCHES "omp")
      MARK_AS_ADVANCED(${_prefix}_${_library}_LIBRARY)
      SET(${LIBRARIES} ${${LIBRARIES}} ${${_prefix}_${_library}_LIBRARY})
      SET(_libraries_work ${${_prefix}_${_library}_LIBRARY})
      IF (NOT MKL_FIND_QUIETLY)
        IF(${_prefix}_${_library}_LIBRARY)
          MESSAGE(STATUS "  Library ${_library}: ${${_prefix}_${_library}_LIBRARY}")
        ELSE(${_prefix}_${_library}_LIBRARY)
          MESSAGE(STATUS "  Library ${_library}: not found")
        ENDIF(${_prefix}_${_library}_LIBRARY)
      ENDIF ()
    ENDIF(_libraries_work)
  ENDFOREACH(_library ${_list})
  # Test this combination of libraries.
  IF(_libraries_work)
    SET(CMAKE_REQUIRED_LIBRARIES ${_flags} ${${LIBRARIES}})
    SET(CMAKE_REQUIRED_LIBRARIES "${CMAKE_REQUIRED_LIBRARIES};${CMAKE_REQUIRED_LIBRARIES}")
    CHECK_FUNCTION_EXISTS(${_name} ${_prefix}${_combined_name}_WORKS)
    SET(CMAKE_REQUIRED_LIBRARIES)
    MARK_AS_ADVANCED(${_prefix}${_combined_name}_WORKS)
    SET(_libraries_work ${${_prefix}${_combined_name}_WORKS})
  ENDIF(_libraries_work)
  # Fin
  IF(_libraries_work)
    SET(${OPENMP_TYPE} ${_openmp_type})
    MARK_AS_ADVANCED(${OPENMP_TYPE})
    SET(${OPENMP_LIBRARY} ${_openmp_library})
    MARK_AS_ADVANCED(${OPENMP_LIBRARY})
  ELSE (_libraries_work)
    SET(${LIBRARIES})
    MARK_AS_ADVANCED(${LIBRARIES})
  ENDIF(_libraries_work)
ENDMACRO(CHECK_ALL_LIBRARIES)

IF(WIN32)
  SET(mkl_m "")
  SET(mkl_pthread "")
ELSE(WIN32)
  SET(mkl_m "m")
  SET(mkl_pthread "pthread")
ENDIF(WIN32)

IF(UNIX AND NOT APPLE)
  SET(mkl_dl "${CMAKE_DL_LIBS}")
ELSE(UNIX AND NOT APPLE)
  SET(mkl_dl "")
ENDIF(UNIX AND NOT APPLE)

# Check for version 10/11
IF (NOT MKL_LIBRARIES)
  SET(MKL_VERSION 1011)
ENDIF (NOT MKL_LIBRARIES)

# First: search for parallelized ones with intel thread lib
IF (NOT INTEL_MKL_SEQUENTIAL)
  FOREACH(mklrtl ${mklrtls} "")
    FOREACH(mkliface ${mklifaces})
      FOREACH(mkl64 ${mkl64s} "")
        FOREACH(mklthread ${mklthreads})
          IF (NOT MKL_LIBRARIES)
            CHECK_ALL_LIBRARIES(MKL_LIBRARIES MKL_OPENMP_TYPE MKL_OPENMP_LIBRARY cblas_sgemm
              "mkl_${mkliface}${mkl64};${mklthread};mkl_core;${mklrtl};${mkl_pthread};${mkl_m};${mkl_dl}" "")
          ENDIF (NOT MKL_LIBRARIES)
        ENDFOREACH(mklthread)
      ENDFOREACH(mkl64)
    ENDFOREACH(mkliface)
  ENDFOREACH(mklrtl)
ENDIF (NOT INTEL_MKL_SEQUENTIAL)

# Second: search for sequential ones
FOREACH(mkliface ${mklifaces})
  FOREACH(mkl64 ${mkl64s} "")
    IF (NOT MKL_LIBRARIES)
      CHECK_ALL_LIBRARIES(MKL_LIBRARIES MKL_OPENMP_TYPE MKL_OPENMP_LIBRARY cblas_sgemm
        "mkl_${mkliface}${mkl64};mkl_sequential;mkl_core;${mkl_m};${mkl_dl}" "")
      IF (MKL_LIBRARIES)
        SET(mklseq "_sequential")
      ENDIF (MKL_LIBRARIES)
    ENDIF (NOT MKL_LIBRARIES)
  ENDFOREACH(mkl64)
ENDFOREACH(mkliface)

# First: search for parallelized ones with native pthread lib
FOREACH(mklrtl ${mklrtls} "")
  FOREACH(mkliface ${mklifaces})
    FOREACH(mkl64 ${mkl64s} "")
      IF (NOT MKL_LIBRARIES)
        CHECK_ALL_LIBRARIES(MKL_LIBRARIES MKL_OPENMP_TYPE MKL_OPENMP_LIBRARY cblas_sgemm
          "mkl_${mkliface}${mkl64};${mklthread};mkl_core;${mklrtl};pthread;${mkl_m};${mkl_dl}" "")
      ENDIF (NOT MKL_LIBRARIES)
    ENDFOREACH(mkl64)
  ENDFOREACH(mkliface)
ENDFOREACH(mklrtl)

# Check for older versions
IF (NOT MKL_LIBRARIES)
  SET(MKL_VERSION 900)
  CHECK_ALL_LIBRARIES(MKL_LIBRARIES MKL_OPENMP_TYPE MKL_OPENMP_LIBRARY cblas_sgemm
    "mkl;guide;pthread;m" "")
ENDIF (NOT MKL_LIBRARIES)

# Include files
IF (MKL_LIBRARIES)
  FIND_PATH(MKL_INCLUDE_DIR "mkl_cblas.h")
  MARK_AS_ADVANCED(MKL_INCLUDE_DIR)
ENDIF (MKL_LIBRARIES)

# Other libraries
IF (MKL_LIBRARIES)
  FOREACH(mkl64 ${mkl64s} "_core" "")
    FOREACH(mkls ${mklseq} "")
      IF (NOT MKL_LAPACK_LIBRARIES)
        FIND_LIBRARY(MKL_LAPACK_LIBRARIES NAMES "libmkl_lapack${mkl64}${mkls}.a")
        MARK_AS_ADVANCED(MKL_LAPACK_LIBRARIES)
      ENDIF (NOT MKL_LAPACK_LIBRARIES)
      IF (NOT MKL_SCALAPACK_LIBRARIES)
        FIND_LIBRARY(MKL_SCALAPACK_LIBRARIES NAMES "libmkl_scalapack${mkl64}${mkls}.a")
        MARK_AS_ADVANCED(MKL_SCALAPACK_LIBRARIES)
      ENDIF (NOT MKL_SCALAPACK_LIBRARIES)
      IF (NOT MKL_SOLVER_LIBRARIES)
        FIND_LIBRARY(MKL_SOLVER_LIBRARIES NAMES "libmkl_solver${mkl64}${mkls}.a")
        MARK_AS_ADVANCED(MKL_SOLVER_LIBRARIES)
      ENDIF (NOT MKL_SOLVER_LIBRARIES)
      IF (NOT MKL_CDFT_LIBRARIES)
        FIND_LIBRARY(MKL_CDFT_LIBRARIES NAMES "libmkl_cdft${mkl64}${mkls}.a")
        MARK_AS_ADVANCED(MKL_CDFT_LIBRARIES)
      ENDIF (NOT MKL_CDFT_LIBRARIES)
    ENDFOREACH(mkls)
  ENDFOREACH(mkl64)
ENDIF (MKL_LIBRARIES)

# LibIRC: intel compiler always links this;
# gcc does not; but mkl kernels sometimes need it.
IF (MKL_LIBRARIES)
  IF (CMAKE_COMPILER_IS_GNUCC)
    FIND_LIBRARY(MKL_KERNEL_libirc "irc")
  ELSEIF (CMAKE_C_COMPILER_ID AND NOT CMAKE_C_COMPILER_ID STREQUAL "Intel")
    FIND_LIBRARY(MKL_KERNEL_libirc "irc")
  ENDIF (CMAKE_COMPILER_IS_GNUCC)
  MARK_AS_ADVANCED(MKL_KERNEL_libirc)
  IF (MKL_KERNEL_libirc)
    SET(MKL_LIBRARIES ${MKL_LIBRARIES} ${MKL_KERNEL_libirc})
  ENDIF (MKL_KERNEL_libirc)
ENDIF (MKL_LIBRARIES)

# Final
SET(CMAKE_LIBRARY_PATH ${saved_CMAKE_LIBRARY_PATH})
SET(CMAKE_INCLUDE_PATH ${saved_CMAKE_INCLUDE_PATH})
IF (MKL_LIBRARIES AND MKL_INCLUDE_DIR)
  SET(MKL_FOUND TRUE)
ELSE (MKL_LIBRARIES AND MKL_INCLUDE_DIR)
  if (MKL_LIBRARIES AND NOT MKL_INCLUDE_DIR)
    MESSAGE(WARNING "MKL libraries files are found, but MKL header files are \
      not. You can get them by `conda install mkl-include` if using conda (if \
      it is missing, run `conda upgrade -n root conda` first), and \
      `pip install mkl-devel` if using pip. If build fails with header files \
      available in the system, please make sure that CMake will search the \
      directory containing them, e.g., by setting CMAKE_INCLUDE_PATH.")
  endif()
  SET(MKL_FOUND FALSE)
  SET(MKL_VERSION)  # clear MKL_VERSION
ENDIF (MKL_LIBRARIES AND MKL_INCLUDE_DIR)

# Standard termination
IF(NOT MKL_FOUND AND MKL_FIND_REQUIRED)
  MESSAGE(FATAL_ERROR "MKL library not found. Please specify library location")
ENDIF(NOT MKL_FOUND AND MKL_FIND_REQUIRED)
IF(NOT MKL_FIND_QUIETLY)
  IF(MKL_FOUND)
    MESSAGE(STATUS "MKL library found")
  ELSE(MKL_FOUND)
    MESSAGE(STATUS "MKL library not found")
  ENDIF(MKL_FOUND)
ENDIF(NOT MKL_FIND_QUIETLY)

# Do nothing if MKL_FOUND was set before!
ENDIF (NOT MKL_FOUND)
