#!/bin/bash
# Stress test with correct SIGWINCH timing

ITERATIONS=${1:-30}
VERSION_NAME="${2:-unknown}"

echo "========================================="
echo "SIGWINCH Stress Test (Correct Timing)"
echo "Version: $VERSION_NAME"
echo "Iterations: $ITERATIONS"
echo "========================================="
echo ""

CRASHES=0
SUCCESS=0

for i in $(seq 1 $ITERATIONS); do
    echo -n "Test $i/$ITERATIONS: "

    FIFO=$(mktemp -u)
    mkfifo "$FIFO"

    timeout 15 cargo run --quiet < "$FIFO" > test_stress_$i.log 2>&1 &
    PID=$!

    sleep 0.3
    exec 3>"$FIFO"

    # First nested editor
    echo "confirm" >&3
    sleep 0.2

    # Send SIGWINCH while active
    for k in {1..8}; do
        kill -WINCH $PID 2>/dev/null || break
        sleep 0.05
    done

    echo "y" >&3
    sleep 0.2

    # Second nested editor (more stress)
    echo "confirm" >&3
    sleep 0.2

    # More SIGWINCH while active
    for k in {1..8}; do
        kill -WINCH $PID 2>/dev/null || break
        sleep 0.05
    done

    echo "n" >&3
    sleep 0.2

    # Back to main editor, send more SIGWINCH
    for k in {1..5}; do
        kill -WINCH $PID 2>/dev/null || break
        sleep 0.05
    done

    echo "quit" >&3
    sleep 0.2

    exec 3>&-

    wait $PID 2>/dev/null
    EXIT_CODE=$?
    rm -f "$FIFO"

    if [ $EXIT_CODE -ne 0 ] && [ $EXIT_CODE -ne 124 ]; then
        echo "❌ CRASHED (exit $EXIT_CODE)"
        CRASHES=$((CRASHES + 1))
        if grep -q "thread.*panicked\|assertion.*failed\|fd != -1" test_stress_$i.log; then
            grep -B 2 -A 3 "thread.*panicked\|assertion.*failed\|fd != -1" test_stress_$i.log | head -10 | sed 's/^/   /'
        fi
    elif grep -q "thread.*panicked\|assertion.*failed\|fd != -1" test_stress_$i.log; then
        echo "❌ PANIC/ASSERTION"
        CRASHES=$((CRASHES + 1))
        grep -B 2 -A 3 "thread.*panicked\|assertion.*failed\|fd != -1" test_stress_$i.log | head -10 | sed 's/^/   /'
    else
        echo "✅"
        SUCCESS=$((SUCCESS + 1))
        rm -f test_stress_$i.log
    fi
done

echo ""
echo "========================================="
echo "Results: $VERSION_NAME"
echo "========================================="
echo "Total:    $ITERATIONS"
echo "Success:  $SUCCESS"
echo "Crashes:  $CRASHES"
echo ""

if [ $CRASHES -eq 0 ]; then
    echo "✅ All tests passed!"
    exit 0
else
    echo "⚠️  $CRASHES failures detected"
    echo "Failed test logs: $(ls test_stress_*.log 2>/dev/null | wc -l) files"
    exit 1
fi
