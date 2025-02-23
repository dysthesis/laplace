{
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mapAttrsToList;
  inherit (lib.strings) concatStringsSep;
  inherit (lib.babel.pkgs) mkWrapper;
  inherit (pkgs)
    anime4k
    writeText
    ;

  low1k = import ./low1k.nix { inherit anime4k; };
  low1kParsed =
    low1k 
		|> mapAttrsToList (k: v: "${k} ${v}") 
		|> concatStringsSep "\n" 
		|> writeText "inputs.conf"
		;

  mpv = pkgs.mpv.override {
    scripts = builtins.attrValues {
      inherit (pkgs.mpvScripts)
        sponsorblock
        thumbfast
        mpv-webm
        uosc
        ;
    };
  };
  config = pkgs.stdenv.mkDerivation (finalAttrs: {
    pname = "mpv-config";
    version = "0.0.1";

    src = ./config;
    buildPhase =
        # sh
        ''
                  mkdir -p $out/
                  cp -r $src/* $out/
          				cp ${low1kParsed} $out/input.conf
        '';
  });
in
mkWrapper pkgs mpv ''
  wrapProgram $out/bin/mpv \
   --add-flags '--config-dir=${config}'
''
