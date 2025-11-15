#!/bin/bash
# Stress test to try to trigger the SIGWINCH bug
# Runs multiple iterations to catch non-deterministic crashes

ITERATIONS=${1:-20}
VERSION_NAME="${2:-unknown}"

echo "========================================="
echo "SIGWINCH Stress Test - $ITERATIONS iterations"
echo "Version: $VERSION_NAME"
echo "========================================="
echo ""

CRASHES=0
SUCCESS=0

for i in $(seq 1 $ITERATIONS); do
    echo -n "Test $i/$ITERATIONS: "

    # Create a named pipe for input
    FIFO=$(mktemp -u)
    mkfifo "$FIFO"

    # Run the program with input from the pipe, in background
    timeout 10 cargo run --quiet < "$FIFO" > test_iter_$i.log 2>&1 &
    PID=$!

    # Give it a moment to start
    sleep 0.3

    # Send commands through the pipe
    exec 3>"$FIFO"

    # Create nested editor multiple times
    for j in {1..3}; do
        echo "confirm" >&3
        sleep 0.1
        echo "y" >&3
        sleep 0.1

        # Send SIGWINCH signals aggressively
        for k in {1..5}; do
            kill -WINCH $PID 2>/dev/null || break
            sleep 0.05
        done
    done

    echo "quit" >&3
    sleep 0.2

    # Close the pipe
    exec 3>&-

    # Wait for process to finish
    wait $PID 2>/dev/null
    EXIT_CODE=$?

    # Cleanup
    rm -f "$FIFO"

    # Check for crash
    if [ $EXIT_CODE -ne 0 ] && [ $EXIT_CODE -ne 124 ]; then
        echo "❌ CRASHED (exit code $EXIT_CODE)"
        CRASHES=$((CRASHES + 1))
        if grep -q "thread.*panicked" test_iter_$i.log; then
            echo "   Panic message:"
            grep -A 3 "thread.*panicked" test_iter_$i.log | sed 's/^/   /'
        fi
    elif grep -q "thread.*panicked" test_iter_$i.log; then
        echo "❌ PANIC DETECTED"
        CRASHES=$((CRASHES + 1))
        grep -A 3 "thread.*panicked" test_iter_$i.log | sed 's/^/   /'
    else
        echo "✅ OK"
        SUCCESS=$((SUCCESS + 1))
        rm -f test_iter_$i.log
    fi
done

echo ""
echo "========================================="
echo "Results Summary - $VERSION_NAME"
echo "========================================="
echo "Total tests:     $ITERATIONS"
echo "Successful:      $SUCCESS"
echo "Crashed/Panics:  $CRASHES"
echo ""

if [ $CRASHES -eq 0 ]; then
    echo "✅ All tests passed - no crashes detected!"
    exit 0
else
    echo "⚠️  $CRASHES crashes/panics detected"
    echo ""
    echo "Failed test logs:"
    ls -1 test_iter_*.log 2>/dev/null || echo "  (none saved)"
    exit 1
fi
