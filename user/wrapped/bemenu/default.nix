{
  config,
  pkgs,
  lib,
  ...
}:
let
  bemenu = pkgs.bemenu.overrideAttrs (old: {
    patches = [
      # NOTE: This pull request enables fuzzy finding via the '-z' flag
      (pkgs.fetchpatch {
        url = "https://patch-diff.githubusercontent.com/raw/Cloudef/bemenu/pull/432.patch";
        hash = "sha256-x9y16hmqjzHhs0RzKUTytP+NgAfXNcBVDmMOSWcXL1s=";
      })
    ];
  });
  inherit (lib.babel.pkgs) mkWrapper;
  inherit (builtins) concatStringsSep;
  # Adaptive sizing based on primary monitor, similar to waybar/style.nix
  monitors = config.laplace.hardware.monitors or [ ];
  defaultMonitor =
    if monitors == [ ] then
      {
        width = 1920;
        height = 1080;
      }
    else
      builtins.head monitors;
  primaryMonitor = lib.findFirst (m: (m.primary or false)) defaultMonitor monitors;

  clamp =
    min: max: val:
    lib.max min (lib.min max val);
  round = x: builtins.floor (x + 0.5);

  hostName = config.networking.hostName or "";
  baselineH = 1080.0;
  rawScale = baselineH / (primaryMonitor.height or baselineH);
  scale = clamp 0.6 1.2 rawScale;

  baseFont = if hostName == "phobos" then 12.0 else 9.0;
  fontLineRatio = 24.0 / 9.0;
  fontPaddingRatio = 8.0 / 9.0;
  baseLineH = baseFont * fontLineRatio;
  baseHP = baseFont * fontPaddingRatio;

  fontSize = round (baseFont * scale);
  lineHeight = round (baseLineH * scale);
  hp = lib.max 1 (round (baseHP * scale));

  flags = [
    "-b" # bottom
    ''-z'' # fuzzy
    ''-i'' # ignorecase
    ''-p \" \"'' # prompt
    ''--fn \"JBMono Nerd Font ${toString fontSize}\"''
    ''-H \"${toString lineHeight}\"''
    ''--hp \"${toString hp}\"''
    ''--fb \"#000000\"''
    ''--ff \"#ffffff\"''
    ''--nb \"#000000\"''
    ''--nf \"#ffffff\"''
    ''--tb \"#7788AA\"''
    ''--hb \"#080808\"''
    ''--tf \"#000000\"''
    ''--hf \"#7788AA\"''
    ''--ab \"#000000\"''
  ];
  flags' = flags |> map (flag: ''--add-flags "${flag}"'') |> concatStringsSep " ";
in
mkWrapper pkgs bemenu
  # sh
  ''
    for file in $out/bin/*; do
      wrapProgram $file ${flags'}
    done
  ''
