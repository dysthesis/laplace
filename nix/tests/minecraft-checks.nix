{
  pkgs,
  lib,
  inputs,
  serviceFixtures,
}: {
  minecraft-maintenance = let
    services = serviceFixtures.minecraft.systemd.services;
    snapshot = pkgs.writeText "mc-world-snapshot.sh" services.mc-world-snapshot.script;
    restart = pkgs.writeText "mc-nightly-restart.sh" services.mc-nightly-restart.script;
  in
    pkgs.runCommand "minecraft-maintenance-check" {nativeBuildInputs = [pkgs.bash];} ''
      bash -n ${snapshot}
      bash -n ${restart}
      touch $out
    '';

  minecraft-runtime = let
    runtime = pkgs.jdk25_headless;
    server = serviceFixtures.minecraft.services.minecraft-servers.servers.retirement-home;
  in
    assert server.enable;
    assert lib.versionAtLeast runtime.version "25";
      pkgs.runCommand "minecraft-runtime-check" {} ''
        ${runtime}/bin/java -Xms128M -Xmx256M -version >java-version 2>&1
        grep -Eq 'version "25[."]' java-version
        touch $out
      '';

  minecraft-config-staging = import ./minecraft-config-staging.nix {
    inherit pkgs inputs;
  };
}
