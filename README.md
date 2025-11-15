# Rustyline SIGWINCH Nested Editors Bug Reproduction

This repository reproduces and tests the fix for a rustyline crash that occurs when nested editor instances are dropped and the terminal is resized.

## The Bug

**Issue:** [#902](https://github.com/kkawakam/rustyline/issues/902)

When creating nested rustyline `DefaultEditor` instances (e.g., a main REPL that creates temporary editors for confirmations), dropping the nested editor and then resizing the terminal can cause a panic with the error: `fd != -1`.

## The Fix

**PR:** [#903](https://github.com/kkawakam/rustyline/pull/903) by gwenn

The fix defers signal handler installation until the actual `readline()` call, preventing dangling signal handlers from dropped instances.

## Current Status

✅ **This repository is currently configured with PR #903 applied**

```toml
[dependencies]
rustyline = { git = "https://github.com/gwenn/rustyline.git", branch = "sigwinch" }
```

## Quick Start

### Run the test program:
```bash
cargo run
```

### Test the nested editor scenario:
1. At the `>>>` prompt, type: `confirm`
2. At the confirmation prompt, type: `y`
3. Resize your terminal window multiple times
4. With PR #903: Should NOT crash ✅
5. Without PR #903: May crash with "fd != -1" ❌

## Testing Different Versions

### Using the helper script:
```bash
./test_versions.sh
```

This interactive script allows you to:
- Test WITHOUT PR #903 (original crates.io version)
- Test WITH PR #903 (fixed version)
- Show current configuration

### Manual testing:

**Test WITH PR #903 (current default):**
```bash
cargo clean
cargo build
cargo run
```

**Test WITHOUT PR #903 (to reproduce the bug):**
```bash
# Edit Cargo.toml to use:
# rustyline = "*"

cargo clean
cargo build
cargo run
```

## Files

- `src/main.rs` - Reproduction program with nested editors
- `Cargo.toml` - Currently configured with PR #903
- `PR903_TEST_RESULTS.md` - Detailed test documentation
- `test_versions.sh` - Helper script to test different versions
- `README.md` - This file

## Expected Behavior

### Without PR #903 (v17.0.2 from crates.io):
- ❌ May panic after terminal resize
- ❌ Signal handlers left in inconsistent state
- ❌ "fd != -1" assertion failure

### With PR #903 (v17.0.1 from gwenn's branch):
- ✅ Handles terminal resize gracefully
- ✅ Signal handlers properly managed
- ✅ No crashes with nested editors

## How It Works

The reproduction creates:
1. A main `DefaultEditor` for the REPL
2. A nested `DefaultEditor` for confirmations (created temporarily)
3. Drops the nested editor
4. Tests terminal resize handling

The bug occurs because signal handlers installed during initialization remain active even after the nested editor is dropped, leading to crashes on SIGWINCH events.

PR #903 fixes this by deferring signal handler installation until the editor is actually used.

## Documentation

See [PR903_TEST_RESULTS.md](PR903_TEST_RESULTS.md) for comprehensive testing documentation.

## Contributing

To report issues or test results:
1. Specify which version you tested (with/without PR #903)
2. Describe the steps taken
3. Include any crash logs or panics observed

## License

This reproduction code is provided for testing purposes.
