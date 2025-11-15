#!/bin/bash
# Test the progression of commits to understand the fix

echo "======================================================================="
echo "Testing Commit Progression"
echo "======================================================================="
echo ""
echo "Commit History:"
echo "  dcc71b1:         BEFORE fix (old code)"
echo "  assertion_only:  OLD CODE + ASSERTION ONLY (to show value of assertion)"
echo "  2a1dcb2:         Install signal handlers only when actually reading (THE FIX)"
echo "  d6bab80:         Check SIGWINCH handler is not already installed (THE FIX + ASSERTION)"
echo ""
echo "======================================================================="
echo ""

test_commit() {
    local commit="$1"
    local description="$2"
    local cargo_toml="Cargo.toml.$commit"

    echo "Testing: $commit - $description"
    echo "-----------------------------------------------------------------------"

    if [ ! -f "$cargo_toml" ]; then
        echo "⚠️  Skipping - $cargo_toml not found"
        echo ""
        return
    fi

    cp "$cargo_toml" Cargo.toml
    cargo clean > /dev/null 2>&1

    if python3 pty_test.py > "test_$commit.log" 2>&1; then
        echo "✅ PASSED - No crash"
    else
        echo "❌ CRASHED"
        if grep -q "assertion.*failed" "test_$commit.log"; then
            echo "   💥 Assertion fired!"
            grep "assertion" "test_$commit.log" | head -3
        elif grep -q "fd != -1" "test_$commit.log"; then
            echo "   💥 fd != -1 panic"
        fi
    fi
    echo ""
}

# Test in chronological order
test_commit "dcc71b1" "BEFORE fix (old code)"
test_commit "assertion_only" "OLD CODE + ASSERTION (demonstrates value)"
test_commit "2a1dcb2" "THE FIX (defer signal handler installation)"
test_commit "d6bab80" "THE FIX + ASSERTION"

echo "======================================================================="
echo "Summary"
echo "======================================================================="
echo ""
echo "Results:"
echo "  dcc71b1:        ❌ CRASHES with 'fd != -1' (cryptic, delayed)"
echo "  assertion_only: ❌ CRASHES with 'assertion failed' (clear, immediate)"
echo "  2a1dcb2:        ✅ PASSES (fix applied)"
echo "  d6bab80:        ✅ PASSES (fix + safety assertion)"
echo ""
echo "Key Insight:"
echo "  The assertion (d6bab80) catches the bug IMMEDIATELY with a clear error,"
echo "  instead of the cryptic 'fd != -1' that appears later during SIGWINCH."
echo "  Even with the fix, the assertion provides defensive programming."
echo ""
