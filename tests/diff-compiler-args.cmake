# Copyright (c) 2018 Alain Martin
#
# This file is part of FRUT.
#
# FRUT is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# FRUT is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with FRUT.  If not, see <http://www.gnu.org/licenses/>.

cmake_minimum_required(VERSION 3.4)


macro(parse_script_arguments)

  if(NOT DEFINED jucer_FILE)
    message(FATAL_ERROR "jucer_FILE must be defined")
  endif()
  if(NOT EXISTS ${jucer_FILE})
    message(FATAL_ERROR "No such .jucer file: ${jucer_FILE}")
  endif()
  get_filename_component(jucer_file "${jucer_FILE}" ABSOLUTE)
  get_filename_component(jucer_dir "${jucer_file}" DIRECTORY)
  get_filename_component(jucer_file_name "${jucer_file}" NAME)
  string(REGEX REPLACE "[^A-Za-z0-9]" "_" escaped_jucer_file_name "${jucer_file_name}")

  if(NOT DEFINED configuration)
    set(configuration "Debug")
  endif()

  message(STATUS ".jucer file: ${jucer_file}")
  message(STATUS "build configuration: ${configuration}")

endmacro()


macro(generate_reprojucer_build_system)

  message(STATUS "Generate build system with Reprojucer")

  set(reprojucer_build_dir "${jucer_dir}/build/LinuxMakefile")
  if(NOT IS_DIRECTORY "${reprojucer_build_dir}")
    file(MAKE_DIRECTORY "${reprojucer_build_dir}")
  endif()

  execute_process(
    COMMAND "${CMAKE_COMMAND}" "../.." "-G" "Unix Makefiles"
    "-DCMAKE_BUILD_TYPE=${configuration}"
    "-D${escaped_jucer_file_name}_FILE=${jucer_file}"
    WORKING_DIRECTORY "${reprojucer_build_dir}"
    RESULT_VARIABLE cmake_result
  )
  if(NOT cmake_result EQUAL 0)
    message(FATAL_ERROR "")
  endif()

endmacro()


macro(touch_file_to_compile)

  execute_process(
    COMMAND "${CMAKE_COMMAND}" "-E" "touch_nocreate" "${jucer_dir}/Source/foo.cpp"
  )

endmacro()


macro(do_build)

  execute_process(
    COMMAND ${build_command}
    WORKING_DIRECTORY "${build_working_dir}"
    OUTPUT_VARIABLE build_output
    RESULT_VARIABLE build_result
  )
  if(NOT build_result EQUAL 0)
    message("${build_output}")
    message(FATAL_ERROR "")
  endif()

  string(REGEX MATCH "\n([^\n]+-o[^\n]+-c[^\n]+foo.cpp[^\n]*)\n" m "${build_output}")
  set(compiler_cmd "${CMAKE_MATCH_1}")

endmacro()


macro(build_with_projucer_build_system)

  message(STATUS "Build with the build system generated by Projucer")

  set(build_command "${CMAKE_COMMAND}" "-E" "env" "CONFIG=${configuration}" "make" "-n")
  set(build_working_dir "${jucer_dir}/Builds/LinuxMakefile")
  do_build()
  set(projucer_compiler_cmd "${compiler_cmd}")

  if(NOT projucer_compiler_cmd)
    message(FATAL_ERROR "Failed to extract Projucer's compiler command")
  endif()

endmacro()


macro(build_with_reprojucer_build_system)

  message(STATUS "Build with the build system generated by Reprojucer")

  set(build_command "${CMAKE_COMMAND}" "-E" "env" "VERBOSE=1" "make")
  set(build_working_dir "${reprojucer_build_dir}")
  do_build()
  set(reprojucer_compiler_cmd "${compiler_cmd}")

  if(NOT reprojucer_compiler_cmd)
    message(FATAL_ERROR "Failed to extract Reprojucer's compiler command")
  endif()

endmacro()


macro(diff_compiler_arguments)

  message(STATUS "Diff compiler arguments (old: Projucer, new: Reprojucer)")

  separate_arguments(projucer_compiler_args UNIX_COMMAND "${projucer_compiler_cmd}")
  separate_arguments(reprojucer_compiler_args UNIX_COMMAND "${reprojucer_compiler_cmd}")

  include("${CMAKE_CURRENT_LIST_DIR}/test-utils/simplediff/simplediff.cmake")
  diff(projucer_compiler_args reprojucer_compiler_args args_diff)
  print_diff(args_diff)

endmacro()


macro(main)

  parse_script_arguments()
  generate_reprojucer_build_system()
  touch_file_to_compile()
  build_with_projucer_build_system()
  build_with_reprojucer_build_system()
  diff_compiler_arguments()

endmacro()


if(CMAKE_SCRIPT_MODE_FILE STREQUAL CMAKE_CURRENT_LIST_FILE)
  main()
endif()
