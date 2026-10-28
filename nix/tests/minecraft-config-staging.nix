{
  pkgs,
  inputs,
}:
pkgs.testers.runNixOSTest {
  name = "minecraft-config-staging";
  node.pkgsReadOnly = false;
  nodes.machine = {
    lib,
    pkgs,
    ...
  }: {
    imports = [
      ({
        config,
        lib,
        pkgs,
        ...
      }:
        import ../../system/services/minecraft {inherit config lib pkgs inputs;})
    ];
    options.mnemosyne.dirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
    };
    config = {
      nixpkgs.overlays = [inputs.nix-minecraft.overlay];
      nixpkgs.config.allowUnfree = true;
      environment.systemPackages = [pkgs.netcat-openbsd];
      virtualisation = {
        memorySize = 2048;
        cores = 2;
      };
      laplace.services.minecraft.retirement-home = {
        enable = true;
        autoStart = true;
        openFirewall = true;
        memoryGb = 1;
        motd = "Original";
        viewDistance = 2;
        simulationDistance = 2;
      };
      # Exercise the real JVM and upstream start/stop/property staging without
      # downloading the production modpack or needing Discord credentials.
      services.minecraft-servers.servers.retirement-home = {
        package = lib.mkForce (pkgs.vanillaServers.vanilla-1_20_1.override {
          jre_headless = pkgs.temurin-bin-17;
        });
        symlinks = lib.mkForce {};
        files = lib.mkForce {};
        serverProperties.online-mode = lib.mkForce false;
      };
      systemd.timers = {
        mc-world-snapshot.enable = false;
        mc-nightly-restart.enable = false;
      };
      specialisation = {
        staged.configuration.laplace.services.minecraft.retirement-home.motd = lib.mkForce "Staged";
        moved.configuration.laplace.services.minecraft.retirement-home = {
          motd = lib.mkForce "Moved";
          port = lib.mkForce 25566;
        };
      };
    };
  };
  testScript = ''
    start_all()
    unit = "minecraft-server-retirement-home.service"
    properties = "/srv/minecraft/retirement-home/server.properties"
    machine.wait_for_unit(unit)
    machine.wait_for_open_port(25565)
    base = machine.succeed("readlink -f /run/current-system").strip()
    staged = base + "/specialisation/staged"
    moved = base + "/specialisation/moved"
    invocation = machine.succeed(f"systemctl show {unit} --property=InvocationID --value")

    with subtest("content stays staged without restarting or rewriting live properties"):
        machine.succeed(f"{staged}/bin/switch-to-configuration switch")
        assert machine.succeed(f"systemctl show {unit} --property=InvocationID --value") == invocation
        machine.succeed(f"grep -Fx 'motd=Original' {properties}")
        machine.wait_for_open_port(25565)
        staged_system = machine.succeed("readlink -f /run/current-system").strip()

    with subtest("port change fails before activation while the old JVM is running"):
        machine.fail(f"{moved}/bin/switch-to-configuration switch")
        assert machine.succeed("readlink -f /run/current-system").strip() == staged_system
        assert machine.succeed(f"systemctl show {unit} --property=InvocationID --value") == invocation
        machine.wait_for_open_port(25565)
        machine.fail("nc -z 127.0.0.1 25566")

    with subtest("explicit maintenance advances the JVM and its listener together"):
        machine.succeed(f"systemctl stop {unit}")
        machine.wait_until_fails("nc -z 127.0.0.1 25565")
        machine.succeed(f"{moved}/bin/switch-to-configuration switch")
        machine.wait_for_unit(unit)
        machine.wait_for_open_port(25566)
        machine.fail("nc -z 127.0.0.1 25565")
        machine.succeed(f"grep -Fx 'motd=Moved' {properties}")
        machine.succeed(f"grep -Fx 'server-port=25566' {properties}")
        assert machine.succeed(f"systemctl show {unit} --property=InvocationID --value") != invocation
  '';
}
