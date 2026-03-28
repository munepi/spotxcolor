#!/bin/sh
# separation_name.sh — Separation colorant-name verification
#
# Verify that spotxcolor writes the correct colorant name (the user-
# visible spot-color name) into each Separation colour-space array,
# rather than the colour-model string "cmyk".
#
# Background (ISO 32000-1, §8.6.6.4):
#   [/Separation <name> <alternateSpace> <tintTransform>]
#   <name> must be the intended colorant name, e.g. /DIC#20161s*
#
# Bug being caught:
#   \definespotcolor{DIC161s}{DIC 161s*}{0, 0.64, 1, 0}
#                    #1       #2         #3
#   The second argument (PDF Name) must appear in the Separation
#   array.  A known bug passes the colour-model token "cmyk" instead,
#   producing:
#     [/Separation /cmyk /DeviceCMYK ...]   (BROKEN)
#   instead of:
#     [/Separation /DIC#20161s* /DeviceCMYK ...]   (correct)
#
# Expected PDF Names (from test.tex definitions):
#   DIC 161s*     -> /DIC#20161s*
#   DIC 256s*     -> /DIC#20256s*
#   DIC 200s*     -> /DIC#20200s*
#   PANTONE 876 C -> /PANTONE#20876#20C
#
# Usage:  sh separation_name.sh <qdf-file> [<qdf-file> ...]
# Exit:   0 = all PASS, 1 = any FAIL

set -eu
export LANG=C

# ── grep with PCRE support (macOS: use ggrep from homebrew) ──
__grep=grep
if which ggrep >/dev/null 2>&1; then
    __grep=ggrep
fi

# ── helpers ──────────────────────────────────────────────────
total_pass=0
total_fail=0
total_file_fails=0

pass() { total_pass=$((total_pass + 1)); file_pass=$((file_pass + 1)); printf "  PASS: %s\n" "$1"; }
fail() { total_fail=$((total_fail + 1)); file_fail=$((file_fail + 1)); printf "  FAIL: %s\n" "$1"; }

# ── Extract colorant names from Separation arrays ───────────
# In QDF, the pattern is:
#   /Separation
#   /<colorantName>
#   /DeviceCMYK
#   <objref>
# We grab the line immediately after each /Separation line.
colorant_names_in() {
    ${__grep} -aA1 '/Separation' "$1" | ${__grep} -av '/Separation' | ${__grep} -a '^ */' || true
}

# ── argument ─────────────────────────────────────────────────
if [ $# -lt 1 ]; then
    echo "Usage: $0 <qdf-file> [<qdf-file> ...]" >&2
    exit 2
fi

for QDF in "$@"; do
    if [ ! -f "$QDF" ]; then
        echo "WARNING: $QDF not found, skipping" >&2
        continue
    fi

    BASENAME=$(basename "$QDF" .qdf)
    echo "=== separation_name: $BASENAME ==="
    file_pass=0
    file_fail=0

    names=$(colorant_names_in "$QDF")

    if [ -z "$names" ]; then
        fail "No Separation arrays found in QDF"
        echo "--- $BASENAME: $file_pass passed, $file_fail failed ---"
        total_file_fails=$((total_file_fails + 1))
        continue
    fi

    # ── Test 1: /cmyk must NOT appear as a colorant name ─────
    # If the colour-model argument "cmyk" leaks into the PDF Name
    # slot, all spot colours become indistinguishable.
    if printf '%s\n' "$names" | ${__grep} -qa '^ */cmyk$'; then
        n=$(printf '%s\n' "$names" | ${__grep} -ca '^ */cmyk$')
        fail "/cmyk found as colorant name ($n times) — colour-model leak"
    else
        pass "No /cmyk colorant-name leak"
    fi

    # ── Test 2–5: expected PDF Names present ─────────────────
    for expected in \
        "/DIC#20161s*" \
        "/DIC#20256s*" \
        "/DIC#20200s*" \
        "/PANTONE#20876#20C"
    do
        if printf '%s\n' "$names" | ${__grep} -qaF "$expected"; then
            pass "Colorant name $expected found"
        else
            fail "Colorant name $expected NOT found"
        fi
    done

    echo "--- $BASENAME: $file_pass passed, $file_fail failed ---"
    if [ "$file_fail" -gt 0 ]; then
        total_file_fails=$((total_file_fails + 1))
    fi
done

# ── summary ──────────────────────────────────────────────────
echo "=== total: $total_pass passed, $total_fail failed ==="
[ "$total_file_fails" -eq 0 ]
