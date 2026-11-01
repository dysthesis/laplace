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
    runtime = pkgs.temurin-bin-17;
    minecraft = serviceFixtures.minecraft.laplace.services.minecraft.retirement-home;
    server = serviceFixtures.minecraft.services.minecraft-servers.servers.retirement-home;
    # Keep production Xmx for G1 heap sizing. Set a low Xms to decrease AlwaysPreTouch memory use in CI.
    smokeJvmOpts = builtins.replaceStrings ["-Xms${toString minecraft.memoryGb}G"] ["-Xms128M"] server.jvmOpts;
  in
    assert lib.versionAtLeast runtime.version "17.0.19";
    assert lib.versionOlder runtime.version "18";
      pkgs.runCommand "minecraft-runtime-check" {} ''
        ${runtime}/bin/java ${smokeJvmOpts} -version >java-version 2>&1
        grep -Fq 'Temurin-17.' java-version
        touch $out
      '';

  minecraft-config-staging = import ./minecraft-config-staging.nix {
    inherit pkgs inputs;
  };
}
