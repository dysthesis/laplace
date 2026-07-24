{
  lib,
  config,
  ...
}: {
  imports = [
    (lib.laplace.modules.mkSelector {
      dir = ./.;
      option = ["laplace" "display" "servers"];
      description = "Which display servers to enable";
    })
  ];

  # Selected sessions contribute their own validation commands.
  options.laplace.display.checkCommands = lib.mkOption {
    type = lib.types.listOf lib.types.lines;
    default = [];
    internal = true;
    description = "Validation snippets run by the flake's desktop-stack check.";
  };

  config = lib.mkIf (config.laplace.display.servers != []) {
    location = {
      latitude = 33.9;
      longitude = 151.2;
    };
  };
}
