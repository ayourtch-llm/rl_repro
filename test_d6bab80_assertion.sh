#!/bin/bash
# Test if d6bab80 assertion fires when creating nested editors

echo "========================================="
echo "Testing commit d6bab80 assertion"
echo "========================================="
echo ""
echo "This commit adds: assert!(unsafe { SIG_PIPE == INVALID_FD });"
echo "Should fail when trying to install handler twice"
echo ""

FIFO=$(mktemp -u)
mkfifo "$FIFO"

./target/debug/rustyline_repro < "$FIFO" > d6bab80_test.log 2>&1 &
PID=$!

sleep 0.5
exec 3>"$FIFO"

echo "Sending 'confirm' to create nested editor..."
echo "confirm" >&3
sleep 1

# Check if process died
if ! kill -0 $PID 2>/dev/null; then
    echo "❌ Process DIED when creating nested editor!"
    echo ""
    wait $PID 2>/dev/null
    EXIT_CODE=$?
    echo "Exit code: $EXIT_CODE"
    echo ""
    echo "Output:"
    cat d6bab80_test.log

    if grep -q "assertion.*failed\|panicked at" d6bab80_test.log; then
        echo ""
        echo "✅ ASSERTION FIRED - Clean failure at nested editor creation!"
        exit 0
    fi
    exit 1
else
    echo "Process still alive after creating nested editor"

    # Clean up
    echo "y" >&3
    sleep 0.5
    echo "quit" >&3
    sleep 0.5

    exec 3>&-
    wait $PID 2>/dev/null

    echo ""
    echo "⚠️  No assertion failure - nested editor was created successfully"
    echo ""
    echo "Output:"
    cat d6bab80_test.log
    exit 0
fi
