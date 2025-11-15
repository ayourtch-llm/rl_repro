/// Test the scenario where an editor is created but never used (no readline call)
/// This is the scenario PR #903 is designed to fix!

use rustyline::DefaultEditor;

fn main() {
    eprintln!("========================================");
    eprintln!("Unused Editor SIGWINCH Test");
    eprintln!("========================================\n");

    eprintln!("Creating main editor...");
    let mut main_rl = match DefaultEditor::new() {
        Ok(rl) => rl,
        Err(e) => {
            eprintln!("Failed to create main editor: {}", e);
            return;
        }
    };

    eprintln!("Main editor created.\n");

    loop {
        match main_rl.readline(">>> ") {
            Ok(line) => {
                let line = line.trim();

                if line == "quit" || line == "exit" {
                    break;
                }

                if line == "create-unused" {
                    eprintln!("\n🔴 Creating a DefaultEditor but NOT calling readline()...");

                    // THIS IS THE KEY: Create editor but never use it!
                    {
                        let _unused_editor = match DefaultEditor::new() {
                            Ok(rl) => {
                                eprintln!("   Unused editor created");
                                rl
                            }
                            Err(e) => {
                                eprintln!("   Failed to create unused editor: {}", e);
                                continue;
                            }
                        };

                        eprintln!("   Unused editor exists in this scope...");
                        eprintln!("   WITHOUT PR #903: Signal handlers MAY be installed");
                        eprintln!("   WITH PR #903: Signal handlers NOT installed yet");

                        // Drop happens here
                    }

                    eprintln!("   ✓ Unused editor dropped (never called readline)");
                    eprintln!("\n╔═══════════════════════════════════════════════════════════╗");
                    eprintln!("║  👉 RESIZE YOUR TERMINAL WINDOW NOW                       ║");
                    eprintln!("║                                                           ║");
                    eprintln!("║  WITHOUT PR #903: May crash if signal handlers were      ║");
                    eprintln!("║                   installed during new() and not cleaned  ║");
                    eprintln!("║                                                           ║");
                    eprintln!("║  WITH PR #903: Should be safe - no handlers installed    ║");
                    eprintln!("╚═══════════════════════════════════════════════════════════╝\n");

                } else if line == "create-used" {
                    eprintln!("\n🟢 Creating a DefaultEditor AND calling readline()...");

                    let mut temp_editor = match DefaultEditor::new() {
                        Ok(rl) => {
                            eprintln!("   Temp editor created");
                            rl
                        }
                        Err(e) => {
                            eprintln!("   Failed to create temp editor: {}", e);
                            continue;
                        }
                    };

                    eprintln!("   Calling readline()...");
                    match temp_editor.readline("  Temp prompt >>> ") {
                        Ok(input) => eprintln!("   Got input: {}", input),
                        Err(_) => eprintln!("   Cancelled"),
                    }

                    eprintln!("   ✓ Temp editor dropped (after calling readline)\n");

                } else if !line.is_empty() {
                    eprintln!("Commands:");
                    eprintln!("  create-unused  - Create editor WITHOUT calling readline()");
                    eprintln!("  create-used    - Create editor WITH readline()");
                    eprintln!("  quit           - Exit");
                }
            }
            Err(_) => break,
        }
    }

    eprintln!("\nExiting...");
}
