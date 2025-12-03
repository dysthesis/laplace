{lib, ...}: let
  inherit
    (lib)
    concatMap
    concatMapStringsSep
    concatStringsSep
    mapAttrsToList
    optionalString
    replicate
    ;

  indentUnit = "  ";

  escapeString = str: let
    replacements = {
      "\"" = "\\\"";
      "\\" = "\\\\";
      "\n" = "\\n";
      "\r" = "\\r";
      "\t" = "\\t";
    };
    chars = lib.stringToCharacters str;
  in
    lib.concatMapStrings (c: lib.attrByPath [c] c replacements) chars;

  renderValue = value:
    if builtins.isBool value
    then
      if value
      then "true"
      else "false"
    else if builtins.isInt value || builtins.isFloat value
    then toString value
    else if builtins.isString value
    then "\"${escapeString value}\""
    else throw "Unsupported KDL value type: ${builtins.typeOf value}";

  renderArgs = args:
    if args == []
    then ""
    else " " + concatStringsSep " " (map renderValue args);

  renderAssignments = assignments: let
    parts = mapAttrsToList (name: value: "${name}=${renderValue value}") assignments;
  in
    if parts == []
    then ""
    else " " + concatStringsSep " " parts;

  indentStr = level: concatStringsSep "" (replicate level indentUnit);

  renderNode = level: node: let
    indent = indentStr level;
    header = "${indent}${node.name}${renderArgs node.args}${renderAssignments node.assignments}";
    commentBlock = optionalString (
      node.comment != null && node.comment != ""
    ) "${indent}// ${node.comment}\n";
  in
    if node.inline || node.children == []
    then
      if node.children != []
      then throw "Inline nodes cannot have children (${node.name})"
      else "${commentBlock}${header}\n"
    else let
      body = concatMapStringsSep "" (renderNode (level + 1)) node.children;
    in "${commentBlock}${header} {\n${body}${indent}}\n";

  specialKeys = [
    "name"
    "__name"
    "inline"
    "__inline"
    "args"
    "__args"
    "assign"
    "__assign"
    "body"
    "__body"
    "children"
    "__children"
    "comment"
    "__comment"
  ];

  bodyToNodes = body: let
    entries = mapAttrsToList valueToNodes body;
  in
    concatMap (x: x) entries;

  valueToNodes = name: value:
    if value == null
    then []
    else if builtins.isList value
    then concatMap (v: valueToNodes name v) value
    else if builtins.isAttrs value
    then let
      spec =
        value
        // {
          name = lib.attrByPath ["__name"] (lib.attrByPath ["name"] name value) value;
        };
    in [
      normaliseNode
      spec
    ]
    else if builtins.isBool value
    then
      if value
      then [
        {
          inherit name;
          inline = true;
          args = [];
          assignments = {};
          children = [];
          comment = null;
        }
      ]
      else []
    else [
      {
        inherit name;
        inline = true;
        args = [value];
        assignments = {};
        children = [];
        comment = null;
      }
    ];

  normaliseNode = spec:
    if builtins.isAttrs spec
    then let
      nodeName =
        if spec ? name
        then spec.name
        else if spec ? __name
        then spec.__name
        else throw "KDL node is missing a name";

      inline = lib.attrByPath ["inline"] (lib.attrByPath ["__inline"] false spec) spec;

      args = lib.attrByPath ["args"] (lib.attrByPath ["__args"] [] spec) spec;
      assignments = lib.attrByPath ["assign"] (lib.attrByPath ["__assign"] {} spec) spec;
      userBody = lib.attrByPath ["body"] (lib.attrByPath ["__body"] {} spec) spec;
      comment = lib.attrByPath ["comment"] (lib.attrByPath ["__comment"] null spec) spec;
      extraBody = builtins.removeAttrs spec specialKeys;
      childrenFromBody = bodyToNodes (userBody // extraBody);
      rawChildren = lib.attrByPath ["children"] (lib.attrByPath ["__children"] [] spec) spec;
      childNodes = childrenFromBody ++ map normaliseNode rawChildren;
    in {
      inherit
        inline
        args
        assignments
        comment
        ;
      name = nodeName;
      children = childNodes;
    }
    else throw "KDL node spec must be an attrset, got ${builtins.toString spec}";

  normaliseNodes = map normaliseNode;
in {
  node = attrs: attrs;
  statement = {
    name,
    args ? [],
    assign ? {},
    comment ? null,
  }: {
    inherit
      name
      args
      comment
      assign
      ;
    inline = true;
  };
  block = {
    name,
    args ? [],
    assign ? {},
    body ? {},
    children ? [],
    comment ? null,
  }: {
    inherit
      name
      args
      comment
      assign
      ;
    inline = false;
    __body = body;
    __children = children;
  };
  render = nodes: nodes |> normaliseNodes |> concatMapStringsSep "" (renderNode 0);
  inherit renderNode;
}
