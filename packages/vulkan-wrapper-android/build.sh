PKG_VER=25.0.0
PKG_CATEGORY="VulkanDriver"
PKG_PRETTY_NAME="Mesa Android Wrapper"
VK_DRIVER_LIB="libvulkan_wrapper.so"

TERMUX_PKG_HOMEPAGE=https://www.mesa3d.org
TERMUX_PKG_DESCRIPTION="Android Vulkan ICD"
TERMUX_PKG_LICENSE="MIT"
TERMUX_PKG_LICENSE_FILE="docs/license.rst"
TERMUX_PKG_MAINTAINER="Pipetto-crypto <name@example.com>"
TERMUX_PKG_VERSION=${PKG_VER}
TERMUX_PKG_REVISION=1
TERMUX_PKG_SRCURL=git+https://gitlab.freedesktop.org/Pipetto-crypto/mesa
TERMUX_PKG_GIT_BRANCH=wrapper
_COMMIT=8c8e0079152a247dc37f1d81bb0162afcdba9e60
TERMUX_PKG_DEPENDS="libandroid-shmem, libc++, libdrm, libx11, libxcb, libxshmfence, libwayland, vulkan-loader-generic, zlib, zstd"
TERMUX_PKG_BUILD_DEPENDS="libwayland-protocols, libxrandr, xorgproto"
TERMUX_PKG_API_LEVEL=26

TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
--cmake-prefix-path $TERMUX_PREFIX
-Dcpp_rtti=false
-Dgbm=disabled
-Dopengl=false
-Degl=disabled
-Dllvm=disabled
-Dshared-llvm=disabled
-Dplatforms=x11,wayland
-Dgallium-drivers=
-Dglvnd=disabled
-Dzstd=enabled
-Dxmlconfig=disabled
-Dvulkan-drivers=wrapper
-Db_ndebug=true
-Dc_args="-Wno-error"
"

termux_step_post_get_source() {
	git fetch --unshallow || true
	git checkout $_COMMIT

	rm -rf subprojects
	mkdir -p subprojects

	cat <<EOF > subprojects/libadrenotools.wrap
[wrap-git]
directory = libadrenotools
url = https://github.com/Pipetto-crypto/libadrenotools.git
revision = master
depth = 1
recursive = true
EOF

	cd subprojects
	git clone --recurse-submodules https://github.com/Pipetto-crypto/libadrenotools.git
	cd "$TERMUX_PKG_SRCDIR"

	# 1. Șterge orice redefinire directă de native_handle_t
	find . \( -name '*.c' -o -name '*.h' \) \
		! -path '*/android_stub/cutils/native_handle.h' \
		-exec sed -i '/typedef struct native_handle/,/} native_handle_t;/d' {} +

	# 2. Include headerul oficial oriunde se folosește native_handle_t și nu e deja inclus
	find . \( -name '*.c' -o -name '*.h' \) \
		-exec grep -l 'native_handle_t' {} \; | while read -r f; do
		case "$f" in
			*android_stub/cutils/native_handle.h*) continue ;;
		esac
		if ! grep -q 'android_stub/cutils/native_handle.h' "$f"; then
			sed -i '1i #include <android_stub/cutils/native_handle.h>' "$f"
		fi
	done

	# 3. Debug: vezi dacă mai există definiții duble în afară de headerul oficial
	find . \( -name '*.c' -o -name '*.h' \) -exec grep -Hn 'native_handle_t' {} \; | grep -v 'android_stub/cutils/native_handle.h'
}


termux_step_pre_configure() {
	termux_setup_cmake

	CPPFLAGS+=" -D__USE_GNU"
	LDFLAGS+=" -landroid-shmem"

	_WRAPPER_BIN=$TERMUX_PKG_BUILDDIR/_wrapper/bin
	mkdir -p $_WRAPPER_BIN

	if [ "$TERMUX_ON_DEVICE_BUILD" = "false" ]; then
		sed 's|@CMAKE@|'"$(command -v cmake)"'|g' \
			$TERMUX_PKG_BUILDER_DIR/cmake-wrapper.in \
			> $_WRAPPER_BIN/cmake
		chmod 0700 $_WRAPPER_BIN/cmake
		termux_setup_wayland_cross_pkg_config_wrapper
	fi
	export PATH=$_WRAPPER_BIN:$PATH
}


termux_step_post_configure() {
	rm -f $_WRAPPER_BIN/cmake
}
