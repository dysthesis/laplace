install HOST DISK:
  sudo nix run 'github:nix-community/disko/latest#disko-install' -- \
    --flake .#{{HOST}} \
    --disk main {{DISK}}
