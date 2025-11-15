#!/bin/bash
# Test with instrumented binary to see if SIGWINCH is actually being received

echo "========================================="
echo "Instrumented SIGWINCH Detection Test"
echo "========================================="
echo ""

FIFO=$(mktemp -u)
mkfifo "$FIFO"

./target/debug/instrumented_test < "$FIFO" > instrumented_out.log 2>&1 &
PID=$!

sleep 1
exec 3>"$FIFO"

echo "Process PID: $PID"
echo ""

echo "Step 1: Sending 'confirm' to create nested editor..."
echo "confirm" >&3
sleep 1

echo "Step 2: Sending SIGWINCH while nested editor is ACTIVE..."
for i in {1..5}; do
    echo "  Sending SIGWINCH #$i to PID $PID"
    kill -WINCH $PID 2>/dev/null || break
    sleep 0.3
done

sleep 1

echo "Step 3: Answering 'y'..."
echo "y" >&3
sleep 1

echo "Step 4: Sending SIGWINCH AFTER nested editor dropped..."
for i in {6..10}; do
    echo "  Sending SIGWINCH #$i to PID $PID"
    kill -WINCH $PID 2>/dev/null || break
    sleep 0.3
done

sleep 1

echo "Step 5: Sending 'quit'..."
echo "quit" >&3
sleep 0.5

exec 3>&-

wait $PID 2>/dev/null
EXIT_CODE=$?

rm -f "$FIFO"

echo ""
echo "========================================="
echo "Results"
echo "========================================="
echo ""

cat instrumented_out.log

echo ""
echo "========================================="
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Process exited normally"
else
    echo "❌ Process exited with code $EXIT_CODE"
fi

if grep -q "SIGNAL RECEIVED" instrumented_out.log; then
    SIGWINCH_RECV=$(grep -c "SIGNAL RECEIVED" instrumented_out.log)
    echo "✅ SIGWINCH signals detected: $SIGWINCH_RECV"
else
    echo "⚠️  No SIGWINCH signals detected in instrumented output"
    echo "    This means rustyline is handling them, not our counter"
fi

if grep -q "thread.*panicked\|assertion.*failed" instrumented_out.log; then
    echo "❌ PANIC/CRASH detected!"
    grep -B 2 -A 5 "thread.*panicked\|assertion.*failed" instrumented_out.log
fi
