#!/bin/sh
# pdfname_escape.sh — PDF Name space-escape test (ISO 32000-1, §7.3.5)
#
# Verify that spotxcolor escapes space (0x20) as #20 in PDF Names.
#
# ISO 32000-1, §7.3.5:
#   Characters in a Name outside 0x21–0x7E MUST be written as #XX.
#   Space (0x20) is outside this range → MUST appear as #20.
#
# Example:
#   \definespotcolor{DIC161s}{DIC 161s*}{0, 0.64, 1, 0}
#
#   Separation array:   [/Separation /DIC#20161s* /DeviceCMYK ...]   (correct)
#                        [/Separation /DIC 161s*  /DeviceCMYK ...]   (BROKEN)
#
# Usage:  sh t/pdfname_escape.sh <qdf-file> [<qdf-file> ...]
# Exit:   0 = all PASS, 1 = any FAIL

set -eu

__grep=grep
if which ggrep; then
    __grep=ggrep
fi

# ── helpers ──────────────────────────────────────────────────
total_pass=0
total_fail=0
total_file_fails=0

pass() { total_pass=$((total_pass + 1)); file_pass=$((file_pass + 1)); printf "  PASS: %s\n" "$1"; }
fail() { total_fail=$((total_fail + 1)); file_fail=$((file_fail + 1)); printf "  FAIL: %s\n" "$1"; }

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
    echo "=== pdfname_escape: $BASENAME ==="
    file_pass=0
    file_fail=0

    # ── Test 1: No QPDFFake entries ──────────────────────────
    # qpdf emits /QPDFFake<N> when a dictionary key Name contains
    # illegal bytes (e.g. bare space).  Presence = proof of breakage.
    if LANG=C ${__grep} -qa 'QPDFFake' "$QDF"; then
        n=$(LANG=C ${__grep} -ca 'QPDFFake' "$QDF")
        fail "QPDFFake entries found ($n) — qpdf could not parse PDF Names"
    else
        pass "No QPDFFake entries"
    fi

    # ── Test 2: Separation array names are #20-escaped ───────
    # Correct:  [/Separation /DIC#20161s* /DeviceCMYK ...]
    # Broken:   [/Separation /DIC 161s*   /DeviceCMYK ...]
    #           (space splits the Name into two tokens)
    if LANG=C ${__grep} -qa '/Separation' "$QDF"; then
        if LANG=C ${__grep} -aqP '/Separation\s+/\S*#20' "$QDF"; then
            pass "Separation array Name(s) contain #20 escaping"
        else
            fail "Separation array Name(s) lack #20 escaping"
        fi
    else
        pass "No Separation arrays (not applicable)"
    fi

    # ── Test 3: No bare spaces in cs/CS color-space operators ─
    # Content stream:  /DIC161s cs  (OK — xcolor name has no space)
    #                  /PANTONE 485 C cs  (BROKEN — bare space in Name)
    if LANG=C ${__grep} -aqP '/\w+ \w+.* [cC][sS]\b' "$QDF"; then
        fail "Bare spaces in cs/CS operator Name(s)"
    else
        pass "No bare spaces in cs/CS operator Names"
    fi

    # ── Test 4: ColorSpace dict keys have no bare spaces ─────
    # /ColorSpace << /DIC161s 14 0 R >>        (OK)
    # /ColorSpace << /PANTONE 485 ... >>        (BROKEN → QPDFFake)
    if LANG=C ${__grep} -aqP '/ColorSpace\b' "$QDF"; then
        if LANG=C ${__grep} -aA 20 '/ColorSpace <<' "$QDF" \
             | LANG=C ${__grep} -qP '^\s+/\w+ \w' 2>/dev/null; then
            fail "ColorSpace dict key(s) contain bare spaces"
        else
            pass "ColorSpace dict keys are clean"
        fi
    else
        pass "No ColorSpace dict (not applicable)"
    fi

    echo "--- $BASENAME: $file_pass passed, $file_fail failed ---"
    if [ "$file_fail" -gt 0 ]; then
        total_file_fails=$((total_file_fails + 1))
    fi
done

# ── summary ──────────────────────────────────────────────────
echo "=== total: $total_pass passed, $total_fail failed ==="
[ "$total_file_fails" -eq 0 ]
