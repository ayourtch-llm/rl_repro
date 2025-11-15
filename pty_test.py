#!/usr/bin/env python3
"""
Test with a real PTY (pseudo-terminal) instead of pipes
This may be necessary to reproduce the SIGWINCH bug
"""

import os
import pty
import select
import signal
import subprocess
import sys
import time
import termios
import struct
import fcntl

def set_winsize(fd, rows=24, cols=80):
    """Set the window size of a terminal"""
    winsize = struct.pack("HHHH", rows, cols, 0, 0)
    fcntl.ioctl(fd, termios.TIOCSWINSZ, winsize)

def test_with_pty():
    print("=" * 60)
    print("PTY Test - Real Terminal Emulation")
    print("=" * 60)
    print()

    # Create a pseudo-terminal
    master, slave = pty.openpty()

    # Set initial window size
    set_winsize(master, 24, 80)
    print(f"PTY created: master={master}, slave={slave}")
    print("Initial window size: 24x80")

    # Start the process with the PTY
    env = os.environ.copy()
    process = subprocess.Popen(
        ['./target/debug/rustyline_repro'],
        stdin=slave,
        stdout=slave,
        stderr=slave,
        close_fds=True,
        env=env,
        preexec_fn=os.setsid
    )

    os.close(slave)  # Parent doesn't need the slave

    print(f"Process started with PID: {process.pid}")
    print()

    # Helper to read from master without blocking indefinitely
    def read_output(timeout=0.5):
        output = b""
        end_time = time.time() + timeout
        while time.time() < end_time:
            ready, _, _ = select.select([master], [], [], 0.1)
            if ready:
                try:
                    chunk = os.read(master, 1024)
                    if chunk:
                        output += chunk
                    else:
                        break
                except OSError:
                    break
            else:
                if output:  # Got some output, give a bit more time
                    time.sleep(0.1)
        return output.decode('utf-8', errors='replace')

    try:
        # Wait for initial output
        print("Step 1: Waiting for initial prompt...")
        time.sleep(1)
        output = read_output(1.0)
        print(output)

        # Send 'confirm' command
        print("\nStep 2: Sending 'confirm' command...")
        os.write(master, b'confirm\n')
        time.sleep(0.5)
        output = read_output()
        print(output)

        # Now we're in the nested editor prompt
        print("\nStep 3: Nested editor is active (waiting for input)")
        print("       This is when we should test SIGWINCH!")

        # Resize the terminal WHILE nested editor is active
        print("\nStep 4: Resizing terminal from 24x80 to 30x100...")
        set_winsize(master, 30, 100)

        # Send SIGWINCH to the process
        print(f"       Sending SIGWINCH to process {process.pid}...")
        os.kill(process.pid, signal.SIGWINCH)
        time.sleep(0.3)

        # Resize again
        print("       Resizing to 40x120...")
        set_winsize(master, 40, 120)
        os.kill(process.pid, signal.SIGWINCH)
        time.sleep(0.3)

        # Resize again
        print("       Resizing to 20x60...")
        set_winsize(master, 20, 60)
        os.kill(process.pid, signal.SIGWINCH)
        time.sleep(0.5)

        # Check if process is still alive
        if process.poll() is not None:
            print(f"\n❌ CRASH DETECTED! Process exited with code {process.returncode}")
            output = read_output()
            print("Output before crash:")
            print(output)
            return False

        print("       Process still alive after SIGWINCH while nested editor active")

        # Now answer the prompt
        print("\nStep 5: Answering 'y' to nested prompt...")
        os.write(master, b'y\n')
        time.sleep(0.5)
        output = read_output()
        print(output)

        # Back to main prompt - try resizing again
        print("\nStep 6: Back to main prompt, resizing again...")
        for i in range(5):
            rows = 25 + i * 2
            cols = 80 + i * 5
            print(f"       Resize #{i+1}: {rows}x{cols}")
            set_winsize(master, rows, cols)
            os.kill(process.pid, signal.SIGWINCH)
            time.sleep(0.2)

            if process.poll() is not None:
                print(f"\n❌ CRASH DETECTED! Process exited with code {process.returncode}")
                output = read_output()
                print("Output before crash:")
                print(output)
                return False

        print("       Process still alive after multiple SIGWINCH")

        # Exit the program
        print("\nStep 7: Sending 'quit' command...")
        os.write(master, b'quit\n')
        time.sleep(0.5)

        # Wait for process to exit
        try:
            process.wait(timeout=2)
            print(f"\n✅ Process exited normally with code {process.returncode}")
        except subprocess.TimeoutExpired:
            print("\n⚠️  Process didn't exit, killing it...")
            process.kill()
            process.wait()

        # Get final output
        output = read_output()
        if output:
            print("\nFinal output:")
            print(output)

        return process.returncode == 0

    except Exception as e:
        print(f"\n❌ Exception: {e}")
        import traceback
        traceback.print_exc()
        process.kill()
        return False
    finally:
        os.close(master)

if __name__ == '__main__':
    # Make sure the binary is built
    print("Building rustyline_repro...")
    result = subprocess.run(['cargo', 'build', '--quiet'],
                          capture_output=True, text=True)
    if result.returncode != 0:
        print("Build failed:")
        print(result.stderr)
        sys.exit(1)

    print()
    success = test_with_pty()

    print("\n" + "=" * 60)
    if success:
        print("✅ TEST PASSED - No crashes detected")
    else:
        print("❌ TEST FAILED - Crash or error detected")
    print("=" * 60)

    sys.exit(0 if success else 1)
