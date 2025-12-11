# the minimum version of CMake.
cmake_minimum_required(VERSION 3.4.1)
project(MyApplication)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})
# 关闭 strip 并保留调试符号
set(CMAKE_STRIP_OPTIONS "--strip-debug")  # 或完全禁用：set(CMAKE_STRIP_COMMAND "")

include_directories(${NATIVERENDER_ROOT_PATH}
                    ${NATIVERENDER_ROOT_PATH}/include)

add_library(entry SHARED napi_init.cpp GetSystemInfo.cpp)
target_link_libraries(entry PUBLIC libhilog_ndk.z.so libace_napi.z.so)