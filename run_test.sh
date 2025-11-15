#!/bin/bash
# Automated test script to reproduce the SIGWINCH bug

set -e

echo "========================================="
echo "Running automated SIGWINCH test"
echo "========================================="
echo ""

# Build first
echo "Building..."
cargo build --quiet

echo "Starting test program in background..."
echo ""

# Create a named pipe for input
FIFO=$(mktemp -u)
mkfifo "$FIFO"

# Run the program with input from the pipe, in background
timeout 30 cargo run < "$FIFO" > test_output.log 2>&1 &
PID=$!

# Give it a moment to start
sleep 1

# Send commands through the pipe
exec 3>"$FIFO"

echo "Sending 'confirm' command..."
echo "confirm" >&3
sleep 0.5

echo "Sending 'y' response..."
echo "y" >&3
sleep 0.5

echo ""
echo "Nested editor created and dropped."
echo "Now sending SIGWINCH signals to simulate terminal resize..."
echo ""

# Send multiple SIGWINCH signals to simulate terminal resizing
for i in {1..10}; do
    echo "Sending SIGWINCH signal #$i to PID $PID..."
    kill -WINCH $PID 2>/dev/null || break
    sleep 0.2
done

echo ""
echo "Sending quit command..."
echo "quit" >&3
sleep 0.5

# Close the pipe
exec 3>&-

# Wait for process to finish
wait $PID 2>/dev/null
EXIT_CODE=$?

# Cleanup
rm -f "$FIFO"

echo ""
echo "========================================="
echo "Test Results"
echo "========================================="
echo ""

if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ SUCCESS: Program exited normally (exit code 0)"
    echo "   No crash detected with PR #903 applied!"
else
    echo "❌ FAILED: Program exited with code $EXIT_CODE"
    if [ $EXIT_CODE -eq 124 ]; then
        echo "   (Timeout - program didn't respond)"
    else
        echo "   (Possible crash or panic)"
    fi
fi

echo ""
echo "Program output:"
echo "----------------------------------------"
cat test_output.log
echo "----------------------------------------"

if grep -q "thread.*panicked" test_output.log; then
    echo ""
    echo "⚠️  PANIC DETECTED in output!"
    grep "thread.*panicked" test_output.log
    exit 1
elif grep -q "fd != -1" test_output.log; then
    echo ""
    echo "⚠️  Known SIGWINCH bug error detected!"
    exit 1
elif grep -q "SIGABRT\|SIGSEGV\|signal.*11" test_output.log; then
    echo ""
    echo "⚠️  Signal error detected!"
    exit 1
else
    echo ""
    echo "✅ No panic or error detected in output"
fi

exit $EXIT_CODE
