{
  lib,
  pkgs,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
  inherit (pkgs) writeText;

  # No secret lands in the Nix store: the Radicale password is fetched at runtime
  # from the sops-managed /run/secrets/khal_caldav (declared in system/secrets,
  # owner = demiurge). `username` is the Radicale htpasswd account; change it here
  # if it isn't "demiurge".
  config = writeText "vdirsyncer-config" ''
    [general]
    status_path = "~/.local/share/vdirsyncer/status/"

    [pair calendar]
    a = "local"
    b = "remote"
    collections = ["from a", "from b"]
    metadata = ["displayname", "color"]

    [storage local]
    type = "filesystem"
    path = "~/.local/share/calendars/"
    fileext = ".ics"

    [storage remote]
    type = "caldav"
    url = "https://cal.dysthesis.com/"
    username = "demiurge"
    password.fetch = ["command", "cat", "/run/secrets/khal_caldav"]
  '';
in
  mkWrapper pkgs.unstable pkgs.unstable.vdirsyncer {set.VDIRSYNCER_CONFIG = config;}
