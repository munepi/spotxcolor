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
    if ${__grep} -qa 'QPDFFake' "$QDF"; then
        n=$(${__grep} -ca 'QPDFFake' "$QDF")
        fail "QPDFFake entries found ($n) — qpdf could not parse PDF Names"
    else
        pass "No QPDFFake entries"
    fi

    # ── Test 2: Separation array Names are #20-escaped ───────
    # In QDF format, elements may be on separate lines:
    #   /Separation
    #   /DIC#20161s*           ← Name (next line after /Separation)
    #   /DeviceCMYK
    # Or on one line:
    #   /Separation /DIC#20161s* /DeviceCMYK
    #
    # Strategy: extract the line(s) immediately following /Separation
    # and check whether any Name there contains #20.
    if ${__grep} -qa '/Separation' "$QDF"; then
        # Get 1 line of context after /Separation — captures the Name
        sep_context=$(${__grep} -aA1 '/Separation' "$QDF")
        if printf '%s\n' "$sep_context" | ${__grep} -qP '#20'; then
            pass "Separation array Name(s) contain #20 escaping"
        else
            fail "Separation array Name(s) lack #20 escaping"
        fi
    else
        pass "No Separation arrays (not applicable)"
    fi

    # ── Test 3: No bare-space Names in content stream operators ─
    # Content streams are between "stream" and "endstream" lines.
    # A broken Name in a cs/CS operator looks like:
    #   /DIC 161s* cs /DIC 161s* CS 1 sc 1 SC
    # Check: extract content streams, look for lines with both
    # a bare-space slash-Name and a cs/CS/sc/SC operator.
    stream_data=$(sed -n '/^stream$/,/^endstream$/p' "$QDF" 2>/dev/null || true)
    if [ -n "$stream_data" ]; then
        if printf '%s\n' "$stream_data" \
             | ${__grep} -qP '/\S+\s+\S+.*\s[cC][sS]\s' 2>/dev/null; then
            # Double-check it's not just "/Name cs /Name CS" (which is valid)
            # A broken Name has space INSIDE: /WORD WORD ... cs
            if printf '%s\n' "$stream_data" \
                 | ${__grep} -qP '/[A-Za-z]+\s+[A-Za-z0-9]+\S*\s+[cC][sS]\s' 2>/dev/null; then
                fail "Bare-space Name(s) in content stream cs/CS operators"
            else
                pass "Content stream cs/CS operators are clean"
            fi
        else
            pass "Content stream cs/CS operators are clean"
        fi
    else
        pass "No content streams (not applicable)"
    fi

    echo "--- $BASENAME: $file_pass passed, $file_fail failed ---"
    if [ "$file_fail" -gt 0 ]; then
        total_file_fails=$((total_file_fails + 1))
    fi
done

# ── summary ──────────────────────────────────────────────────
echo "=== total: $total_pass passed, $total_fail failed ==="
[ "$total_file_fails" -eq 0 ]
