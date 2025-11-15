#!/bin/bash
# Compare both versions with PTY test

echo "======================================================================="
echo "Comparing rustyline versions with real PTY test"
echo "======================================================================="
echo ""

ITERATIONS=${1:-5}

test_version() {
    local version_name="$1"
    local cargo_toml="$2"

    echo "Testing: $version_name"
    echo "-----------------------------------------------------------------------"

    cp "$cargo_toml" Cargo.toml
    cargo clean > /dev/null 2>&1

    local crashes=0
    local successes=0

    for i in $(seq 1 $ITERATIONS); do
        echo -n "  Iteration $i/$ITERATIONS: "

        if python3 pty_test.py > pty_test_iteration_$i.log 2>&1; then
            echo "✅ PASSED"
            successes=$((successes + 1))
            rm -f pty_test_iteration_$i.log
        else
            echo "❌ CRASHED"
            crashes=$((crashes + 1))
        fi
    done

    echo ""
    echo "Results for $version_name:"
    echo "  Success: $successes/$ITERATIONS"
    echo "  Crashes: $crashes/$ITERATIONS"
    echo ""

    return $crashes
}

# Test original version
test_version "rustyline v17.0.2 (WITHOUT PR #903)" "Cargo.toml.original"
ORIGINAL_CRASHES=$?

echo ""
echo "======================================================================="
echo ""

# Test PR #903 version
test_version "rustyline v17.0.1 (WITH PR #903)" "Cargo.toml.pr903"
PR903_CRASHES=$?

echo ""
echo "======================================================================="
echo "FINAL COMPARISON"
echo "======================================================================="
echo "WITHOUT PR #903: $ORIGINAL_CRASHES crashes in $ITERATIONS iterations"
echo "WITH PR #903:    $PR903_CRASHES crashes in $ITERATIONS iterations"
echo ""

if [ $ORIGINAL_CRASHES -gt 0 ] && [ $PR903_CRASHES -eq 0 ]; then
    echo "✅ PR #903 SUCCESSFULLY FIXES THE BUG!"
    exit 0
elif [ $ORIGINAL_CRASHES -eq 0 ]; then
    echo "⚠️  Could not reproduce crash with original version"
    exit 1
elif [ $PR903_CRASHES -gt 0 ]; then
    echo "⚠️  PR #903 did not fully fix the bug"
    exit 1
fi
