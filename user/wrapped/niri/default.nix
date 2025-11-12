{
  pkgs,
  lib,
  config,
  niri ? pkgs.niri,
  ...
}:
let
  inherit (lib.babel.pkgs) mkWrapper;
  configPath =
    import ./config {
      inherit pkgs lib config;
    };
in
mkWrapper pkgs niri ''
  wrapProgram $out/bin/niri \
    --set NIRI_CONFIG ${configPath} \
    --add-flags "--config ${configPath}"
  if [ -x "$out/bin/niri-session" ]; then
    wrapProgram $out/bin/niri-session \
      --set NIRI_CONFIG ${configPath}
  fi
''
