{ config, pkgs, lib, ... }:

{
  imports = builtins.map (name: ./${name}) (
    builtins.attrNames (
      lib.filterAttrs
        (name: type: type == "regular" && name != "default.nix")
        (builtins.readDir ./.)
    )
  );
}
