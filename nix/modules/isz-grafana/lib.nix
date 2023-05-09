{ config, pkgs, lib, ... }:
rec {
  dashboardFormat = pkgs.formats.json {};
  fluxValue = with builtins; v:
    if isInt v || isFloat v then toString v
    else if isString v then ''"${lib.escape [''"''] v}"''
    else abort "Unknown type";
  fluxFilter = with builtins; field: v:
    lib.concatMapStringsSep
      (if v.op == "!=" || v.op == "!~" then " and " else " or ")
      (value: ''r[${fluxValue field}] ${v.op} ${if v.op == "=~" || v.op == "!~" then "/${value}/" else fluxValue value}'')
      v.values
  ;
  toProperties = with builtins; with lib; attrs:
    (removeAttrs attrs ["custom"]) //
    (mapAttrs' (k: v: nameValuePair "custom.${k}" v) (attrs.custom or {}));
}
