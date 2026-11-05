{
  protocol = "wayland";
  module = {
    inputs,
    lib,
    pkgs,
    ...
  }: let
    system = pkgs.stdenv.hostPlatform.system;
    login = pkgs.writeShellScript "dwl-session" ''
      ${lib.escapeShellArgs [(lib.getExe' inputs.status.packages.${system}.default "status")]} | ${lib.escapeShellArgs [(lib.getExe' pkgs.configured.dwl "dwl")]}
    '';
  in {
    imports = [../../../legacy.nix];
    laplace.wm = {
      protocol = "wayland";
      login = ["${login}"];
    };
    laplace.display.checkCommands = [
      ''
        test -x ${lib.getExe' pkgs.configured.dwl "dwl"}
      ''
    ];
  };
}
