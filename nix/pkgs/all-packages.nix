self: pkgs:

with pkgs;

{
  rtlamr = callPackage ./rtlamr {};
  rtlamr-collect = callPackage ./rtlamr-collect {};
}
