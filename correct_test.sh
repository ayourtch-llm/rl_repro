#!/bin/bash
# Correct test: Send SIGWINCH while the nested editor is ACTIVE
# This is the key to reproducing the bug!

set -e

VERSION_NAME="${1:-unknown}"

echo "========================================="
echo "Correct SIGWINCH Test"
echo "Version: $VERSION_NAME"
echo "========================================="
echo ""
echo "Key: Send SIGWINCH while nested editor is ACTIVE (waiting for input)"
echo ""

# Create a named pipe for input
FIFO=$(mktemp -u)
mkfifo "$FIFO"

# Run the program with input from the pipe, in background
timeout 30 cargo run < "$FIFO" > test_output_correct.log 2>&1 &
PID=$!

# Give it a moment to start
sleep 0.5

# Send commands through the pipe
exec 3>"$FIFO"

echo "Step 1: Sending 'confirm' command..."
echo "confirm" >&3
sleep 0.5

echo "Step 2: Nested editor is now ACTIVE and waiting for input..."
echo "Step 3: Sending SIGWINCH signals while nested editor is reading..."

# Send multiple SIGWINCH signals while the nested editor is ACTIVE
for i in {1..10}; do
    echo "  Sending SIGWINCH #$i to PID $PID..."
    kill -WINCH $PID 2>/dev/null || {
        echo "  Process died!"
        break
    }
    sleep 0.2
done

echo "Step 4: Now answering the prompt with 'y'..."
echo "y" >&3
sleep 0.5

echo "Step 5: Sending quit..."
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
elif [ $EXIT_CODE -eq 124 ]; then
    echo "⚠️  TIMEOUT: Program didn't respond"
else
    echo "❌ FAILED: Program exited with code $EXIT_CODE"
fi

echo ""
echo "Program output:"
echo "----------------------------------------"
cat test_output_correct.log
echo "----------------------------------------"

if grep -q "thread.*panicked" test_output_correct.log; then
    echo ""
    echo "❌ PANIC DETECTED!"
    echo ""
    grep -A 5 "thread.*panicked" test_output_correct.log
    exit 1
elif grep -q "fd != -1" test_output_correct.log; then
    echo ""
    echo "❌ Known SIGWINCH bug error detected: 'fd != -1'"
    exit 1
else
    echo ""
    echo "✅ No panic or error detected"
fi

exit $EXIT_CODE
