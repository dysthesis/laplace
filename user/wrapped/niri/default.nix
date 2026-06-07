{
  pkgs,
  lib,
  config,
  niri ? pkgs.niri,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
  configPath = import ./config {
    inherit pkgs lib config;
  };
in
  mkWrapper pkgs niri ''
    wrapProgram $out/bin/niri \
      --set NIRI_CONFIG ${configPath}
    if [ -x "$out/bin/niri-session" ]; then
      wrapProgram $out/bin/niri-session \
        --set NIRI_CONFIG ${configPath}
    fi
    desktopFile="$out/share/wayland-sessions/niri.desktop"
    if [ -f "$desktopFile" ]; then
      if [ -L "$desktopFile" ]; then
        desktopTarget=$(readlink -f "$desktopFile")
        rm "$desktopFile"
        cp "$desktopTarget" "$desktopFile"
      fi
      substituteInPlace "$desktopFile" \
        --replace-fail 'Exec=niri-session' "Exec=$out/bin/niri-session"
    fi
    serviceFile="$out/share/systemd/user/niri.service"
    if [ -f "$serviceFile" ]; then
      if [ -L "$serviceFile" ]; then
        serviceTarget=$(readlink -f "$serviceFile")
        rm "$serviceFile"
        cp "$serviceTarget" "$serviceFile"
      fi
      substituteInPlace "$serviceFile" \
        --replace-fail 'ExecStart=${niri}/bin/niri --session' "ExecStart=$out/bin/niri --session"
    fi
  ''
