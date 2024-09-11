default:
  @just --list

check:
  git add *; nix fmt; nix flake check;

update:
  nix flake update --commit-lock-file

test config:
  nix run github:nix-community/nixos-anywhere/ef708ac46d83dbf3871efc25befb9c13bd5702a8 -- --vm-test --disk-encryption-keys /tmp/luks.key <(pass luks/{{config}}) --flake .#{{config}}

install config ip:
  nix run github:nix-community/nixos-anywhere/69ad3f4a50cfb711048f54013404762c9a8e201e -- --disk-encryption-keys /tmp/luks.key <(pass luks/{{config}}) --flake .#{{config}} root@{{ip}}
