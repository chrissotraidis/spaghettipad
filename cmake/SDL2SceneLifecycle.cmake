# SDL2's project hook runs before CMake enumerates its sources. Keep this
# compatibility backport scoped to the fetched iOS SDL2 input.
if(NOT CMAKE_SYSTEM_NAME STREQUAL "iOS")
  return()
endif()
find_package(Python3 REQUIRED COMPONENTS Interpreter)
execute_process(
  COMMAND "${Python3_EXECUTABLE}"
    "${CMAKE_CURRENT_LIST_DIR}/../scripts/patch-sdl2-scenes.py"
    "${CMAKE_CURRENT_SOURCE_DIR}"
  RESULT_VARIABLE scene_patch_result)
if(NOT scene_patch_result EQUAL 0)
  message(FATAL_ERROR "SDL2 scene startup backport failed; see the message above")
endif()
