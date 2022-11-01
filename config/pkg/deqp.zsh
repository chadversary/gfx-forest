hh_pkg_deps=()

hh_pkg_configure() {
    hh_pkg_cmake_args=(
        #"-DGLSLANG_SRC_PATH=$hh_top/src/glslang"
    )

    hh_default_pkg_configure
}

hh_pkg_build() {
    hh_pkg_make deqp-vk
}

hh_pkg_install() {
    : # Do not install. Just run deqp from its build dir.
}
