{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib.babel.pkgs) mkWrapper;

  rev = "c291194a4e593bbbb91420e81fa0111508084448";
  srcHash = "sha256-LipZljhxpMFOEce+KNNcjJVWKsxDJnhgJm9UWJ4sWJI=";
  patchHash = "sha256-d9Dj/e5ejc6mbsjKdS2AfPQqTKNyKyNMwVE6QPkOSpE=";

  fcftPatched = pkgs.fcft.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      (pkgs.fetchpatch {
        url = "https://codeberg.org/dnkl/fcft/pulls/116.patch";
        hash = "sha256-juOQETratMOGMQBFM7d4aIl+1fU6FZUb/NFw/QTlw0k=";
      })
    ];
  });

  footPatched =
    (pkgs.foot.override {fcft = fcftPatched;}).overrideAttrs (old: {
      version = "master-${builtins.substring 0 7 rev}-pr2278";
      src = pkgs.fetchFromGitea {
        domain = "codeberg.org";
        owner = "dnkl";
        repo = "foot";
        rev = rev;
        hash = srcHash;
      };
      patches =
        (old.patches or [])
        ++ [
          (pkgs.fetchpatch {
            url = "https://codeberg.org/dnkl/foot/pulls/2278.patch";
            hash = patchHash;
          })
        ];
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
