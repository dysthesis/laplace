default:
  @just --list

check:
  git add *; nix fmt; nix flake check;

update:
  nix flake update --commit-lock-file
