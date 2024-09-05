tmpdir := `mktemp -d`

default:
  @just --list

check:
  git add *; nix fmt; nix flake check;

update:
  nix flake update --commit-lock-file

install config ip:
  install -d -m755 {{tmpdir}}/etc/secrets/age
  cp /etc/secrets/age/keys.txt {{tmpdir}}/etc/secrets/age
  chmod 600 {{tmpdir}}/etc/secrets/age/keys.txt
  nix run github:nix-community/nixos-anywhere -- --extra-files {{tmpdir}} --flake .#{{config}} root@{{ip}}
  rm -rf {{tmpdir}}
