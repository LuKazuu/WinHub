#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
TERMUX_PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"

WINHUB_RAW="https://raw.githubusercontent.com/LuKazuu/WinHub/main"
HANGOVER_TAG="hangover-wine-11.9-r25"
HANGOVER_BASE="https://github.com/LuKazuu/TermuxHangoverWine/releases/download/${HANGOVER_TAG}"

termux-setup-storage

pkg update -y && pkg upgrade -y
pkg install -y x11-repo tur-repo
pkg update -y
pkg install -y termux-x11-nightly xorg-xrandr pulseaudio xfce4 xfce4-terminal vlc-qt \
    curl zstd tar unzip mesa mesa-vulkan-icd-freedreno vulkan-loader-generic libandroid-shmem \
    libc++ libdrm libx11 libxcb libxshmfence libwayland vulkan-tools

WRAPPER_ARCHIVE="$(mktemp)"
curl -fL --retry 3 --retry-all-errors -o "${WRAPPER_ARCHIVE}" "${WINHUB_RAW}/wrapper/pipetto/wrapper.tzst"
zstd -dc "${WRAPPER_ARCHIVE}" | tar -x -C "${TERMUX_PREFIX}" --strip-components=1
rm -f "${WRAPPER_ARCHIVE}"

BCN_ARCHIVE="$(mktemp)"
BCN_TMPDIR="$(mktemp -d)"
curl -fL --retry 3 --retry-all-errors -o "${BCN_ARCHIVE}" "${WINHUB_RAW}/wrapper/pipetto/extra_libs.tzst"
zstd -dc "${BCN_ARCHIVE}" | tar -x -C "${BCN_TMPDIR}" \
    usr/lib/libbcn_layer.so \
    usr/share/vulkan/implicit_layer.d/libbcn_layer.json
mkdir -p "${TERMUX_PREFIX}/share/vulkan/implicit_layer.d"
cp -f "${BCN_TMPDIR}/usr/lib/libbcn_layer.so" "${TERMUX_PREFIX}/lib/"
cp -f "${BCN_TMPDIR}/usr/share/vulkan/implicit_layer.d/libbcn_layer.json" \
    "${TERMUX_PREFIX}/share/vulkan/implicit_layer.d/"
rm -rf "${BCN_TMPDIR}" "${BCN_ARCHIVE}"

ln -sfn "libandroid-shmem.so" "${TERMUX_PREFIX}/lib/libandroid-sysvshm.so"

HANGOVER_DEBS=(
    "hangover-wine_11.9_aarch64.deb"
    "hangover-libarm64ecfex_11.9_aarch64.deb"
    "hangover-wowbox64_11.9_aarch64.deb"
    "hangover-libwow64fex_11.9_aarch64.deb"
)
for deb in "${HANGOVER_DEBS[@]}"; do
    curl -fLO --retry 3 --retry-all-errors "${HANGOVER_BASE}/${deb}"
done
apt install -y "${HANGOVER_DEBS[@]/#/./}"
rm -f "${HANGOVER_DEBS[@]}"

for f in "${TERMUX_PREFIX}/opt/hangover-wine/bin/"*; do
    [ -e "$f" ] || continue
    ln -sf "$f" "${TERMUX_PREFIX}/bin/${f##*/}"
done

if [ ! -e "${TERMUX_PREFIX}/bin/wine.real" ]; then
    mv "${TERMUX_PREFIX}/bin/wine" "${TERMUX_PREFIX}/bin/wine.real"
fi

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
#!/${TERMUX_PREFIX}/bin/bash

TERMUX_PREFIX="${TERMUX_PREFIX}"
WINE_DIR="\${TERMUX_PREFIX}/opt/hangover-wine/lib/wine/aarch64-windows"
SHARED_DIR=~/storage/shared/Termux
LAYERS_DIR="\${SHARED_DIR}/layers"
WINEPREFIX=~/.wine
LOG_DIR="\${SHARED_DIR}/logs"

mkdir -p "\${LOG_DIR}"
rm -f "\${LOG_DIR}/"*.log
export WINE_LOGFILE="\${LOG_DIR}/wine.log"
DESKTOP_LOGFILE="\${LOG_DIR}/desktop.log"
: > "\${WINE_LOGFILE}"
: > "\${DESKTOP_LOGFILE}"

WRAPPER_CACHE_DIR="\${TERMUX_PREFIX}/var/cache/vulkan-wrapper"
TURNIP_SHARED_DIR="\${SHARED_DIR}/turnip"
TURNIP_RUNTIME_DIR="\${TERMUX_PREFIX}/var/lib/pipetto-turnip"
mkdir -p "\${LAYERS_DIR}" "\${WRAPPER_CACHE_DIR}" "\${TURNIP_SHARED_DIR}" "\${TURNIP_RUNTIME_DIR}"
mkdir -p "\${SHARED_DIR}/dxvk/system32" "\${SHARED_DIR}/dxvk/syswow64"
mkdir -p "\${SHARED_DIR}/vkd3d/system32" "\${SHARED_DIR}/vkd3d/syswow64"

if [ ! -f "\${SHARED_DIR}/desktop.txt" ]; then
    cat > "\${SHARED_DIR}/desktop.txt" << 'INNER_EOF'
WINEDEBUG=-all
HODLL=libwow64fex.dll
LC_ALL=en_US.UTF-8
WINEESYNC=1
WINE_VMR7_GDI_FALLBACK=1
WINE_DO_NOT_CREATE_DXGI_DEVICE_MANAGER=1
WINEVMEMMAXSIZE=2048
GPU_BACKEND=wrapper
WRAPPER_DRIVER=system
WRAPPER_BCN=0
TURNIP_PACKAGE=none
OPENGL_DRIVER=llvmpipe
MESA_NO_ERROR=1
MESA_GL_VERSION_OVERRIDE=4.6
MESA_GLES_VERSION_OVERRIDE=3.2
MESA_VK_WSI_PRESENT_MODE=mailbox
ZINK_DESCRIPTORS=lazy
ZINK_DEBUG=compact
GALLIUM_THREAD=1
GALLIUM_HUD=simple,fps
DXVK_HUD=fps
XDG_DATA_DIRS=${TERMUX_PREFIX}/share:${XDG_DATA_DIRS:-}
XDG_CONFIG_DIRS=${TERMUX_PREFIX}/etc/xdg:${XDG_CONFIG_DIRS:-}
WRAPPER_VK_VERSION=1.3
WRAPPER_EXTENSION_BLACKLIST=none
WRAPPER_VMEM_MAX_SIZE=2048
WRAPPER_RESOURCE_TYPE=auto
WRAPPER_USE_BCN_CACHE=0
INNER_EOF
fi

if [ ! -f "\${SHARED_DIR}/box64.txt" ]; then
    cat > "\${SHARED_DIR}/box64.txt" << 'INNER_EOF'
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
FEX_SMC_CHECKS=mtrack
FEX_VOLATILEMETADATA=1
FEX_MONOHACKS=1
FEX_HIDEHYPERVISORBIT=0
FEX_DISABLEL2CACHE=0
FEX_DYNAMICL1CACHE=0
INNER_EOF
fi

if ! ls "\${LAYERS_DIR}/"*.dll > /dev/null 2>&1; then
    cp "\${WINE_DIR}/libarm64ecfex.dll" "\${WINE_DIR}/wowbox64.dll" "\${WINE_DIR}/libwow64fex.dll" "\${LAYERS_DIR}/" > /dev/null 2>&1
fi

set -a
source "\${SHARED_DIR}/desktop.txt"
source "\${SHARED_DIR}/box64.txt"
source "\${SHARED_DIR}/fexcore.txt"
set +a

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
        unset MESA_LOADER_DRIVER_OVERRIDE
        export GALLIUM_DRIVER=llvmpipe
        export LIBGL_ALWAYS_SOFTWARE=true
        ;;
esac

case "\${GPU_BACKEND}" in
    termux)
        export VK_ICD_FILENAMES="\${TERMUX_PREFIX}/share/vulkan/icd.d/freedreno_icd.aarch64.json"
        unset VK_LAYER_PATH WRAPPER_LAYER_PATH WRAPPER_CACHE_PATH WRAPPER_EMULATE_BCN ENABLE_BCN_COMPUTE BCN_COMPUTE_AUTO USE_CPU_BCN
        unset ADRENOTOOLS_DRIVER_PATH ADRENOTOOLS_DRIVER_NAME ADRENOTOOLS_HOOKS_PATH ADRENOTOOLS_REDIRECT_DIR
        ;;
    wrapper)
        export VK_ICD_FILENAMES="\${TERMUX_PREFIX}/share/vulkan/icd.d/wrapper_icd.aarch64.json"
        export VK_LAYER_PATH="\${TERMUX_PREFIX}/share/vulkan/implicit_layer.d:\${TERMUX_PREFIX}/share/vulkan/explicit_layer.d"
        export WRAPPER_LAYER_PATH="\${TERMUX_PREFIX}/lib"
        export WRAPPER_CACHE_PATH="\${TERMUX_PREFIX}/var/cache/vulkan-wrapper"
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
                TURNIP_SOURCE="\${TURNIP_SHARED_DIR}/\${TURNIP_PACKAGE}"
                TURNIP_ACTIVE_DIR="\${TURNIP_RUNTIME_DIR}/active"
                if [ ! -f "\${TURNIP_ACTIVE_DIR}/meta.json" ] || [ "\${TURNIP_SOURCE}" -nt "\${TURNIP_ACTIVE_DIR}/meta.json" ]; then
                    rm -rf "\${TURNIP_ACTIVE_DIR}"
                    mkdir -p "\${TURNIP_ACTIVE_DIR}"
                    unzip -q "\${TURNIP_SOURCE}" -d "\${TURNIP_ACTIVE_DIR}"
                fi
                TURNIP_LIBRARY="\$(sed -n 's/.*"libraryName"[[:space:]]*:[[:space:]]*"\([^"\]*\)".*/\1/p' "\${TURNIP_ACTIVE_DIR}/meta.json" | head -n 1)"
                export ADRENOTOOLS_DRIVER_PATH="\${TURNIP_ACTIVE_DIR}/"
                export ADRENOTOOLS_DRIVER_NAME="\${TURNIP_LIBRARY}"
                export ADRENOTOOLS_HOOKS_PATH="\${TERMUX_PREFIX}/lib"
                ;;
        esac
        ;;
esac

cp -f "\${LAYERS_DIR}/"*.dll "\${WINE_DIR}/" > /dev/null 2>&1

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
    wine wineboot -u > /dev/null 2>&1
    wineserver -w
fi

HAS_CUSTOM_DX=0
if ls "\${SHARED_DIR}/dxvk/"*/*.dll > /dev/null 2>&1 || ls "\${SHARED_DIR}/vkd3d/"*/*.dll > /dev/null 2>&1; then
    HAS_CUSTOM_DX=1
fi

if [ "\$HAS_CUSTOM_DX" -eq 0 ]; then
    for dll in d3d8 d3d9 d3d10core d3d11 dxgi d3d12 d3d12core; do
        wine reg delete "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v "\$dll" /f > /dev/null 2>&1
    done
else
    for arch in "system32" "syswow64"; do
        for fw in "dxvk" "vkd3d"; do
            if [ -d "\${SHARED_DIR}/\${fw}/\${arch}" ]; then
                for dll_path in "\${SHARED_DIR}/\${fw}/\${arch}/"*.dll; do
                    if [ -f "\$dll_path" ]; then
                        dll_name=\$(basename "\$dll_path")
                        cp -f "\$dll_path" "\${WINEPREFIX}/drive_c/windows/\${arch}/" > /dev/null 2>&1
                        wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v "\${dll_name%.*}" /t REG_SZ /d "native,builtin" /f > /dev/null 2>&1
                    fi
                done
            fi
        done
    done
fi
wineserver -w

exec startxfce4 >> "\${DESKTOP_LOGFILE}" 2>&1
EOF
chmod +x "${TERMUX_PREFIX}/bin/startx11"

mkdir -p ~/Desktop ~/.local/share/applications ~/.config

cat > ~/.local/share/applications/wine.desktop << EOF
[Desktop Entry]
Type=Application
Name=Wine
Exec=wine start /Unix %f
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
echo "Type This Command to Start XFCE4 Desktop and Wine:"
echo "startx11"
