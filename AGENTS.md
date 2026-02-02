# Repository Guidelines

## Project Structure & Module Organization
- `flake.nix` is the flake entrypoint; `flake.lock`/`npins/` pin dependencies.
- `hosts/<hostname>/` contains NixOS configs per machine (`chaos`, `phobos`, `deimos`, `erebus`) plus `hosts/README.md` with remote-install notes.
- `modules/` holds custom modules (`ariadne` for home symlinks, `mnemosyne` for persistence) and `modules/default.nix` that imports them.
- `system/` groups shared NixOS modules by concern (`boot/`, `network/`, `services/`, `security/`, etc.); `system/default.nix` wires common defaults.
- `user/` defines user-level packages/wrappers (git, gnupg, gtk, scripts, wallpapers); `nix/` contains the dev shell and formatter config; `assets/` stores shared media (e.g., `assets/wallpaper.png`).

## Build, Test, and Development Commands
- `nix develop` — enter the dev shell with alejandra, statix, deadnix, shfmt, just, sops, etc.
- `nix fmt` — run treefmt (alejandra + shfmt indent 4 + prettier + toml-sort + deadnix) over the repo.
- `nix flake check` — fast pre-flight check; currently runs the formatting check.
- `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` — compile a host config without switching (e.g., `<host>=chaos`).
- `just rebuild` — apply the configuration on the local machine via `nh os switch`.
- Remote install: `nix run .#install-<hostname> -- --target-host root@1.2.3.4` (set `FLAKE_REF=…` to pin a revision; `LUKS_PASSWORD_FILE=…` to reuse an existing key).
- Images: `just image /dev/sdX PROFILE=chaos|erebus` writes installer/SD media; destructive and requires sudo.
- Cleanup: `just clean` prunes common build outputs (`core`, `result`, `out`, `test`).

## Coding Style & Naming Conventions
- Nix: 2-space indent; keep modules small and imported via `lib.babel.modules.importInDirectory`; prefer attribute sets over long lets.
- Shell: POSIX `sh` with shfmt 4-space indent; avoid bash-only features unless the shebang is `bash`.
- Filenames and hostnames stay lower-case/kebab where applicable; module names mirror their directory (`ariadne`, `mnemosyne`).
- Always run `nix fmt` before committing; fix `deadnix`/`statix` warnings when they appear.

## Testing Guidelines
- Baseline: `nix flake check` plus at least one host build for touched modules.
- For service changes, run `nixos-rebuild test` or `nh os test` locally and note the command in your PR.
- Keep secrets out of the tree; use `sops-nix` or environment files, never commit plaintext keys or sample LUKS files.

## Commit & Pull Request Guidelines
- Commit subjects follow `scope: summary` in present tense (e.g., `flake.lock: Update`); keep to ~72 characters and separate lock bumps from functional changes.
- PRs should include: concise summary, affected hosts/modules, commands run (`nix fmt`, `nix flake check`, build/switch commands), and linked issues; add screenshots only when UI assets change.
- Do not commit build outputs (`result`, `out`) or crash dumps (`core`); ensure `.gitignore` remains respected.
