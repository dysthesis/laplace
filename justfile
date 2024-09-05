default:
  @just --list

check:
  git add *; nix fmt; nix flake check;

update:
  nix flake update --commit-lock-file

install config ip:
  nix run github:nix-community/nixos-anywhere -- --disk-encryption-keys /tmp/luks.key <(pass luks/{{config}}) --flake .#{{config}} root@{{ip}}
