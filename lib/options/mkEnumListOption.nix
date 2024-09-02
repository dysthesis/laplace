lib: let
  inherit (lib) mkOption;
  inherit (lib.types) listOf enum;

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
      type = listOf (enum elems);
      inherit description;
    }
    // mkIf (default != null) {
      inherit default;
    }
