# debugging
set(Boost_DEBUG ON)

if (WIN32)
  # use static python lib
  add_definitions(-D BOOST_PYTHON_STATIC_LIB)
  # disable autolinking in boost
  add_definitions(-D BOOST_ALL_NO_LIB) # avoid LNK1104 on Windows: http://stackoverflow.com/a/28902261/122441
endif()

if(${CMAKE_VERSION} VERSION_LESS "3.12.0")
  message(STATUS "CMake version < 3.12.0")
  find_package(PythonInterp)
  if (PYTHONINTERP_FOUND)
    if (UNIX AND NOT APPLE)
      find_package(Boost COMPONENTS python${PYTHON_VERSION_SUFFIX})
      if (PYTHON_VERSION_MAJOR EQUAL 3)
          find_package(PythonInterp 3)
          find_package(PythonLibs 3 REQUIRED)
      else()
          find_package(PythonInterp)
          find_package(PythonLibs REQUIRED)
      endif()
    else()
      find_package(Boost COMPONENTS python${PYTHON_VERSION_MAJOR}${PYTHON_VERSION_MINOR})
      if (PYTHON_VERSION_MAJOR EQUAL 3)
          find_package(PythonInterp 3)
          find_package(PythonLibs 3 REQUIRED)
      else()
          find_package(PythonInterp)
          find_package(PythonLibs REQUIRED)
      endif()
    endif()
  else()
    message("Python not found")
  endif()
  execute_process(
    COMMAND ${PYTHON_EXECUTABLE} -c "from distutils.sysconfig import get_python_lib; print get_python_lib(0,0,\"/usr/local\")"
    OUTPUT_VARIABLE PYTHON_SITE_PACKAGES_RAW
    OUTPUT_STRIP_TRAILING_WHITESPACE
  ) # on Ubuntu 11.10 this outputs: /usr/local/lib/python2.7/dist-packages
  execute_process(
    COMMAND ${PYTHON_EXECUTABLE} -c "from distutils.sysconfig import get_python_lib; print get_python_lib(plat_specific=1,standard_lib=0,prefix=\"/usr/local\")"
    OUTPUT_VARIABLE PYTHON_ARCH_PACKAGES_RAW
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
  cmake_path(SET PYTHON_SITE_PACKAGES "${PYTHON_SITE_PACKAGES_RAW}")
  cmake_path(SET PYTHON_ARCH_PACKAGES "${PYTHON_ARCH_PACKAGES_RAW}")
else()
  message(STATUS "CMake version >= 3.12.0")
  if (USE_PY_3)
    find_package(Python3 COMPONENTS Interpreter Development)
    set(PYTHON_INCLUDE_DIRS ${Python3_INCLUDE_DIRS})
    set(PYTHON_LIBRARIES ${Python3_LIBRARIES})
    cmake_path(SET PYTHON_SITE_PACKAGES "${Python3_SITELIB}")
    cmake_path(SET PYTHON_ARCH_PACKAGES "${Python3_SITEARCH}")
    find_package(Boost COMPONENTS python${Python3_VERSION_MAJOR}${Python3_VERSION_MINOR})
  else()
    find_package(Python2 COMPONENTS Interpreter Development)
    set(PYTHON_INCLUDE_DIRS ${Python2_INCLUDE_DIRS})
    set(PYTHON_LIBRARIES ${Python2_LIBRARIES})
    cmake_path(SET PYTHON_SITE_PACKAGES "${Python2_SITELIB}")
    cmake_path(SET PYTHON_ARCH_PACKAGES "${Python2_SITEARCH}")
    find_package(Boost COMPONENTS python${Python2_VERSION_MAJOR}${Python2_VERSION_MINOR})
  endif()
endif()

message(STATUS "Boost_INCLUDE_DIR = ${Boost_INCLUDE_DIR}")
message(STATUS "Boost_INCLUDE_DIRS = ${Boost_INCLUDE_DIRS}")
message(STATUS "Boost_LIBRARY_DIRS = ${Boost_LIBRARY_DIRS}")
message(STATUS "Boost_LIBRARIES = ${Boost_LIBRARIES}")
message(STATUS "PYTHON_INCLUDE_DIRS = ${PYTHON_INCLUDE_DIRS}")
message(STATUS "PYTHON_LIBRARIES = ${PYTHON_LIBRARIES}")
message(STATUS "PYTHON_SITE_PACKAGES = ${PYTHON_SITE_PACKAGES}")
message(STATUS "PYTHON_ARCH_PACKAGES = ${PYTHON_ARCH_PACKAGES}")

include_directories(${Boost_INCLUDE_DIRS})
include_directories(${PYTHON_INCLUDE_DIRS})

# include dirs
include_directories( ${OpenCamLib_SOURCE_DIR}/cutters )
include_directories( ${OpenCamLib_SOURCE_DIR}/geo )
include_directories( ${OpenCamLib_SOURCE_DIR}/algo )
include_directories( ${OpenCamLib_SOURCE_DIR}/dropcutter )
include_directories( ${OpenCamLib_SOURCE_DIR}/common )
include_directories( ${OpenCamLib_SOURCE_DIR} )

# this makes the ocl Python module
add_library(
  ocl 
  MODULE
  pythonlib/ocl_cutters.cpp
  pythonlib/ocl_geometry.cpp
  pythonlib/ocl_algo.cpp
  pythonlib/ocl_dropcutter.cpp
  pythonlib/ocl.cpp
)

message(STATUS "linking Python binary ocl.so with Boost: " ${Boost_PYTHON_LIBRARY} " and OpenMP: " ${OpenMP_CXX_LIBRARIES})

if(APPLE)
  # to avoid the need to link with libpython, we should use dynamic lookup
  SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -undefined dynamic_lookup")
endif()

target_link_libraries(
  ocl
  ocl_common
  ocl_dropcutter
  ocl_cutters
  ocl_geo
  ocl_algo
  ${Boost_LIBRARIES}
  ${OpenMP_CXX_LIBRARIES}
)

if(NOT APPLE)
  target_link_libraries(ocl ${PYTHON_LIBRARIES})
endif()

# this makes the lib name ocl.so and not libocl.so
set_target_properties(ocl PROPERTIES PREFIX "")
# this makes the lib name ocl.pyd and not ocl.so
if (WIN32)
  set_target_properties(ocl PROPERTIES SUFFIX ".pyd")
endif (WIN32)

if (APPLE AND NOT CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  install(
    TARGETS ocl
    LIBRARY DESTINATION lib/python${Python3_VERSION_MAJOR}.${Python3_VERSION_MINOR}/site-packages/ocl
  )
  # these are the python helper lib-files such as camvtk.py
  install(
    DIRECTORY lib/
    DESTINATION lib/python${Python3_VERSION_MAJOR}.${Python3_VERSION_MINOR}/site-packages/ocl
  )
else()
  install(
    TARGETS ocl
    LIBRARY DESTINATION ${PYTHON_ARCH_PACKAGES}
  )
  # these are the python helper lib-files such as camvtk.py 
  install(
    DIRECTORY lib/
    DESTINATION ${PYTHON_SITE_PACKAGES}
    #    PATTERN .svn EXCLUDE
  )
endif()
