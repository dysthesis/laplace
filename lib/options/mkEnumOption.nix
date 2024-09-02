lib: let
  inherit (lib) mkOption;
  inherit (lib.types) enum;
in
  elems: description:
    mkOption {
      type = enum elems;
      inherit description;
    }
