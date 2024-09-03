{
  config,
  lib,
  ...
}: let
  inherit (lib) fold;
  cfg = config.laplace.features.docs.enable;
  setOpt = name: value: {${name}.enable = value;};
  foldFn = curr: acc: acc // (setOpt curr cfg);
  foldList = list: fold foldFn {} list;
in {
  config.documentation =
    foldList [
      "doc"
      "nixos"
      "info"
      "man"
    ]
    // {
      man.generateCaches = cfg;
    };
}
