# TODO: Rewrite this garbage in a better language

set -eu

: "${HH_DEBUG:=}"

hh_bin_dir="${${(%):-%x}:A:h}"
hh_top="${hh_bin_dir:A:h}"
hh_config_dir="$hh_top/config"

hh_profile_name() { echo "cheddar"; }
hh_profile_out_dir() { echo "$hh_top/out/`hh_profile_name`"; }
hh_profile_prefix_dir() { echo "$hh_top/out/`hh_profile_name`/prefix"; }
hh_profile_pkg_dir() { echo "$hh_top/out/`hh_profile_name`/pkg"; }

# TODO: Let pkgs choose to configure these as either funcs or vars.
# TODO: Let pkgs configure these as relative paths.
# TODO: Prevent pkgs from configuring some vars.
hh_pkg_src_dir() { echo "$hh_top/src/$hh_pkg_name"; }
hh_pkg_out_dir() { echo "`hh_profile_pkg_dir`/$hh_pkg_name"; }
hh_pkg_build_dir() { echo "`hh_pkg_out_dir`/build"; }
hh_pkg_install_prefix_dir() { echo "`hh_profile_prefix_dir`"; }
hh_pkg_install_lib_dir() { echo "`hh_profile_prefix_dir`/lib"; }
hh_pkg_deps=()
hh_pkg_cmake_args=()
hh_pkg_meson_args=()

hh_die_pkg() {
    echo >&2 "error: pkg $hh_pkg_name: $*"
    exit 1
}

hh_debug_pkg() {
    echo >&2 "debug: pkg $hh_pkg_name: $*"
}

hh_get_pkg_stamp() {
    echo "`hh_pkg_out_dir`/stamp.${1}"
}

hh_touch_pkg_stamp() {
    mkdir -p "`hh_pkg_out_dir`"
    touch "`hh_get_pkg_stamp "$1"`"
}


hh_req_pkg_stamp() {
    local stage="$1"
    local stamp; stamp="`hh_get_pkg_stamp "$stage"`"

    if [[ ! -e "$stamp" ]] || [[ "$hh_pkg_file" -nt "$stamp" ]]; then
        "hh_wrap_pkg_${stage}"
    fi
}

hh_wrap_pkg_deps() {
    # TODO: Hit each pkg exactly once.
    # FIXME: Rerun if pkg file changes.
    local dep
    for dep in "${hh_pkg_deps[@]}"; do
        "$hh_bin_dir/hh-pkg" "$dep" install
    done

    hh_touch_pkg_stamp deps
}

hh_wrap_pkg_configure() {
    hh_req_pkg_stamp deps
    hh_pkg_configure
    hh_touch_pkg_stamp configure
}

hh_wrap_pkg_make() {
    hh_req_pkg_stamp configure
    hh_pkg_make "$@"
}

hh_wrap_pkg_build() {
    hh_req_pkg_stamp configure
    hh_pkg_build
    hh_touch_pkg_stamp build
}

hh_wrap_pkg_install() {
    hh_req_pkg_stamp build
    hh_pkg_install
    hh_touch_pkg_stamp install
}

hh_pkg_build_system() {
    hh_default_pkg_build_system
}

hh_pkg_configure() {
    hh_default_pkg_configure
}

hh_pkg_make() {
    hh_default_pkg_make "$@"
}

hh_pkg_build() {
    hh_default_pkg_build
}

hh_pkg_install() {
    hh_default_pkg_install
}

hh_default_pkg_build_system() {
    local name=
    local n=0

    if [[ -f "`hh_pkg_src_dir`/meson.build" ]]; then
        name='meson'
        ((n+=1))
    fi

    if [[ -f "`hh_pkg_src_dir`/CMakeLists.txt" ]]; then
        name='cmake'
        ((n+=1))
    fi

    case "$n" in
        0) hh_die_pkg "failed to find a build system";;
        1) echo "$name";;
        *) hh_die_pkg "found multiple build systems";;
    esac
}

hh_default_pkg_configure() {
    local sys; sys="`hh_pkg_build_system`"

    case "$sys" in
        meson) hh_meson_configure;;
        cmake) hh_cmake_configure;;
        *) hh_die_pkg "no default rules to configure build system '$sys'";;
    esac
}

hh_default_pkg_make() {
    if [[ -f "`hh_pkg_build_dir`/build.ninja" ]]; then
        ninja -C "`hh_pkg_build_dir`" "$@"
    else
        hh_die_pkg "failed to detect build system"
    fi
}

hh_default_pkg_build() {
    hh_pkg_make
}

hh_default_pkg_install() {
    hh_pkg_make install
}

hh_meson_configure() {
    local meson_args=(setup)

    if [[ -f "`hh_get_pkg_stamp configure`" ]]; then
        meson_args+=(--reconfigure)
    fi

    meson_args+=(
        "-Dprefix=`hh_profile_prefix_dir`"
        "-Dlibdir=`hh_pkg_install_lib_dir`"

        "${hh_pkg_meson_args[@]}"

        "`hh_pkg_build_dir`"
        "`hh_pkg_src_dir`"
    )

    meson "${meson_args[@]}"
}

hh_cmake_configure() {
    local cmake_args=(
        -GNinja

        "-H`hh_pkg_src_dir`"
        "-B`hh_pkg_build_dir`"

        "-DCMAKE_PREFIX_PATH=`hh_profile_prefix_dir`"

        "-DCMAKE_INSTALL_PREFIX=`hh_pkg_install_prefix_dir`"
        "-DCMAKE_INSTALL_LIBDIR=`hh_pkg_install_lib_dir`"

        "${hh_pkg_cmake_args[@]}"
    )

    cmake "${cmake_args[@]}"
}

hh_scrub_pkg() {
    if [[ "`hh_pkg_out_dir`" != "`hh_profile_pkg_dir`/$hh_pkg_name" ]]; then
        hh_die_pkg "hh_pkg_build_dir is invalid"
    fi

    rm -rf "`hh_pkg_out_dir`"
}

hh_help_pkg() {
    echo "usage: hh-pkg <pkg-name> [<cmd>...]"
}

hh_cmd_pkg() {
    if [[ $# -eq 0 ]]; then
        hh_help_pkg
        exit 1
    fi

    local hh_pkg_name="$1"
    shift

    if [[ "$#" -eq 0 ]]; then
        hh_help_pkg
        exit 1
    fi

    local hh_pkg_file="$hh_config_dir/pkg/$hh_pkg_name.zsh"

    (
        if ! [[ -f "$hh_pkg_file" ]]; then
            hh_die_pkg "cannot find pkg file"
        fi

        if ! source "$hh_pkg_file"; then
            hh_die_pkg "errors in pkg file: $hh_pkg_file"
        fi

        local cmd="$1"
        shift

        case "$cmd" in
            deps) hh_wrap_pkg_deps;;
            configure) hh_wrap_pkg_configure;;
            build) hh_wrap_pkg_build;;
            install) hh_wrap_pkg_install;;
            scrub) hh_scrub_pkg;;
            make) hh_wrap_pkg_make "$@" ;;

            *)
                hh_die_pkg "not a pkg cmd: $cmd"
                ;;
        esac
    )
}
