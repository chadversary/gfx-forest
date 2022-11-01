hh_pkg_deps=(
    robin-hood-hashing
    spirv-headers
    spirv-tools
    vulkan-headers
)

hh_pkg_cmake_args=(
    "-DVulkanRegistry_DIR=`hh_profile_prefix_dir`/share/vulkan/registry"
)
