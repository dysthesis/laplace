{
  pkgs,
  lib,
  ...
}: let
  inherit
    (lib)
    mapAttrsToList
    getExe
    ;
  inherit
    (builtins)
    concatLists
    concatStringsSep
    typeOf
    ;

  # river does not support zwp_idle_inhibit_manager_v1.
  idle = x: ''"sh -c \"${getExe pkgs.playerctl} status || ${x}\""'';

  configs = {
    input = import ./inputs.nix {inherit lib;};
    rule-add = import ./rules.nix {inherit lib;};
    background-color = "0x080808";
    border-color-focused = "0xffffff";
    border-color-unfocused = "0x080808";
    border-width = 1;
    default-layout = "rivercarro";
  };

  mkConfig = configs:
    configs
    |> mapAttrsToList (
      key: value:
        if typeOf value == "list"
        then map (val: "riverctl ${key} ${val}") value
        else ["riverctl ${key} ${toString value}"]
    )
    |> concatLists
    |> concatStringsSep "\n";
in
  pkgs.writeShellScriptBin "river-init" ''
    ${mkConfig configs}
    ${import ./keys.nix {inherit pkgs;}}
    ${getExe pkgs.swayidle} \
      timeout 130 ${idle "${getExe pkgs.brightnessctl} s 5%"} \
      timeout 135 ${idle "${getExe pkgs.swaylock} -f"} \
      timeout 600 ${idle "systemctl suspend"} \
      before-sleep ${idle "${getExe pkgs.swaylock} -f"} \
      lock "${getExe pkgs.swaylock}" &
    ${getExe pkgs.rivercarro} -inner-gaps 8 -outer-gaps 8 -per-tag &
    ${lib.getExe pkgs.swaybg} -m fill -i ${./wallpaper.png} 2>/dev/null &
    ${pkgs.configured.dunst}/bin/dunst &
    ${pkgs.configured.yambar}/bin/yambar &
    systemctl --user start wlsunset
  ''
