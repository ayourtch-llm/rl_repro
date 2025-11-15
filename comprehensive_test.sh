#!/bin/bash
# Comprehensive test: Try different SIGWINCH timing scenarios

VERSION_NAME="${1:-unknown}"

echo "========================================="
echo "Comprehensive SIGWINCH Test"
echo "Version: $VERSION_NAME"
echo "========================================="
echo ""

test_scenario() {
    local scenario_name="$1"
    local test_num="$2"

    echo "----------------------------------------"
    echo "Test $test_num: $scenario_name"
    echo "----------------------------------------"

    FIFO=$(mktemp -u)
    mkfifo "$FIFO"

    timeout 20 cargo run --quiet < "$FIFO" > test_scenario_$test_num.log 2>&1 &
    PID=$!

    sleep 0.5
    exec 3>"$FIFO"

    case $test_num in
        1)
            # Scenario 1: SIGWINCH while nested editor is ACTIVE
            echo "Scenario: SIGWINCH while nested editor is active"
            echo "  1. Sending 'confirm'..."
            echo "confirm" >&3
            sleep 0.5

            echo "  2. Nested editor is ACTIVE, sending SIGWINCH..."
            for i in {1..15}; do
                kill -WINCH $PID 2>/dev/null || break
                sleep 0.1
            done

            echo "  3. Answering 'y'..."
            echo "y" >&3
            sleep 0.5
            ;;

        2)
            # Scenario 2: SIGWINCH AFTER nested editor drops (wait 3-4 sec)
            echo "Scenario: SIGWINCH after nested editor drops (3-4 sec delay)"
            echo "  1. Sending 'confirm'..."
            echo "confirm" >&3
            sleep 0.5

            echo "  2. Answering 'y' immediately..."
            echo "y" >&3

            echo "  3. Waiting 3-4 seconds for nested editor to fully drop..."
            sleep 3.5

            echo "  4. Now sending SIGWINCH to main editor..."
            for i in {1..15}; do
                kill -WINCH $PID 2>/dev/null || break
                sleep 0.1
            done
            ;;

        3)
            # Scenario 3: Both - SIGWINCH while active, then after drop
            echo "Scenario: SIGWINCH while active AND after drop"
            echo "  1. Sending 'confirm'..."
            echo "confirm" >&3
            sleep 0.5

            echo "  2. SIGWINCH while nested editor active..."
            for i in {1..10}; do
                kill -WINCH $PID 2>/dev/null || break
                sleep 0.1
            done

            echo "  3. Answering 'y'..."
            echo "y" >&3

            echo "  4. Waiting 3-4 seconds..."
            sleep 3.5

            echo "  5. SIGWINCH after nested editor dropped..."
            for i in {1..10}; do
                kill -WINCH $PID 2>/dev/null || break
                sleep 0.1
            done
            ;;

        4)
            # Scenario 4: Multiple nested editors with delays
            echo "Scenario: Multiple nested editors with SIGWINCH after each"
            for round in {1..3}; do
                echo "  Round $round: Creating nested editor..."
                echo "confirm" >&3
                sleep 0.5
                echo "y" >&3
                sleep 3

                echo "  Sending SIGWINCH after drop $round..."
                for i in {1..10}; do
                    kill -WINCH $PID 2>/dev/null || break
                    sleep 0.1
                done
            done
            ;;
    esac

    echo "  Sending quit..."
    echo "quit" >&3
    sleep 0.5

    exec 3>&-

    wait $PID 2>/dev/null
    EXIT_CODE=$?
    rm -f "$FIFO"

    if [ $EXIT_CODE -eq 0 ]; then
        echo "Result: ✅ PASSED"
        rm -f test_scenario_$test_num.log
        return 0
    elif grep -q "thread.*panicked\|assertion.*failed\|fd != -1" test_scenario_$test_num.log 2>/dev/null; then
        echo "Result: ❌ PANIC/CRASH DETECTED"
        echo ""
        echo "Error output:"
        grep -B 2 -A 5 "thread.*panicked\|assertion.*failed\|fd != -1" test_scenario_$test_num.log | head -15 | sed 's/^/  /'
        return 1
    else
        echo "Result: ⚠️  Exit code $EXIT_CODE (no panic message)"
        return 1
    fi
}

# Run all scenarios
FAILURES=0

test_scenario "SIGWINCH while nested editor active" 1 || FAILURES=$((FAILURES + 1))
echo ""

test_scenario "SIGWINCH 3-4 sec after nested editor drops" 2 || FAILURES=$((FAILURES + 1))
echo ""

test_scenario "SIGWINCH both during and after" 3 || FAILURES=$((FAILURES + 1))
echo ""

test_scenario "Multiple nested with SIGWINCH after each" 4 || FAILURES=$((FAILURES + 1))
echo ""

echo "========================================="
echo "Final Results"
echo "========================================="
echo "Tests run: 4"
echo "Failed:    $FAILURES"
echo "Passed:    $((4 - FAILURES))"
echo ""

if [ $FAILURES -eq 0 ]; then
    echo "✅ All scenarios passed - no bugs detected!"
    exit 0
else
    echo "❌ $FAILURES scenario(s) triggered crashes/panics"
    echo ""
    echo "Failed test logs:"
    ls -1 test_scenario_*.log 2>/dev/null | sed 's/^/  /'
    exit 1
fi
