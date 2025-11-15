# Testing Rustyline PR #903 - SIGWINCH Fix

## Overview
This document describes testing of [PR #903](https://github.com/kkawakam/rustyline/pull/903) which fixes crashes when nested rustyline instances are dropped and terminal resize occurs.

## The Issue
**Original Bug (Issue #902):**
- Creating nested rustyline `DefaultEditor` instances
- Dropping the nested instance
- Resizing the terminal window
- Results in panic: "fd != -1" from rustyline's signal handler

**Root Cause:**
Signal handlers were installed during editor initialization. When a nested editor was dropped, signal handlers could be left in an inconsistent state, causing crashes on subsequent SIGWINCH (window resize) events.

## The Fix (PR #903)
**Author:** gwenn
**Branch:** `gwenn/rustyline` branch `sigwinch`
**Commit:** `8376906d9547d0699846a3b9e7f77f5e0d585c27`

**Change:** Defer signal handler installation until the actual reading operation begins (`readline()` call), rather than during initialization. This prevents dangling signal handlers from dropped instances.

## Test Setup

### Version Comparison

| Aspect | Without PR #903 | With PR #903 |
|--------|----------------|--------------|
| Rustyline Version | v17.0.2 (crates.io) | v17.0.1 (git branch) |
| Dependency | `rustyline = "*"` | `rustyline = { git = "https://github.com/gwenn/rustyline.git", branch = "sigwinch" }` |
| Signal Handler Install | During initialization | During `readline()` call |

### Current Build Status
✅ **Currently built with PR #903 applied**

The project is currently configured to use the PR #903 version:
```toml
[dependencies]
# Using PR #903 from gwenn's fork to test the SIGWINCH fix
# PR: https://github.com/kkawakam/rustyline/pull/903
rustyline = { git = "https://github.com/gwenn/rustyline.git", branch = "sigwinch" }
```

## How to Test

### Manual Interactive Test

1. **Build and run:**
   ```bash
   cargo build
   cargo run
   ```

2. **Trigger nested editor creation:**
   - At the `>>>` prompt, type: `confirm`
   - At the confirmation prompt, type: `y`

3. **Test terminal resize:**
   - After the nested editor is dropped, the program displays a message prompting you to resize
   - Resize your terminal window multiple times
   - Observe if any panic occurs

### Expected Results

**Without PR #903 (v17.0.2):**
- May panic with "fd != -1" error after resize
- Crash more likely with multiple nested editor creations

**With PR #903 (v17.0.1 from branch):**
- Should handle resize gracefully
- No panic even with nested editors
- Signal handlers properly managed

## Switching Between Versions

### To test WITHOUT PR #903 (original crates.io version):
```bash
# Edit Cargo.toml
[dependencies]
rustyline = "*"

# Clean and rebuild
cargo clean
cargo build
cargo run
```

### To test WITH PR #903 (current configuration):
```bash
# Edit Cargo.toml
[dependencies]
rustyline = { git = "https://github.com/gwenn/rustyline.git", branch = "sigwinch" }

# Clean and rebuild
cargo clean
cargo build
cargo run
```

## Test Checklist

- [ ] Test with original version (v17.0.2) - observe crash behavior
- [ ] Test with PR #903 version - verify fix works
- [ ] Test multiple nested editor cycles
- [ ] Test resize at different points in the lifecycle
- [ ] Test with rapid resizing
- [ ] Verify normal operation (non-nested) still works

## Notes

- The crash is **non-deterministic** - it may not occur every time
- Multiple iterations may be needed to trigger the bug
- The nested editor scenario increases probability of the crash
- Terminal resize timing matters - resize right after nested editor drops

## Conclusion

The project is currently configured with PR #903 applied. To fully verify the fix:

1. Test the current build (with PR #903) - expect no crashes
2. Switch to vanilla rustyline - may observe crashes
3. Switch back to PR #903 - confirm crashes are resolved

This validates that PR #903 successfully addresses the SIGWINCH nested editor issue.
