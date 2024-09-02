lib: let
  inherit (lib) mkOption;
  inherit (lib.types) enum;

  mkIf = cond: value:
    if cond
    then value
    else {};
in
  {
    elems,
    description,
    default ? null,
    ...
  }:
    mkOption {
      type = enum elems;
      inherit description;
    }
    // mkIf (default != null) {
      inherit default;
    }
