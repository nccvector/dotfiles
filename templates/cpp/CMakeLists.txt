cmake_minimum_required(VERSION 3.21)
project(demo LANGUAGES CXX)

# Also enabled when configuring without presets.
set(CMAKE_EXPORT_COMPILE_COMMANDS ON CACHE BOOL "Export compiler commands" FORCE)

add_executable(demo src/main.cpp)
target_compile_features(demo PRIVATE cxx_std_23)
set_target_properties(demo PROPERTIES CXX_EXTENSIONS OFF)
if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  target_compile_options(demo PRIVATE -Weverything)
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
  target_compile_options(demo PRIVATE -Wall -Wextra -Wpedantic -Wconversion -Wshadow)
endif()
