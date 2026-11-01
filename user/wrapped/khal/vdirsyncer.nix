{
  lib,
  pkgs,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
  inherit (pkgs) writeText;

  # Read the Radicale password from SOPS at runtime, outside the store.
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
    password.fetch = ["command", "cat", "/run/secrets/caldav"]
  '';
in
  mkWrapper pkgs.unstable pkgs.unstable.vdirsyncer {set.VDIRSYNCER_CONFIG = config;}
