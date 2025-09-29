{ lib, ... }:
{
  users.users = {
    quentin = {
      isNormalUser = true;
      description = "Quentin Smith";
      extraGroups = [
        "wheel"
        "adm"
        "dialout"
        "video"
        "plugdev"
        "wireshark"
      ];
    };
    ginas = {
      isNormalUser = true;
      description = "Gina Smith";
    };
    phillips = {
      isNormalUser = true;
      description = "Phillip Smith";
    };
  };
}
