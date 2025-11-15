#!/bin/bash
# Helper script to test different rustyline versions

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function print_header() {
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}========================================${NC}\n"
}

function test_original() {
    print_header "Testing WITHOUT PR #903 (original crates.io version)"

    # Backup current Cargo.toml
    cp Cargo.toml Cargo.toml.backup

    # Create version without PR
    cat > Cargo.toml << 'EOF'
[package]
name = "rustyline_repro"
version = "0.1.0"
edition = "2024"

[dependencies]
rustyline = "*"
EOF

    echo -e "${YELLOW}Building with rustyline from crates.io...${NC}"
    cargo clean > /dev/null 2>&1
    cargo build

    echo -e "\n${YELLOW}Version info:${NC}"
    cargo tree | grep rustyline | head -1

    echo -e "\n${RED}⚠️  This version MAY crash on terminal resize after nested editor!${NC}"
    echo -e "${YELLOW}To test:${NC}"
    echo -e "  1. Run: cargo run"
    echo -e "  2. Type: confirm"
    echo -e "  3. Type: y"
    echo -e "  4. Resize your terminal window multiple times"
    echo -e "  5. May see panic: 'fd != -1'\n"

    read -p "Press Enter to run the test (or Ctrl+C to skip)..."
    cargo run

    # Restore backup
    mv Cargo.toml.backup Cargo.toml
}

function test_pr903() {
    print_header "Testing WITH PR #903 (fix applied)"

    # Backup current Cargo.toml
    cp Cargo.toml Cargo.toml.backup

    # Create version with PR
    cat > Cargo.toml << 'EOF'
[package]
name = "rustyline_repro"
version = "0.1.0"
edition = "2024"

[dependencies]
# Using PR #903 from gwenn's fork to test the SIGWINCH fix
# PR: https://github.com/kkawakam/rustyline/pull/903
rustyline = { git = "https://github.com/gwenn/rustyline.git", branch = "sigwinch" }
EOF

    echo -e "${YELLOW}Building with PR #903 from gwenn's fork...${NC}"
    cargo clean > /dev/null 2>&1
    cargo build

    echo -e "\n${YELLOW}Version info:${NC}"
    cargo tree | grep rustyline | head -1

    echo -e "\n${GREEN}✅ This version should handle terminal resize gracefully!${NC}"
    echo -e "${YELLOW}To test:${NC}"
    echo -e "  1. Run: cargo run"
    echo -e "  2. Type: confirm"
    echo -e "  3. Type: y"
    echo -e "  4. Resize your terminal window multiple times"
    echo -e "  5. Should NOT crash\n"

    read -p "Press Enter to run the test (or Ctrl+C to skip)..."
    cargo run

    # Restore backup
    mv Cargo.toml.backup Cargo.toml
}

function show_current() {
    print_header "Current Configuration"
    echo -e "${YELLOW}Cargo.toml dependencies:${NC}"
    grep -A 3 "\[dependencies\]" Cargo.toml

    if cargo tree 2>/dev/null | grep -q "rustyline.*git"; then
        echo -e "\n${GREEN}Currently using PR #903 version${NC}"
    else
        echo -e "\n${YELLOW}Currently using crates.io version${NC}"
    fi
}

function main() {
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  Rustyline PR #903 Testing Script                     ║${NC}"
    echo -e "${GREEN}║  Test SIGWINCH fix for nested editors                 ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}\n"

    echo "Options:"
    echo "  1) Test WITHOUT PR #903 (original - may crash)"
    echo "  2) Test WITH PR #903 (fixed version)"
    echo "  3) Show current configuration"
    echo "  4) Exit"
    echo ""
    read -p "Select option (1-4): " choice

    case $choice in
        1) test_original ;;
        2) test_pr903 ;;
        3) show_current ;;
        4) echo "Exiting..."; exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}"; exit 1 ;;
    esac
}

main
