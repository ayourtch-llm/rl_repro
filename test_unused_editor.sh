#!/bin/bash
# Test the scenario where an editor is created but never used
# This is what PR #903 specifically fixes!

VERSION_NAME="${1:-unknown}"

echo "========================================="
echo "Unused Editor SIGWINCH Test"
echo "Version: $VERSION_NAME"
echo "========================================="
echo ""
echo "This tests creating an editor WITHOUT calling readline()"
echo "PR #903 fixes this by deferring signal handler install"
echo ""

FIFO=$(mktemp -u)
mkfifo "$FIFO"

./target/debug/unused_editor_test < "$FIFO" > unused_test.log 2>&1 &
PID=$!

sleep 1
exec 3>"$FIFO"

echo "Test Scenario 1: Create unused editor, then SIGWINCH"
echo "------------------------------------------------------"
echo "  Creating unused editor..."
echo "create-unused" >&3
sleep 1

echo "  Sending SIGWINCH signals..."
for i in {1..15}; do
    if kill -WINCH $PID 2>/dev/null; then
        echo "    SIGWINCH #$i sent"
    else
        echo "    ❌ Process DIED at SIGWINCH #$i!"
        break
    fi
    sleep 0.2
done

sleep 1

echo ""
echo "Test Scenario 2: Create multiple unused editors, then SIGWINCH"
echo "---------------------------------------------------------------"
for round in {1..3}; do
    echo "  Round $round: Creating unused editor..."
    echo "create-unused" >&3
    sleep 0.5
done

echo "  Sending SIGWINCH after creating 3 unused editors..."
for i in {16..25}; do
    if kill -WINCH $PID 2>/dev/null; then
        echo "    SIGWINCH #$i sent"
    else
        echo "    ❌ Process DIED at SIGWINCH #$i!"
        break
    fi
    sleep 0.2
done

sleep 1

echo ""
echo "Sending quit..."
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

if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Process exited normally (exit code 0)"
elif [ $EXIT_CODE -eq 143 ]; then
    echo "⚠️  Process was terminated (SIGTERM)"
else
    echo "❌ Process exited with code $EXIT_CODE"
fi

echo ""
echo "Program output:"
echo "----------------------------------------"
cat unused_test.log
echo "----------------------------------------"

echo ""
if grep -q "thread.*panicked\|assertion.*failed\|fd != -1" unused_test.log; then
    echo "❌ PANIC/CRASH/ASSERTION DETECTED!"
    echo ""
    grep -B 3 -A 7 "thread.*panicked\|assertion.*failed\|fd != -1" unused_test.log | head -20
    exit 1
else
    echo "✅ No panic or crash detected"
fi

exit $EXIT_CODE
