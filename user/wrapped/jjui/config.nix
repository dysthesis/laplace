{
  lib,
  jjAliases,
}: let
  inherit (lib) concatMapStringsSep mapAttrsToList;

  bindKeys = {
    tug = "T";
  };

  # Lua literals contain unescaped alias arguments. Do not use quotes or backslashes in those arguments.
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
