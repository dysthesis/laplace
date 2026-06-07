{lib, ...}: {
  imports = [
    (lib.laplace.modules.mkSelector {
      dir = ./.;
      option = ["laplace" "sound" "server"];
      multiple = false;
      extra = ["none"];
      default = "none";
      description = "Which sound server to use";
    })
  ];

  options.laplace.sound.enable = lib.mkEnableOption "Enable sound server.";
}
