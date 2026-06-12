{
  lib,
  # The `aliases` attrset from the jj wrapper's config (via its passthru),
  # so jj subcommands are defined in exactly one place.
  jjAliases,
}: let
  inherit (lib) concatMapStringsSep mapAttrsToList;

  # jj aliases surfaced as jjui actions. Each listed alias gets a key in the
  # `revisions` scope; at invocation every `@` in the alias arguments is
  # substituted with the selected revision's change id, so the action targets
  # the revision under the cursor rather than the working copy.
  bindKeys = {
    tug = "T";
  };

  # NOTE: alias arguments are spliced into Lua string literals verbatim;
  # fine for the current aliases (no quotes or backslashes).
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
