cmake_minimum_required(VERSION 3.19)
project(c-vt-cmake LANGUAGES C)

include(FetchContent)
FetchContent_Declare(spectrepro
    GIT_REPOSITORY https://github.com/spectrepro-org/spectrepro.git
    GIT_TAG main
)
FetchContent_MakeAvailable(spectrepro)

add_executable(c_vt_cmake src/main.c)
target_link_libraries(c_vt_cmake PRIVATE spectrepro-vt)
