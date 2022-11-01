hh_pkg_deps=(
    spirv-headers
)

hh_pkg_cmake_args=(
    # FIXME: Query the pkg for its src dir
    "-DSPIRV-Headers_SOURCE_DIR=$hh_top/src/spirv-headers"
)
