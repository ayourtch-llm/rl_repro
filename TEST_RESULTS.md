# Rustyline PR #903 Test Results

## Test Date
2025-11-15

## Executive Summary

Automated testing of rustyline PR #903 (SIGWINCH fix for nested editors) has been completed. Both versions (with and without PR #903) pass all automated tests in this environment. However, **PR #903 is still recommended** as it fixes a race condition that may manifest under different terminal conditions or timing scenarios.

## Versions Tested

| Version | Source | Commit |
|---------|--------|--------|
| **WITHOUT PR #903** | crates.io | rustyline v17.0.2 |
| **WITH PR #903** | gwenn's fork | rustyline v17.0.1 (commit 8376906d) |

## Test Environment

- **OS:** Linux 4.4.0
- **Test Method:** Automated scripts with SIGWINCH signals
- **Date:** 2025-11-15

## Test Scenarios

### 1. Basic Test
- Create main editor
- Create nested editor with "confirm" command
- Send SIGWINCH signals (10x)
- Answer prompt and quit

**Result:**
- WITHOUT PR #903: ✅ PASSED (20/20 iterations)
- WITH PR #903: ✅ PASSED (20/20 iterations)

### 2. Correct Timing Test
Send SIGWINCH **while** the nested editor is actively waiting for input.

**Result:**
- WITHOUT PR #903: ✅ PASSED
- WITH PR #903: ✅ PASSED

### 3. Delayed SIGWINCH Test
Send SIGWINCH 3-4 seconds **after** the nested editor has been dropped.

**Result:**
- WITHOUT PR #903: ✅ PASSED
- WITH PR #903: ✅ PASSED

### 4. Combined Test
Send SIGWINCH both during active state AND after dropping the nested editor.

**Result:**
- WITHOUT PR #903: ✅ PASSED
- WITH PR #903: ✅ PASSED

### 5. Multiple Nested Editors Test
Create and drop 3 nested editors sequentially, sending SIGWINCH after each.

**Result:**
- WITHOUT PR #903: ✅ PASSED
- WITH PR #903: ✅ PASSED

## Why The Bug Wasn't Reproduced

The original bug (issue #902) is known to be **non-deterministic** and environment-specific. Possible reasons for not reproducing:

1. **Terminal Type Dependencies:** The bug may only manifest with specific terminal types or configurations
2. **Real Terminal Required:** Automated SIGWINCH signals may differ from actual terminal resize ioctl() calls
3. **Timing Sensitivity:** The race condition might require very specific timing that's hard to hit in automated tests
4. **Platform Differences:** The test environment (Linux 4.4.0 in container) may differ from affected systems

## What PR #903 Fixes

Even though we couldn't reproduce the bug, PR #903 addresses a real architectural issue:

### Before PR #903:
```
Editor::new() → Install signal handlers immediately
  ↓
Create nested editor → Install signal handlers again (conflict!)
  ↓
Drop nested editor → Signal handlers in inconsistent state
  ↓
SIGWINCH arrives → CRASH (fd != -1)
```

### After PR #903:
```
Editor::new() → Do NOT install signal handlers yet
  ↓
readline() called → Install signal handlers now
  ↓
Drop editor → Clean up properly
  ↓
SIGWINCH arrives → Handled safely
```

## Code Changes in PR #903

The fix defers signal handler installation from `new()` to `readline()`:

- **Before:** Signal handlers installed during `DefaultEditor::new()`
- **After:** Signal handlers installed when `readline()` is first called

This prevents race conditions when nested editors are created but not used, or when multiple editors coexist.

## Recommendation

**✅ Use PR #903** even though the bug wasn't reproduced in testing because:

1. It fixes a documented real-world issue (#902)
2. The architectural improvement is sound (lazy signal handler installation)
3. No regressions observed in testing
4. Better resource management pattern

## Running The Tests

### Prerequisites
```bash
cd /home/user/rl_repro
cargo build
```

### Test Scripts Available

1. **run_test.sh** - Basic automated test
   ```bash
   ./run_test.sh
   ```

2. **correct_test.sh** - Test with correct SIGWINCH timing
   ```bash
   ./correct_test.sh "version name"
   ```

3. **comprehensive_test.sh** - All scenarios
   ```bash
   ./comprehensive_test.sh "version name"
   ```

4. **test_versions.sh** - Interactive version switcher
   ```bash
   ./test_versions.sh
   ```

### Manual Testing

For best results, manual testing is recommended:

```bash
cargo run
# Type: confirm
# Type: y
# Manually resize terminal window multiple times
```

Repeat several times to account for non-deterministic nature.

## Conclusion

While automated testing didn't trigger the crash, PR #903 represents a solid architectural fix for a documented race condition. The repository is configured to use PR #903 by default, which is the recommended configuration.

### Current Configuration

```toml
[dependencies]
rustyline = { git = "https://github.com/gwenn/rustyline.git", branch = "sigwinch" }
```

This provides the signal handler fix while maintaining full compatibility with existing code.
