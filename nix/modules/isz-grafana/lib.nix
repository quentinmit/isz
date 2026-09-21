{ config, pkgs, lib, ... }:
rec {
  dashboardFormat = pkgs.formats.json {};
  literalExpressionType = with lib.types; mkOptionType {
    name = "literalExpression";
    description = "literal expression";
    descriptionClass = "noun";
    check = isType "literalExpression";
    merge = lib.mergeEqualOption;
  };
  fluxValue = with builtins; v:
    if v._type or "" == "literalExpression" then v.text
    else if isList v then ''[${lib.concatMapStringsSep ", " fluxValue v}]''
    else if isInt v || isFloat v then toString v
    else if isString v then ''"${lib.escape [''"''] v}"''
    else if true == v then "true"
    else if false == v then "false"
    else abort "Unknown type";
  fluxFilter = with builtins; field: v:
    lib.concatMapStringsSep
      (if v.op == "!=" || v.op == "!~" then " and " else " or ")
      (value: ''r[${fluxValue field}] ${v.op} ${if v.op == "=~" || v.op == "!~" then "/${value}/" else fluxValue value}'')
      v.values
  ;
  sqlIdentifier = i:
    if i._type or "" == "literalExpression" then i.text
    else "\"${lib.replaceString "\"" "\"\"" i}\"";
  sqlValue = with builtins; v:
    if v._type or "" == "literalExpression" then v.text
    else if isList v then ''(${lib.concatMapStringsSep ", " fluxValue v})''
    else if isInt v || isFloat v then toString v
    else if isString v then "'${lib.replaceString "'" "''" v}'"
    else if true == v then "true"
    else if false == v then "false"
    else abort "Unknown type";
  sqlFilter = with builtins; field: v:
    lib.concatMapStringsSep
      (if v.op == "!=" then " and " else " or ")
      (value: if value == null then "${sqlIdentifier field} IS ${lib.optionalString (v.op == "!=") "NOT "}NULL" else ''${sqlIdentifier field} ${v.op} ${sqlValue value}'')
      v.values
  ;

  toPropertiesAttrs = with builtins; with lib; attrs:
    (removeAttrs attrs ["custom"]) //
    (mapAttrs' (k: nameValuePair "custom.${k}") (attrs.custom or {}));
  toProperties = options: lib.mapAttrsToList (id: value: {
    inherit id value;
  }) (toPropertiesAttrs options);
}
