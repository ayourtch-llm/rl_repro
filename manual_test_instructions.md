# Manual Test Instructions

## You reported being able to reproduce the crash easily!

Please try this exact scenario:

### Step 1: Build with ORIGINAL version (without PR #903)
```bash
cd /home/user/rl_repro
cp Cargo.toml.original Cargo.toml
cargo clean
cargo build
```

### Step 2: Run the program interactively
```bash
cargo run
```

### Step 3: Follow the prompts
1. Type: `confirm`
2. At the nested prompt, type: `y`
3. **Now resize your terminal window**

Expected result WITHOUT PR #903: Crash with "fd != -1" or panic

### Step 4: Test with PR #903
```bash
cp Cargo.toml.pr903 Cargo.toml
cargo clean
cargo build
cargo run
```

Repeat steps above.

Expected result WITH PR #903: No crash

## Can you reproduce it?
If you can reproduce the crash, please share:
1. The exact error message
2. Your terminal emulator
3. OS details
