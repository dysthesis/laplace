{
  perSystem = {pkgs, ...}: {
    packages = {
      inherit (pkgs) sf-pro generate-domains-blocklist georgia-fonts cartograph-nf oledppuccin-tmux;
    };
  };
}
