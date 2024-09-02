{inputs, ...}: {
  perSystem = {
    pkgs,
    system,
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
  };
}
