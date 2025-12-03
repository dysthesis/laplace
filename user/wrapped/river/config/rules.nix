{lib, ...}: let
  inherit
    (lib)
    mapAttrsToList
    mapAttrs
    map
    foldl
    ;
  inherit
    (builtins)
    concatLists
    ;
  rules = {
    title = foldl (acc: curr: acc // {${curr} = "float";}) {} [
      "Open As"
      "Open File"
      "Open Folder"
      "Open"
      "Save As"
      "Save File"
      "Save Folder"
      "Save"
    ];
  };
  mkSingleConfig = key: value: ''"${key}" ${value}'';
  mkRules = rules:
    rules
    |> mapAttrs (_key: value: mapAttrsToList mkSingleConfig value)
    |> mapAttrsToList (key: value: map (val: "-${key} ${val}") value)
    |> concatLists;
in
  mkRules rules
