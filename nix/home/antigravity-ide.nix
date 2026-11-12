{ lib, modulesPath, ... }:
let
  modulePath = [
    "programs"
    "antigravity-ide"
  ];

  mkVscodeModule = import "${modulesPath}/programs/vscode/mkVscodeModule.nix";
in
{
  imports = [
    (mkVscodeModule {
      inherit modulePath;
      name = "Antigravity IDE";
      packageName = "antigravity-ide";
      nameShort = "Antigravity IDE";
      dataFolderName = ".antigravity-ide";
      skipVersionCheck = true;
    })
  ];
}
