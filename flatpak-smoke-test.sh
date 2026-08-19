#!/usr/bin/env bash
# Smoke test for an AVWOWE Flatpak bundle.
#
# Verifies that the bundle installs, the sandbox resolves every library, the app
# starts, creates its configuration, and exits cleanly. Runs headless with
# software rendering, so it does NOT test real GPU drivers -- see the notes at
# the bottom for what still needs a real machine.
#
# Usage: ./flatpak-smoke-test.sh AVWOWE-1.0.0-x86_64.flatpak

set -uo pipefail

BUNDLE="${1:-}"
APP_ID="com.xusione.AVWOWE"
PASS=0
FAIL=0

if [ -z "$BUNDLE" ] || [ ! -f "$BUNDLE" ]; then
    echo "usage: $0 <bundle.flatpak>" >&2
    exit 2
fi

ok()   { echo "  PASS  $1"; PASS=$((PASS+1)); }
bad()  { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }
note() { echo "  ..    $1"; }

echo "AVWOWE Flatpak smoke test"
echo "bundle: $BUNDLE ($(du -h "$BUNDLE" | cut -f1))"
echo

# ---------------------------------------------------------------- environment
command -v flatpak >/dev/null || { echo "flatpak not installed"; exit 2; }
note "flatpak $(flatpak --version | awk '{print $2}')"

# --------------------------------------------------------------- clean slate
if flatpak info --user "$APP_ID" >/dev/null 2>&1; then
    note "removing existing user install"
    flatpak uninstall --user -y "$APP_ID" >/dev/null 2>&1
fi

# ------------------------------------------------------------------- install
echo "[1/6] install"
if flatpak install --user -y --bundle "$BUNDLE" >/tmp/avwowe-install.log 2>&1; then
    ok "bundle installed"
else
    bad "install failed -- see /tmp/avwowe-install.log"
    tail -20 /tmp/avwowe-install.log
    exit 1
fi

# ------------------------------------------------------------ runtime present
echo "[2/6] runtime"
RT=$(flatpak info --user "$APP_ID" 2>/dev/null | awk -F': *' '/^ *Runtime:/{print $2}')
note "declared runtime: ${RT:-unknown}"
if flatpak list --columns=ref | grep -q "org.freedesktop.Platform.*24.08"; then
    ok "Platform 24.08 available"
else
    bad "Platform 24.08 missing -- runtime resolution would fail for users"
fi
if flatpak list --columns=ref | grep -q "ffmpeg-full"; then
    ok "ffmpeg-full extension present (media playback)"
else
    bad "ffmpeg-full missing -- video/audio will not play"
fi

# ------------------------------------------------------- library resolution
echo "[3/6] libraries"
MISSING=$(flatpak run --command=sh "$APP_ID" \
    -c 'LD_LIBRARY_PATH=/app/lib ldd /app/bin/AVWOWE 2>/dev/null | grep "not found"' 2>/dev/null)
if [ -z "$MISSING" ]; then
    ok "all libraries resolve inside the sandbox"
else
    bad "unresolved libraries:"
    echo "$MISSING" | sed 's/^/        /'
fi

# ------------------------------------------------------------ bundled tools
echo "[4/6] bundled tools"
if flatpak run --command=which "$APP_ID" xset >/dev/null 2>&1; then
    ok "xset present (display blanking suppression)"
else
    bad "xset missing -- display may blank during playback"
fi

# --------------------------------------------------------------- permissions
echo "[5/6] permissions"
PERMS=$(flatpak info --show-permissions "$APP_ID" 2>/dev/null)
grep -q "persistent=.avwowe" <<<"$PERMS" \
    && ok "persist=.avwowe (settings will save)" \
    || bad "persist=.avwowe missing -- settings will NOT be saved"
grep -q "x11" <<<"$PERMS" \
    && ok "x11 socket granted" \
    || bad "no x11 socket -- app cannot display"
grep -qE "shared=.*network" <<<"$PERMS" \
    && ok "network granted (live URL tickers)" \
    || bad "no network -- live tickers will fail"

# ------------------------------------------------------------ headless launch
echo "[6/6] headless launch"
if ! command -v xvfb-run >/dev/null; then
    note "SKIP -- xvfb-run not installed (apt install xvfb / dnf install xorg-x11-server-Xvfb)"
else
    LOG=/tmp/avwowe-run.log
    # Software rendering: this exercises startup, not the real GPU path.
    timeout 25 xvfb-run -a --server-args="-screen 0 1280x720x24" \
        env LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe \
        flatpak run "$APP_ID" >"$LOG" 2>&1
    RC=$?
    # 124 = killed by timeout, which is the expected result for a display app
    # that runs until closed.
    if [ $RC -eq 124 ] || [ $RC -eq 0 ]; then
        ok "app started and ran (exit $RC)"
    else
        bad "app exited abnormally (exit $RC) -- see $LOG"
        tail -25 "$LOG" | sed 's/^/        /'
    fi

    grep -qi "GL_RENDERER" "$LOG" \
        && ok "OpenGL context created: $(grep -i GL_RENDERER "$LOG" | head -1 | sed 's/.*GL_RENDERER: *//')" \
        || note "no GL_RENDERER line -- may not have reached rendering"

    if grep -qiE "command not found|error while loading shared|cannot open shared" "$LOG"; then
        bad "missing command or library reported at runtime:"
        grep -iE "command not found|error while loading shared|cannot open shared" "$LOG" | sort -u | sed 's/^/        /'
    else
        ok "no missing-command or missing-library errors"
    fi

    CFG="$HOME/.var/app/$APP_ID/.avwowe"
    if [ -d "$CFG" ] && [ -n "$(ls -A "$CFG" 2>/dev/null)" ]; then
        ok "settings written to persistent storage ($(ls "$CFG" | tr '\n' ' '))"
    else
        bad "no settings written to $CFG -- persistence is not working"
    fi
fi

# -------------------------------------------------------------------- summary
echo
echo "-------------------------------------------"
echo "  passed: $PASS    failed: $FAIL"
echo "-------------------------------------------"
cat <<'EOF'

NOT covered by this test -- these still need a real machine:
  * NVIDIA proprietary drivers (the most likely real-world failure)
  * AMD / Intel hardware video decoding performance
  * a Wayland session without XWayland installed
  * actual audio output (PipeWire or PulseAudio)
  * real H.264 / MP3 playback with hardware decode

EOF

[ "$FAIL" -eq 0 ] || exit 1
