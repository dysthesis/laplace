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

  escapeString =
    builtins.replaceStrings
    ["\\" "\"" "\n" "\r" "\t"]
    ["\\\\" "\\\"" "\\n" "\\r" "\\t"];

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
    else if value == null
    then "null"
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
    "inline"
    "args"
    "assign"
    "body"
    "children"
    "comment"
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
    then [
      (normaliseNode (value // {name = value.name or name;}))
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
      nodeName = spec.name or (throw "KDL node is missing a name");
      inline = spec.inline or false;
      args = spec.args or [];
      assignments = spec.assign or {};
      userBody = spec.body or {};
      comment = spec.comment or null;
      extraBody = removeAttrs spec specialKeys;
      childrenFromBody = bodyToNodes (userBody // extraBody);
      rawChildren = spec.children or [];
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
    else throw "KDL node spec must be an attrset, got ${toString spec}";

  normaliseNodes = map normaliseNode;
in {
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
      body
      children
      ;
    inline = false;
  };
  render = nodes:
    nodes
    |> normaliseNodes
    |> concatMapStringsSep "" (renderNode 0);
}
