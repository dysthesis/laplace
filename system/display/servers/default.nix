{
  lib,
  config,
  ...
}: {
  imports = [
    (lib.babel.modules.mkSelector {
      dir = ./.;
      option = ["laplace" "display" "servers"];
      description = "Which display servers to enable";
    })
  ];

  config = lib.mkIf (config.laplace.display.servers != []) {
    location = {
      latitude = 33.9;
      longitude = 151.2;
    };
  };
}
