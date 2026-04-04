# Agentic Coding Guidelines (AGENTS.md)

Welcome! This document provides crucial context, project conventions, and operational guidelines for agentic coding assistants operating within this repository. Adherence to these guidelines ensures changes are safe, idiomatic, and consistent with the repository's established patterns.

This repository is a declarative system configuration managed using **Nix Flakes** and **Home Manager**. It sets up user environments, packages, and dotfiles.

---

## 1. Repository Structure Overview

- `flake.nix`: The entry point defining inputs (e.g., `nixpkgs`, `home-manager`) and outputs (`homeConfigurations`).
- `flake.lock`: Pinned versions of the inputs.
- `users.nix`: Contains user-specific configuration (username, home directory, git details). This is imported by `flake.nix`.
- `home.nix`: The unified Home Manager configuration file. It contains all package definitions, shell configurations, and program settings.
- `overlays/`: Custom Nix overlays to modify or add packages.
- `devShells/`: Declarative development environments (if any).
- `maskfile.md`: A markdown-based task runner for repository management commands.

---

## 2. Build, Lint, and Test Commands

Nix evaluation acts as a strict linting and type-checking step. Since this is a declarative configuration, "testing" primarily means verifying that the Nix expressions evaluate successfully and the final derivation builds.

### Linting and Formatting
- **Formatter**: The standard formatter for Nix code in this project is `nixfmt` (or the default formatter defined in the flake).
  - Format a single file: `nix fmt <file>`
  - Format all files: `nix fmt`
- **Syntax Check**: Use `nix-instantiate --parse <file.nix>` to check for basic syntax errors without evaluating. Always do this after modifying `.nix` files.

### Building / "Testing"
To verify that the configuration compiles successfully without actually applying it to the host system, you should build the `activationPackage` derivation for the user. 
The primary user configuration can be found by reading `users.nix` (e.g., `aikoh`).

- **Fast Flake Check (Schema & Evaluation)**:
  Run this command to evaluate all outputs in the flake and ensure they meet flake schemas and type requirements.
  ```bash
  nix flake check
  ```

- **Dry-run Build (Evaluation Test)**:
  ```bash
  nix build .#homeConfigurations.aikoh.activationPackage --dry-run
  ```

- **Full Build (Without Switching)**:
  This builds the configuration and outputs a result symlink, verifying that all packages and modules evaluate correctly.
  ```bash
  nix build .#homeConfigurations.aikoh.activationPackage
  ```

### Applying Changes
When requested to actually apply the configuration:
```bash
home-manager switch --flake .
```
*(Only do this if the user explicitly requests applying or switching the environment).*

---

## 3. Code Style & Language Guidelines (Nix)

When reading or modifying `.nix` files, adhere strictly to the following idioms and conventions.

### Formatting & Whitespace
- **Indentation**: Use 2 spaces for indentation. Never use tabs.
- **Line Length**: Keep lines reasonably short. If an attribute set, list, or function call spans past ~80-100 characters, break it into multiple lines.
- **Trailing Commas/Semicolons**: In attribute sets and `let...in` blocks, ensure every declaration ends with a semicolon `;`. Lists do not use commas.

### Imports & Modularity
- **Avoid `with`**: Never use the `with` statement in top-level or global scopes as it pollutes the namespace and makes tracing variables difficult. If you must use it, restrict it to small, localized attribute sets.
  *Bad:* `with pkgs; [ wget git ]`
  *Acceptable:* Use inside `home.packages = with pkgs; [ ... ];` where scope is clear.
- **Use `inherit`**: Use `inherit` to pull variables from outer scopes cleanly.
  *Good:* `{ inherit (pkgs) lib stdenv; }`
- **Centralized Configuration**: The repository uses a unified `home.nix` for Home Manager configuration rather than split modules. When adding new programs or features, add them to the appropriate commented section in `home.nix` instead of creating new files. Keep `users.nix` purely for user-specific data variables.

### Naming Conventions
- Use `camelCase` for variables and attribute names (`homeConfigurations`, `gitUsername`, `homeDirectory`).
- Use `kebab-case` for file names and derivations/packages (`flake-utils`, `home-manager`).

### Types and Type Checking
Nix is dynamically typed, but Home Manager relies heavily on the module system, which validates types during evaluation.
- Respect Home Manager's strict typing for options. E.g., if an option expects a string, do not pass a path directly; convert it using `builtins.toString` or interpolation `${ }` if necessary.

### Error Handling & Debugging
- Use `builtins.trace` or `lib.warn` sparingly during development to output intermediate values for debugging, but *ensure these are removed before finalizing code*.
- Handle missing variables gracefully using default values or logical conditionals.

### Paths and Strings
- **Paths vs Strings**: Unquoted relative paths like `./file.txt` resolve to path types and are imported into the Nix store. If you only want the string path, use `"${./file.txt}"` or `toString ./file.txt`.
- **Multi-line Strings**: Use two single quotes `''` for multi-line strings. This is especially useful for embedding bash scripts or config files.
  ```nix
  extraConfig = ''
    set -g mouse on
    bind h select-pane -L
  '';
  ```
  Note: Escape Nix variables inside multi-line strings with `'''${var}` if you want literal string output, otherwise use `${var}` for evaluation interpolation.

---

## 4. Agent Operational Directives

1. **Verify Before Editing**: Use the `read` tool to check the current state of `flake.nix`, `home.nix`, and `users.nix` before making adjustments.
2. **Path Construction**: Always use absolute paths (relative to the workspace root) for all file system tools (e.g., `/var/home/aikoh/devbox-home/nix/home.nix`).
3. **Analyze Dependencies**: When adding a new package, check `nixpkgs` availability. If a specific version is requested, check the `overlays/` directory.
4. **Iterative Checking**: When refactoring or making changes, always run `nix-instantiate --parse <file>` followed by `nix flake check` or a single dry-run build (`nix build .#homeConfigurations.<user>.activationPackage --dry-run`) to incrementally prove validity.
5. **Configuration Modifications**: Modify the structure within `home.nix` respectfully. Sections are clearly marked with comment headers (e.g., `# CLI Tools & Utilities`). Place additions logically.

Thank you for maintaining a clean, declarative, and robust configuration!
