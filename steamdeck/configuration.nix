{ pkgs, lib, nixpkgs, self, ... }:

{
  imports = [
    "${nixpkgs}/nixos/modules/services/monitoring/telegraf.nix"
    self.nixosModules.telegraf
  ];

  config = {
    nixpkgs.hostPlatform = "x86_64-linux";
    # TODO: Merge with base/default.nix, somehow?
    networking.hostName = "steamdeck";
    networking.domain = "isz.wtf";

    isz.telegraf = {
      enable = true;
      intelRapl = true;
      amdgpu = true;
      powerSupply = true;
    };

    isz.plasma.enable = true;
    programs.plasma.shortcuts = {
      "khotkeys"."{e521ea71-a8c8-4e23-9b72-4c9ca63c6874}" = "Meta+K";
    };
    programs.plasma.configFile = {
      "kcminputrc"."Mouse"."X11LibInputXAccelProfileFlat" = true;
#       "khotkeysrc"."Data_4"."Comment" = "Comment";
#       "khotkeysrc"."Data_4"."DataCount" = 1;
#       "khotkeysrc"."Data_4"."Enabled" = true;
#       "khotkeysrc"."Data_4"."Name" = "Quentin";
#       "khotkeysrc"."Data_4"."SystemGroup" = 0;
#       "khotkeysrc"."Data_4"."Type" = "ACTION_DATA_GROUP";
#       "khotkeysrc"."Data_4Conditions"."Comment" = "";
#       "khotkeysrc"."Data_4Conditions"."ConditionsCount" = 0;
#       "khotkeysrc"."Data_4_1"."Comment" = "Comment";
#       "khotkeysrc"."Data_4_1"."Enabled" = true;
#       "khotkeysrc"."Data_4_1"."Name" = "Open Onboard";
#       "khotkeysrc"."Data_4_1"."Type" = "SIMPLE_ACTION_DATA";
#       "khotkeysrc"."Data_4_1Actions"."ActionsCount" = 1;
#       "khotkeysrc"."Data_4_1Actions0"."Arguments" = "";
#       "khotkeysrc"."Data_4_1Actions0"."Call" = "org.onboard.Onboard.Keyboard.ToggleVisible";
#       "khotkeysrc"."Data_4_1Actions0"."RemoteApp" = "org.onboard.Onboard";
#       "khotkeysrc"."Data_4_1Actions0"."RemoteObj" = "/org/onboard/Onboard/Keyboard";
#       "khotkeysrc"."Data_4_1Actions0"."Type" = "DBUS";
#       "khotkeysrc"."Data_4_1Conditions"."Comment" = "";
#       "khotkeysrc"."Data_4_1Conditions"."ConditionsCount" = 0;
#       "khotkeysrc"."Data_4_1Triggers"."Comment" = "Simple_action";
#       "khotkeysrc"."Data_4_1Triggers"."TriggersCount" = 1;
#       "khotkeysrc"."Data_4_1Triggers0"."Key" = "Meta+K";
#       "khotkeysrc"."Data_4_1Triggers0"."Type" = "SHORTCUT";
#       "khotkeysrc"."Data_4_1Triggers0"."Uuid" = "{e521ea71-a8c8-4e23-9b72-4c9ca63c6874}";
    };
  };
}
