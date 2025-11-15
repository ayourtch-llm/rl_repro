/// Instrumented version to verify SIGWINCH is received
/// This version adds signal counter to verify signals are delivered

use rustyline::DefaultEditor;
use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::Arc;

static SIGWINCH_COUNT: AtomicU32 = AtomicU32::new(0);

fn setup_sigwinch_counter() {
    use nix::sys::signal::{self, Signal, SigHandler};

    extern "C" fn handle_sigwinch(_: libc::c_int) {
        let count = SIGWINCH_COUNT.fetch_add(1, Ordering::SeqCst) + 1;
        // Use write() which is signal-safe
        let msg = format!("[SIGNAL RECEIVED: SIGWINCH #{}]\n", count);
        unsafe {
            libc::write(2, msg.as_ptr() as *const libc::c_void, msg.len());
        }
    }

    unsafe {
        signal::signal(Signal::SIGWINCH, SigHandler::Handler(handle_sigwinch))
            .expect("Failed to set SIGWINCH handler");
    }
}

fn get_confirmation_with_rustyline() -> bool {
    eprintln!("\n[INSTRUMENTED] Creating temporary rustyline editor");
    eprintln!("[INSTRUMENTED] SIGWINCH count before nested editor: {}",
              SIGWINCH_COUNT.load(Ordering::SeqCst));

    let mut rl = match DefaultEditor::new() {
        Ok(rl) => rl,
        Err(e) => {
            eprintln!("Failed to create confirmation editor: {}", e);
            return false;
        }
    };

    eprintln!("[INSTRUMENTED] Nested editor created, waiting for input...");
    match rl.readline("  Confirm? (y/n) >>> ") {
        Ok(line) => {
            let response = line.trim().to_lowercase();
            response == "y" || response == "yes"
        }
        Err(_) => false,
    }
}

fn main() {
    eprintln!("========================================");
    eprintln!("INSTRUMENTED SIGWINCH Test");
    eprintln!("========================================\n");

    // Set up our own SIGWINCH counter BEFORE rustyline
    // (This will get overridden by rustyline, which is part of the problem!)
    setup_sigwinch_counter();
    eprintln!("[INSTRUMENTED] Custom SIGWINCH handler installed");

    let mut main_rl = match DefaultEditor::new() {
        Ok(rl) => rl,
        Err(e) => {
            eprintln!("Failed to create main editor: {}", e);
            return;
        }
    };

    eprintln!("[INSTRUMENTED] Main editor created");
    eprintln!("[INSTRUMENTED] Send SIGWINCH now to test detection\n");

    loop {
        match main_rl.readline(">>> ") {
            Ok(line) => {
                let line = line.trim();

                if line == "quit" || line == "exit" {
                    break;
                }

                if line == "count" {
                    eprintln!("[INSTRUMENTED] SIGWINCH count: {}",
                              SIGWINCH_COUNT.load(Ordering::SeqCst));
                    continue;
                }

                if line == "confirm" {
                    eprintln!("\n[INSTRUMENTED] About to create nested editor...");
                    eprintln!("[INSTRUMENTED] SIGWINCH count: {}",
                              SIGWINCH_COUNT.load(Ordering::SeqCst));

                    if get_confirmation_with_rustyline() {
                        eprintln!("✓ Confirmed!");
                    } else {
                        eprintln!("✗ Cancelled!");
                    }

                    eprintln!("\n[INSTRUMENTED] Nested editor dropped");
                    eprintln!("[INSTRUMENTED] SIGWINCH count after: {}",
                              SIGWINCH_COUNT.load(Ordering::SeqCst));
                    eprintln!("[INSTRUMENTED] Send SIGWINCH now!");
                } else if !line.is_empty() {
                    eprintln!("Commands: confirm, count, quit");
                }
            }
            Err(_) => break,
        }
    }

    eprintln!("\n[INSTRUMENTED] Final SIGWINCH count: {}",
              SIGWINCH_COUNT.load(Ordering::SeqCst));
}
