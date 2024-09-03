{inputs, ...}: {
  imports = [inputs.flake-parts.flakeModules.easyOverlay];
  perSystem = {
    pkgs,
    system,
    config,
    ...
  }: let
    personal = import ../packages pkgs;
  in {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      overlays = [
        personal
      ];
    };

    overlayAttrs = {
      inherit (config.packages) generate-domains-blocklist sf-pro;
    };
  };
}
