{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;

  rev = "c291194a4e593bbbb91420e81fa0111508084448";
  srcHash = "sha256-LipZljhxpMFOEce+KNNcjJVWKsxDJnhgJm9UWJ4sWJI=";

  fcftPatched = pkgs.fcft.overrideAttrs (old: {
    patches =
      (old.patches or [])
      ++ [
        (pkgs.fetchpatch {
          url = "https://codeberg.org/dnkl/fcft/commit/b023dbd779bd6d7aceee09f19c8898d1084036af.patch";
          hash = "sha256-j5nB0xw5nNo8znjIVbTsW/txwnNqW/0uUZ+FrqWphog=";
        })
      ];
  });

  footPatched = (pkgs.foot.override {fcft = fcftPatched;}).overrideAttrs (old: {
    version = "master-${builtins.substring 0 7 rev}-pr2278";
    src = pkgs.fetchFromGitea {
      domain = "codeberg.org";
      owner = "dnkl";
      repo = "foot";
      inherit rev;
      hash = srcHash;
    };
    patches =
      (old.patches or [])
      ++ [
        (pkgs.fetchpatch {
          url = "https://codeberg.org/dnkl/foot/commit/4858b3db7bf8356f37393c7303f596c798d1f21c.patch";
          hash = "sha256-JodUTh50S0GT+LhyiwW3+511nRiuehe2x5k3HYDaquE=";
        })
      ];
    postPatch =
      (old.postPatch or "")
      + ''
        substituteInPlace render.c \
          --replace-fail 'term->conf->url.style !=' 'true ||' \
          --replace-fail 'term->conf->url.style,' 'UNDERLINE_SINGLE,'
      '';
    passthru = (old.passthru or {}) // {inherit rev;};
  });

  configFile = import ./config.nix {
    inherit
      config
      pkgs
      lib
      ;
  };
in
  mkWrapper pkgs footPatched ''
    wrapProgram $out/bin/foot \
      --add-flags "--config=${configFile}"
  ''
