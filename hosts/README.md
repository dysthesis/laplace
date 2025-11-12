# Hosts

| Hostname | Device                               |
| -------- | ------------------------------------ |
| Phobos   | Framework 13, Ryzen 5 7640U          |
| Deimos   | PC, Ryzen 7 5800X, Radeon RX 6650 XT |
| Erebus   | Raspberry Pi                         |
| Chaos    | Installer ISO                        |

## Remote installation

- Enter the repo and run `nix run .#install-<hostname> -- --target-host root@IP`. Replace `hostname` with one from the table above.
- The wrapper calls `nixos-anywhere` so any of its arguments (disk profiles, `--extra-files`, etc.) can follow the `--`.
- A [`gum`](https://github.com/charmbracelet/gum) password prompt appears before the install kicks off; the answer is written to a `mktemp` file, uploaded as `/tmp/luks.key`, and then deleted on exit. Provide `LUKS_PASSWORD_FILE=/path/to/key` to skip the prompt.
- Set `FLAKE_REF` if you need to install from a remote Git revision or alternate flake reference.
