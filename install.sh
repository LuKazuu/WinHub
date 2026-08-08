#!/data/data/com.termux/files/usr/bin/bash
#REVISION4
set -euo pipefail
TERMUX_PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"

WINHUB_RAW="https://raw.githubusercontent.com/LuKazuu/WinHub/main"
HANGOVER_TAG="hangover-wine-11.14-r10"
HANGOVER_BASE="https://github.com/LuKazuu/WinHubWine/releases/download/${HANGOVER_TAG}"

termux-setup-storage

WORKDIR="$(mktemp -d)"
cleanup() {
    rm -rf "${WORKDIR}" 2>/dev/null || true
    pkg clean 2>/dev/null || true
}
trap cleanup EXIT

pkg install -y x11-repo
pkg update -y && pkg upgrade -y
pkg install -y termux-x11-nightly xorg-xrandr pulseaudio xfce4 xfce4-terminal zstd tar vulkan-loader-generic mesa mesa-vulkan-icd-freedreno

TURNIP_WRAPPER_DEFAULT_DIR="${TERMUX_PREFIX}/var/lib/turnip-wrapper"

WRAPPER_ARCHIVE="${WORKDIR}/wrapper.tzst"
curl -fL --retry 3 --retry-all-errors -o "${WRAPPER_ARCHIVE}" "${WINHUB_RAW}/wrapper/pipetto/wrapper.tzst"
zstd -dc "${WRAPPER_ARCHIVE}" | tar -x -C "${TERMUX_PREFIX}" --strip-components=1

EXTRA_LIBS_ARCHIVE="${WORKDIR}/extra_libs.tzst"
EXTRA_LIBS_TMPDIR="${WORKDIR}/extra_libs"
mkdir -p "${EXTRA_LIBS_TMPDIR}" "${TURNIP_WRAPPER_DEFAULT_DIR}" "${TERMUX_PREFIX}/share/vulkan/implicit_layer.d"
curl -fL --retry 3 --retry-all-errors -o "${EXTRA_LIBS_ARCHIVE}" "${WINHUB_RAW}/wrapper/extra_libs.tzst"
zstd -dc "${EXTRA_LIBS_ARCHIVE}" | tar -x -C "${EXTRA_LIBS_TMPDIR}" \
    usr/lib/libbcn_layer.so \
    usr/lib/libvulkan_freedreno.so \
    usr/share/vulkan/implicit_layer.d/libbcn_layer.json
cp -f "${EXTRA_LIBS_TMPDIR}/usr/lib/libbcn_layer.so" "${TERMUX_PREFIX}/lib/"
cp -f "${EXTRA_LIBS_TMPDIR}/usr/lib/libvulkan_freedreno.so" "${TURNIP_WRAPPER_DEFAULT_DIR}/libvulkan_freedreno.so"
cp -f "${EXTRA_LIBS_TMPDIR}/usr/share/vulkan/implicit_layer.d/libbcn_layer.json" "${TERMUX_PREFIX}/share/vulkan/implicit_layer.d/"

ln -sfn "libandroid-shmem.so" "${TERMUX_PREFIX}/lib/libandroid-sysvshm.so"

HANGOVER_DEBS=(
    "hangover-wine_11.14_aarch64.deb"
    "hangover-libarm64ecfex_11.14_aarch64.deb"
    "hangover-wowbox64_11.14_aarch64.deb"
    "hangover-libwow64fex_11.14_aarch64.deb"
)
for deb in "${HANGOVER_DEBS[@]}"; do
    curl -fL --retry 3 --retry-all-errors -o "${WORKDIR}/${deb}" "${HANGOVER_BASE}/${deb}"
done
apt install -y --allow-downgrades "${HANGOVER_DEBS[@]/#/${WORKDIR}/}"

LAYERS_DEFAULT_DIR="${TERMUX_PREFIX}/var/lib/layers-default"
WINE_DIR="${TERMUX_PREFIX}/opt/hangover-wine/lib/wine/aarch64-windows"
mkdir -p "${LAYERS_DEFAULT_DIR}"
cp -f "${WINE_DIR}/libarm64ecfex.dll" "${WINE_DIR}/wowbox64.dll" "${WINE_DIR}/libwow64fex.dll" "${LAYERS_DEFAULT_DIR}/"

for f in "${TERMUX_PREFIX}/opt/hangover-wine/bin/"*; do
    [ -e "$f" ] || continue
    [ "${f##*/}" = "wine" ] && continue
    ln -sf "$f" "${TERMUX_PREFIX}/bin/${f##*/}"
done
ln -sf "${TERMUX_PREFIX}/opt/hangover-wine/bin/wine" "${TERMUX_PREFIX}/bin/wine.real"

cat > "${TERMUX_PREFIX}/bin/wine" << 'WEOF'
#!/data/data/com.termux/files/usr/bin/bash
if [ -n "${WINE_LOGFILE:-}" ]; then
    mkdir -p "$(dirname "$WINE_LOGFILE")"
    exec wine.real "$@" >> "$WINE_LOGFILE" 2>&1
fi
exec wine.real "$@"
WEOF
chmod +x "${TERMUX_PREFIX}/bin/wine"

cat > "${TERMUX_PREFIX}/bin/startx11" << EOF
#!${TERMUX_PREFIX}/bin/bash

TERMUX_PREFIX="${TERMUX_PREFIX}"
WINE_DIR="\${TERMUX_PREFIX}/opt/hangover-wine/lib/wine/aarch64-windows"
WINE_DIR_32="\${TERMUX_PREFIX}/opt/hangover-wine/lib/wine/i386-windows"
SHARED_DIR=~/storage/shared/Termux
LAYERS_DIR="\${SHARED_DIR}/layers"
WINEPREFIX=~/.wine
LOG_DIR="\${SHARED_DIR}/logs"

mkdir -p "\${LOG_DIR}"
rm -f "\${LOG_DIR}/"*.log
export WINE_LOGFILE="\${LOG_DIR}/wine.log"
DESKTOP_LOGFILE="\${LOG_DIR}/desktop.log"

WRAPPER_CACHE_DIR="\${TERMUX_PREFIX}/var/cache/vulkan-wrapper"
TURNIP_WRAPPER_DIR="\${SHARED_DIR}/turnip/wrapper"
TURNIP_TERMUX_DIR="\${SHARED_DIR}/turnip/termux"
TURNIP_WRAPPER_DEFAULT_DIR="\${TERMUX_PREFIX}/var/lib/turnip-wrapper"
TURNIP_WRAPPER_DEFAULT="\${TURNIP_WRAPPER_DEFAULT_DIR}/libvulkan_freedreno.so"
LAYERS_DEFAULT_DIR="\${TERMUX_PREFIX}/var/lib/layers-default"
DLLS_DIR="\${SHARED_DIR}/dlls"
MANIFEST_DIR="\${TERMUX_PREFIX}/var/lib/dll-manifest"
mkdir -p "\${LAYERS_DIR}" "\${WRAPPER_CACHE_DIR}" "\${TURNIP_WRAPPER_DIR}" "\${TURNIP_TERMUX_DIR}"
mkdir -p "\${DLLS_DIR}/system32" "\${DLLS_DIR}/syswow64"
mkdir -p "\${MANIFEST_DIR}"

if [ ! -f "\${SHARED_DIR}/desktop.txt" ]; then
    cat > "\${SHARED_DIR}/desktop.txt" << 'INNER_EOF'
# BASIC
WINEDEBUG=-all
HODLL=libwow64fex.dll
# libwow64fex.dll / wowbox64.dll
LC_ALL=en_US.UTF-8
WINEESYNC=1
WINE_VMR7_GDI_FALLBACK=1
WINE_DO_NOT_CREATE_DXGI_DEVICE_MANAGER=1
WINEVMEMMAXSIZE=4096
PULSE_LATENCY_MSEC=60
TZ=Asia/Tokyo
WINESERVICES=1
# 0 / 1
CPU_TASKSET=all
# all / 0-3 / 4-7

# GPU
GPU_BACKEND=wrapper
# wrapper / termux
WRAPPER_DRIVER=system
# system / turnip
OPENGL_DRIVER=llvmpipe
# zink / llvmpipe
WRAPPER_BCN=0
# 0 / 1 / 2
MESA_NO_ERROR=1
MESA_GL_VERSION_OVERRIDE=4.6
MESA_GLES_VERSION_OVERRIDE=3.2
MESA_VK_WSI_PRESENT_MODE=mailbox
ZINK_DESCRIPTORS=lazy
ZINK_DEBUG=compact
GALLIUM_THREAD=1
WRAPPER_VK_VERSION=1.4
WRAPPER_EXTENSION_BLACKLIST=none
WRAPPER_VMEM_MAX_SIZE=4096
WRAPPER_RESOURCE_TYPE=auto
WRAPPER_USE_BCN_CACHE=0

# HUD
GALLIUM_HUD=simple,fps
DXVK_HUD=fps
INNER_EOF
fi

if [ ! -f "\${SHARED_DIR}/box64.txt" ]; then
    cat > "\${SHARED_DIR}/box64.txt" << 'INNER_EOF'
BOX64_DYNAREC=1
BOX64_DYNAREC_SAFEFLAGS=1
BOX64_DYNAREC_FASTNAN=1
BOX64_DYNAREC_FASTROUND=1
BOX64_DYNAREC_X87DOUBLE=0
BOX64_DYNAREC_BIGBLOCK=3
BOX64_DYNAREC_STRONGMEM=0
BOX64_DYNAREC_FORWARD=512
BOX64_DYNAREC_CALLRET=1
BOX64_DYNAREC_WAIT=1
BOX64_AVX=0
BOX64_MAXCPU=0
BOX64_UNITYPLAYER=0
BOX64_DYNAREC_WEAKBARRIER=0
BOX64_DYNAREC_ALIGNED_ATOMICS=0
BOX64_DYNAREC_DF=1
BOX64_DYNAREC_DIRTY=0
BOX64_DYNAREC_NATIVEFLAGS=1
BOX64_DYNAREC_PAUSE=0
BOX64_MMAP32=1
INNER_EOF
fi

if [ ! -f "\${SHARED_DIR}/fexcore.txt" ]; then
    cat > "\${SHARED_DIR}/fexcore.txt" << 'INNER_EOF'
FEX_TSOENABLED=0
FEX_VECTORTSOENABLED=0
FEX_HALFBARRIERTSOENABLED=0
FEX_MEMCPYSETTSOENABLED=0
FEX_X87REDUCEDPRECISION=1
FEX_MULTIBLOCK=1
FEX_MAXINST=5000
FEX_HOSTFEATURES=off
FEX_SMALLTSCSCALE=1
FEX_SMCCHECKS=mtrack
FEX_VOLATILEMETADATA=1
FEX_MONOHACKS=1
FEX_HIDEHYPERVISORBIT=0
FEX_DISABLEL2CACHE=0
FEX_DYNAMICL1CACHE=0
INNER_EOF
fi

if [ ! -f "\${SHARED_DIR}/override_dll.txt" ]; then
    cat > "\${SHARED_DIR}/override_dll.txt" << 'INNER_EOF'
version=n,b
INNER_EOF
fi

set -a
source "\${SHARED_DIR}/desktop.txt"
source "\${SHARED_DIR}/box64.txt"
source "\${SHARED_DIR}/fexcore.txt"
set +a

export XDG_DATA_DIRS="\${TERMUX_PREFIX}/share:\${XDG_DATA_DIRS:-}"
export XDG_CONFIG_DIRS="\${TERMUX_PREFIX}/etc/xdg:\${XDG_CONFIG_DIRS:-}"

for var in WRAPPER_VK_VERSION WRAPPER_EXTENSION_BLACKLIST WRAPPER_VMEM_MAX_SIZE WRAPPER_RESOURCE_TYPE; do
    [ -n "\${!var}" ] || unset "\$var"
done

case "\${OPENGL_DRIVER}" in
    zink)
        export MESA_LOADER_DRIVER_OVERRIDE=zink
        export GALLIUM_DRIVER=zink
        unset LIBGL_ALWAYS_SOFTWARE
        ;;
    llvmpipe)
        export MESA_LOADER_DRIVER_OVERRIDE=swrast
        export GALLIUM_DRIVER=llvmpipe
        export LIBGL_ALWAYS_SOFTWARE=true
        ;;
esac

case "\${GPU_BACKEND}" in
    termux)
        export VK_ICD_FILENAMES="\${TERMUX_PREFIX}/share/vulkan/icd.d/freedreno_icd.aarch64.json"
        unset VK_LAYER_PATH WRAPPER_LAYER_PATH WRAPPER_CACHE_PATH WRAPPER_EMULATE_BCN ENABLE_BCN_COMPUTE BCN_COMPUTE_AUTO USE_CPU_BCN
        unset ADRENOTOOLS_DRIVER_PATH ADRENOTOOLS_DRIVER_NAME ADRENOTOOLS_HOOKS_PATH ADRENOTOOLS_REDIRECT_DIR
        TURNIP_TERMUX_DEFAULT="\${TERMUX_PREFIX}/var/lib/turnip-termux/libvulkan_freedreno.so"
        TURNIP_SOURCE_TERMUX="\$(ls "\${TURNIP_TERMUX_DIR}/"*.so 2>/dev/null | head -n 1 || true)"
        if [ -n "\${TURNIP_SOURCE_TERMUX}" ]; then
            if [ ! -f "\${TURNIP_TERMUX_DEFAULT}" ]; then
                mkdir -p "\$(dirname "\${TURNIP_TERMUX_DEFAULT}")"
                cp -f "\${TERMUX_PREFIX}/lib/libvulkan_freedreno.so" "\${TURNIP_TERMUX_DEFAULT}"
            fi
            cp -f "\${TURNIP_SOURCE_TERMUX}" "\${TERMUX_PREFIX}/lib/libvulkan_freedreno.so"
        elif [ -f "\${TURNIP_TERMUX_DEFAULT}" ]; then
            cp -f "\${TURNIP_TERMUX_DEFAULT}" "\${TERMUX_PREFIX}/lib/libvulkan_freedreno.so"
        fi
        ;;
    wrapper)
        export VK_ICD_FILENAMES="\${TERMUX_PREFIX}/share/vulkan/icd.d/wrapper_icd.aarch64.json"
        export VK_LAYER_PATH="\${TERMUX_PREFIX}/share/vulkan/implicit_layer.d:\${TERMUX_PREFIX}/share/vulkan/explicit_layer.d"
        export WRAPPER_LAYER_PATH="\${TERMUX_PREFIX}/lib"
        export WRAPPER_CACHE_PATH="\${WRAPPER_CACHE_DIR}"
        case "\${WRAPPER_BCN}" in
            0)
                unset WRAPPER_EMULATE_BCN ENABLE_BCN_COMPUTE BCN_COMPUTE_AUTO USE_CPU_BCN
                ;;
            1)
                export WRAPPER_EMULATE_BCN=3
                export ENABLE_BCN_COMPUTE=1
                export BCN_COMPUTE_AUTO=1
                unset USE_CPU_BCN
                ;;
            2)
                export WRAPPER_EMULATE_BCN=3
                unset ENABLE_BCN_COMPUTE BCN_COMPUTE_AUTO
                export USE_CPU_BCN=all
                ;;
        esac
        case "\${WRAPPER_DRIVER}" in
            system)
                unset ADRENOTOOLS_DRIVER_PATH ADRENOTOOLS_DRIVER_NAME ADRENOTOOLS_HOOKS_PATH ADRENOTOOLS_REDIRECT_DIR
                ;;
            turnip)
                TURNIP_SOURCE_WRAPPER="\$(ls "\${TURNIP_WRAPPER_DIR}/"*.so 2>/dev/null | head -n 1 || true)"
                if [ -n "\${TURNIP_SOURCE_WRAPPER}" ]; then
                    TURNIP_WRAPPER_INTERNAL_DIR="\${TURNIP_WRAPPER_DEFAULT_DIR}/custom"
                    mkdir -p "\${TURNIP_WRAPPER_INTERNAL_DIR}"
                    find "\${TURNIP_WRAPPER_INTERNAL_DIR}" -maxdepth 1 -type f -name '*.so' -delete
                    TURNIP_INTERNAL_COPY="\${TURNIP_WRAPPER_INTERNAL_DIR}/\$(basename "\${TURNIP_SOURCE_WRAPPER}")"
                    cp -f "\${TURNIP_SOURCE_WRAPPER}" "\${TURNIP_INTERNAL_COPY}"
                    TURNIP_SOURCE_WRAPPER="\${TURNIP_INTERNAL_COPY}"
                elif [ -f "\${TURNIP_WRAPPER_DEFAULT}" ]; then
                    TURNIP_SOURCE_WRAPPER="\${TURNIP_WRAPPER_DEFAULT}"
                fi
                if [ -n "\${TURNIP_SOURCE_WRAPPER}" ]; then
                    export ADRENOTOOLS_DRIVER_PATH="\$(dirname "\${TURNIP_SOURCE_WRAPPER}")/"
                    export ADRENOTOOLS_DRIVER_NAME="\$(basename "\${TURNIP_SOURCE_WRAPPER}")"
                    export ADRENOTOOLS_HOOKS_PATH="\${TERMUX_PREFIX}/lib"
                else
                    unset ADRENOTOOLS_DRIVER_PATH ADRENOTOOLS_DRIVER_NAME ADRENOTOOLS_HOOKS_PATH ADRENOTOOLS_REDIRECT_DIR
                fi
                ;;
        esac
        ;;
esac

if ls "\${LAYERS_DIR}/"*.dll > /dev/null 2>&1; then
    cp -f "\${LAYERS_DIR}/"*.dll "\${WINE_DIR}/" > /dev/null 2>&1
else
    cp -f "\${LAYERS_DEFAULT_DIR}/"*.dll "\${WINE_DIR}/" > /dev/null 2>&1
fi

pkill -9 -f "termux.x11" > /dev/null 2>&1
pkill -9 xfce4-session > /dev/null 2>&1
pkill -9 -f "dbus-daemon" > /dev/null 2>&1
sleep 0.5

unset PULSE_SERVER
pulseaudio --kill > /dev/null 2>&1
pulseaudio --start --exit-idle-time=-1 --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" > /dev/null 2>&1
sleep 1
export PULSE_SERVER=127.0.0.1

termux-x11 :0 -ac >> "\${DESKTOP_LOGFILE}" 2>&1 &
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity
sleep 2
export DISPLAY=:0

if [ ! -d "\${WINEPREFIX}/drive_c/windows/system32" ]; then
    wine wineboot -u
    wineserver -w
fi

declare -A DLL_OVERRIDES_MAP
declare -A DLL_USER_NAMES

if [ -f "\${SHARED_DIR}/override_dll.txt" ]; then
    while IFS='=' read -r name mode || [ -n "\$name" ]; do
        name="\${name%%#*}"
        name="\${name// /}"
        mode="\${mode// /}"
        [ -n "\$name" ] && [ -n "\$mode" ] && {
            DLL_OVERRIDES_MAP["\$mode"]+="\${name},"
            DLL_USER_NAMES["\$name"]=1
        }
    done < "\${SHARED_DIR}/override_dll.txt"
fi

sync_dll_arch() {
    local arch="\$1" source_dir="\$2" dll_path dll_name base_name target manifest prev
    declare -A found=()

    for dll_path in "\${DLLS_DIR}/\${arch}/"*.dll; do
        [ -f "\$dll_path" ] && found["\$(basename "\$dll_path")"]="\$dll_path"
    done

    manifest="\${MANIFEST_DIR}/\${arch}.list"
    prev=""
    [ -f "\$manifest" ] && prev="\$(cat "\$manifest")"

    for dll_name in "\${!found[@]}"; do
        base_name="\${dll_name%.*}"
        target="\${WINEPREFIX}/drive_c/windows/\${arch}/\${dll_name}"
        cp -f "\${found[\$dll_name]}" "\$target" 2>/dev/null
        [ -z "\${DLL_USER_NAMES[\$base_name]:-}" ] && DLL_OVERRIDES_MAP["n,b"]+="\${base_name},"
    done

    while IFS= read -r dll_name; do
        [ -n "\$dll_name" ] && [ -z "\${found[\$dll_name]:-}" ] || continue
        target="\${WINEPREFIX}/drive_c/windows/\${arch}/\${dll_name}"
        if [ -f "\${source_dir}/\${dll_name}" ]; then
            cp -f "\${source_dir}/\${dll_name}" "\$target" 2>/dev/null
        else
            rm -f "\$target" 2>/dev/null
        fi
    done <<< "\$prev"

    printf '%s\n' "\${!found[@]}" > "\$manifest"
}

sync_dll_arch system32 "\${WINE_DIR}"
sync_dll_arch syswow64 "\${WINE_DIR_32}"

WINEDLLOVERRIDES=""
for mode in "\${!DLL_OVERRIDES_MAP[@]}"; do
    names="\${DLL_OVERRIDES_MAP[\$mode]%,}"
    [ -z "\$names" ] && continue
    WINEDLLOVERRIDES+="\${names}=\${mode};"
done
export WINEDLLOVERRIDES="\${WINEDLLOVERRIDES%;}"

if [ "\${WINESERVICES:-0}" = "0" ]; then
    if [ -n "\${WINEDLLOVERRIDES}" ]; then
        export WINEDLLOVERRIDES="\${WINEDLLOVERRIDES};services.exe=d"
    else
        export WINEDLLOVERRIDES="services.exe=d"
    fi
    wineserver -k > /dev/null 2>&1 || true
fi

if [ "\${CPU_TASKSET:-all}" = "all" ]; then
    exec startxfce4 >> "\${DESKTOP_LOGFILE}" 2>&1
else
    exec taskset -c "\${CPU_TASKSET}" startxfce4 >> "\${DESKTOP_LOGFILE}" 2>&1
fi
EOF
chmod +x "${TERMUX_PREFIX}/bin/startx11"

cat > "${TERMUX_PREFIX}/bin/winlaunch" << 'WEOF'
#!/data/data/com.termux/files/usr/bin/bash
wine start /Unix "$1"
WEOF
chmod +x "${TERMUX_PREFIX}/bin/winlaunch"

mkdir -p ~/Desktop ~/.local/share/applications ~/.config

cat > ~/.local/share/applications/wine.desktop << EOF
[Desktop Entry]
Type=Application
Name=Wine
Exec=winlaunch %f
MimeType=application/x-ms-dos-executable;application/x-msi;application/x-bat;application/x-cmd;
NoDisplay=true
EOF

cat > ~/.config/mimeapps.list << EOF
[Default Applications]
application/x-ms-dos-executable=wine.desktop;
application/x-msi=wine.desktop;
application/x-bat=wine.desktop;
application/x-cmd=wine.desktop;
EOF

cat > ~/Desktop/winecfg.desktop << EOF
[Desktop Entry]
Type=Application
Name=Wine Config
Exec=wine winecfg
Icon=xfwm4-default
Categories=System;
EOF
chmod +x ~/Desktop/winecfg.desktop

cat > ~/Desktop/winetaskmgr.desktop << EOF
[Desktop Entry]
Type=Application
Name=Wine Task Manager
Exec=wine taskmgr
Icon=xfwm4-default
Categories=System;
EOF
chmod +x ~/Desktop/winetaskmgr.desktop

clear
echo "Type This Command to Start Desktop and Wine:"
echo "startx11"