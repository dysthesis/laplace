default:
  @just --list

check:
  git add *; nix fmt; nix flake check;

update:
  nix flake update --commit-lock-file

test config:
  nix run github:nix-community/nixos-anywhere -- --disk-encryption-keys /tmp/luks.key <(PASSWORD_STORE_DIR=~/.local/share/password-store pass luks/{{config}}) --flake .#{{config}} --vm-test

install config ip:
  nix run github:nix-community/nixos-anywhere -- --disk-encryption-keys /tmp/luks.key <(PASSWORD_STORE_DIR=~/.local/share/password-store pass luks/{{config}}) --flake .#{{config}} root@{{ip}}
