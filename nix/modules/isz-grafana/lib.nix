{ config, pkgs, lib, ... }:
rec {
  dashboardFormat = pkgs.formats.json {};
  fluxValue = with builtins; v:
    if isList v then ''[${lib.concatMapStringsSep ", " fluxValue v}]''
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
  toProperties = with builtins; with lib; attrs:
    (removeAttrs attrs ["custom"]) //
    (mapAttrs' (k: nameValuePair "custom.${k}") (attrs.custom or {}));
}
