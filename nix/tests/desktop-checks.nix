{
  pkgs,
  lib,
  nixosConfigurations,
}: {
  desktop-stack = let
    validateHost = name: host:
      lib.optionalString (host.config.laplace.display.checkCommands != []) ''
        echo "validating ${name}"
        ${lib.concatStrings host.config.laplace.display.checkCommands}
      '';
  in
    pkgs.runCommand "desktop-configs" {} ''
      ${lib.concatStrings (lib.mapAttrsToList validateHost nixosConfigurations)}
      touch $out
    '';

  niri-config = import ./niri-config.nix {
    inherit lib;
    pkgs = nixosConfigurations.deimos.pkgs;
  };

  commit-tools = import ./commit-tools.nix {
    inherit lib;
    pkgs = nixosConfigurations.deimos.pkgs;
  };

  mk-wrapper = let
    argumentCheck = pkgs.writeShellScriptBin "argument check" ''
      test "$#" -eq 2
      test "$1" = "complex command"
      test "$2" = "--literal"
    '';
    wrapped = lib.laplace.pkgs.mkWrapper pkgs argumentCheck {
      program = "argument check";
      addFlags = ["complex command" "--literal"];
    };
    bashWrapped = lib.laplace.pkgs.mkWrapper pkgs pkgs.bash {};
  in
    assert bashWrapped.meta.outputsToInstall == ["out"];
      pkgs.runCommand "mk-wrapper-check" {} ''
        "${wrapped}/bin/argument check"
        test -e ${bashWrapped}/share/man/man1/bash.1.gz
        touch $out
      '';
}
