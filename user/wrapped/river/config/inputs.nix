{lib, ...}: let
  inherit
    (lib)
    mapAttrsToList
    mapAttrs
    map
    ;
  inherit
    (builtins)
    typeOf
    toString
    concatLists
    ;
  inputConfigs = {
    "pointer-1739-52619-SYNA8004:00_06CB:CD8B_Touchpad" = {
      pointer-accel = 0.1;
      accel-profile = "adaptive";
      click-method = "clickfinger";
      drag = false;
      natural-scroll = true;
    };

    "pointer-2-10-TPPS/2_Elan_TrackPoint" = {
      pointer-accel = -0;
    };

    "pointer-1133-45085-Logitech_MX_Ergo_Multi-Device_Trackball" = {
      pointer-accel = 0.1;
      accel-profile = "adaptive";
      natural-scroll = true;
    };
  };
  mkSingleConfig = opt: value: let
    value' =
      if typeOf value == "bool"
      then
        if value
        then "enabled"
        else "disabled"
      else toString value;
  in "${opt} ${value'}";

  mkInputConfig = config:
    config
    # The value of each key (device) is now a list of strings specifying the option and value
    |> mapAttrs (_key: value: mapAttrsToList mkSingleConfig value)
    |> mapAttrsToList (key: value: map (val: "${key} ${val}") value)
    |> concatLists;
in
  mkInputConfig inputConfigs
