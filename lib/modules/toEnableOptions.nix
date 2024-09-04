lib: let
  inherit (lib) mkEnableOption;
in
  desc: name: {
    ${name}.enable = mkEnableOption "${desc} ${name}";
  }
