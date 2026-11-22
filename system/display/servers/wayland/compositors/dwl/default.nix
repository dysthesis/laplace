{
  name = "dwl";
  protocol = "wayland";
  configure = {
    inputs,
    lib,
    pkgs,
    ...
  }: let
    system = pkgs.stdenv.hostPlatform.system;
    login = pkgs.writeShellScript "dwl-session" ''
      	  dbus-update-activation-environment --systemd \
      	    WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
          ${lib.escapeShellArgs [(lib.getExe' inputs.status.packages.${system}.default "status")]} | ${lib.escapeShellArgs [(lib.getExe' pkgs.configured.dwl "dwl")]}
    '';
  in {
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
