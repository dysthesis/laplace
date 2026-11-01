{
  lib,
  # Use wrapper aliases as the command source.
  jjAliases,
}: let
  inherit (lib) concatMapStringsSep mapAttrsToList;

  # Actions replace @ in alias arguments with the selected change ID.
  bindKeys = {
    tug = "T";
  };

  # Alias arguments enter Lua literals without escaping. Do not use quotes or backslashes.
  mkAction = name: key: let
    argList = concatMapStringsSep ", " (arg: ''"${arg}"'') jjAliases.${name};
  in {
    name = "custom.${name}";
    desc = "jj ${name} (selected revision)";
    scope = "revisions";
    inherit key;
    lua = ''
      local args = {${argList}}
      local id = jjui.context.change_id()
      if not id then
        flash({ text = "no revision selected", error = true })
        return
      end
      for i, arg in ipairs(args) do
        args[i] = arg:gsub("@", id)
      end
      jj_async(args)
    '';
  };
in {
  suggest.exec.mode = "fuzzy";
  actions = mapAttrsToList mkAction bindKeys;
}
