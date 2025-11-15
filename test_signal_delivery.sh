#!/bin/bash
# Test if signals are actually being delivered to the process

echo "========================================="
echo "Signal Delivery Test"
echo "========================================="
echo ""

echo "Test 1: Verify SIGTERM delivery (should kill process)"
echo "------------------------------------------------------"

FIFO=$(mktemp -u)
mkfifo "$FIFO"

cargo run --quiet < "$FIFO" > signal_test.log 2>&1 &
PID=$!

sleep 0.5
exec 3>"$FIFO"

echo "confirm" >&3
sleep 0.5

echo "Process PID: $PID"
echo "Sending SIGTERM to test signal delivery..."
kill -TERM $PID 2>/dev/null

sleep 1

if kill -0 $PID 2>/dev/null; then
    echo "❌ Process still alive - signals may be blocked!"
    echo "quit" >&3
    exec 3>&-
    wait $PID 2>/dev/null
else
    echo "✅ SIGTERM worked - process was killed"
fi

exec 3>&- 2>/dev/null
rm -f "$FIFO"

echo ""
echo "Test 2: Check SIGWINCH with strace to see if it's received"
echo "-----------------------------------------------------------"

FIFO2=$(mktemp -u)
mkfifo "$FIFO2"

# Run with strace to see signal delivery
timeout 10 strace -e signal -f cargo run --quiet < "$FIFO2" > strace_test.log 2>&1 &
PID2=$!

sleep 1
exec 4>"$FIFO2"

echo "confirm" >&4
sleep 0.5

echo "Process PID: $PID2"
echo "Sending SIGWINCH..."

# Send SIGWINCH and see if strace shows it
for i in {1..5}; do
    kill -WINCH $PID2 2>/dev/null && echo "  Sent SIGWINCH #$i"
    sleep 0.2
done

sleep 0.5
echo "y" >&4
sleep 0.3
echo "quit" >&4

exec 4>&-
wait $PID2 2>/dev/null

rm -f "$FIFO2"

echo ""
echo "Checking strace output for SIGWINCH..."
if grep -q "SIGWINCH" strace_test.log; then
    echo "✅ SIGWINCH signals were received by the process"
    echo "SIGWINCH occurrences:"
    grep "SIGWINCH" strace_test.log | head -10
else
    echo "❌ No SIGWINCH found in strace output"
    echo "This suggests signals are being blocked or not delivered"
fi

echo ""
echo "Test 3: Direct process test (no cargo run wrapper)"
echo "---------------------------------------------------"

FIFO3=$(mktemp -u)
mkfifo "$FIFO3"

# Run the binary directly, not through cargo
cargo build --quiet

./target/debug/rustyline_repro < "$FIFO3" > direct_test.log 2>&1 &
PID3=$!

sleep 0.5
exec 5>"$FIFO3"

echo "Direct process PID: $PID3"
echo "confirm" >&5
sleep 0.5

echo "Sending SIGWINCH directly to the process..."
for i in {1..10}; do
    if kill -WINCH $PID3 2>/dev/null; then
        echo "  SIGWINCH #$i sent to PID $PID3"
    else
        echo "  Process died at SIGWINCH #$i!"
        break
    fi
    sleep 0.2
done

sleep 0.5
echo "y" >&5
sleep 0.3
echo "quit" >&5

exec 5>&-
wait $PID3 2>/dev/null
EXIT_CODE=$?

rm -f "$FIFO3"

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Direct process exited normally (exit code 0)"
elif grep -q "thread.*panicked\|assertion.*failed" direct_test.log; then
    echo "❌ CRASH/PANIC detected in direct process!"
    grep -B 2 -A 5 "thread.*panicked\|assertion.*failed" direct_test.log
else
    echo "⚠️  Direct process exited with code $EXIT_CODE"
fi

echo ""
echo "========================================="
echo "Summary"
echo "========================================="
echo "Check the logs:"
echo "  - signal_test.log (SIGTERM test)"
echo "  - strace_test.log (strace output)"
echo "  - direct_test.log (direct binary test)"
