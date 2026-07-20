{
  lib,
  pkgs,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
  inherit (pkgs) writeText;

  # khal only reads a local vdir; vdirsyncer (see ./vdirsyncer.nix) mirrors the
  # Radicale collections into ~/.local/share/calendars, which `type = discover`
  # picks up as individual calendars.
  config = writeText "khal-config" ''
    [calendars]

    [[caldav]]
    path = ~/.local/share/calendars/*
    type = discover

    [locale]
    timeformat = %H:%M
    dateformat = %Y-%m-%d
    longdateformat = %Y-%m-%d
    datetimeformat = %Y-%m-%d %H:%M
    longdatetimeformat = %Y-%m-%d %H:%M
    firstweekday = 0
    weeknumbers = right

    [default]
    timedelta = 5d
  '';
in
  # khal ships two binaries (khal + ikhal); wrap both, so this needs raw postBuild.
  mkWrapper pkgs.unstable pkgs.unstable.khal {
    postBuild = ''
      for bin in khal ikhal; do
        wrapProgram $out/bin/$bin --add-flags "-c ${config}"
      done
    '';
  }
