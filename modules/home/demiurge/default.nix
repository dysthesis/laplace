{
  # Let home-manager manage itself
  programs.home-manager.enable = true;

  home = rec {
    username = "demiurge";
    homeDirectory = "/home/${username}";
    stateVersion = "24.05";
  };
}
