{ config, lib, ... }:
{
  options = with lib; {
    isz.krb5.enable = mkEnableOption "ISZ Kerberos 5 configuration";
  };
  config = lib.mkIf config.isz.krb5.enable {
    security.pam.krb5.enable = false;
    security.krb5 = {
      enable = true;
      settings.libdefaults.default_realm = "ATHENA.MIT.EDU";
      settings.realms = {
        "ATHENA.MIT.EDU" = {
          admin_server = "kerberos.mit.edu";
          default_domain = "mit.edu";
          kdc = [
            "kerberos.mit.edu:88"
            "kerberos-1.mit.edu:88"
            "kerberos-2.mit.edu:88"
          ];
        };
        "ZONE.MIT.EDU" = {
          admin_server = "casio.mit.edu";
          kdc = [
            "casio.mit.edu"
            "seiko.mit.edu"
          ];
        };
      };
      settings.domain_realm = {
        "exchange.mit.edu" = "EXCHANGE.MIT.EDU";
        "mit.edu" = "ATHENA.MIT.EDU";
        "win.mit.edu" = "WIN.MIT.EDU";
        "csail.mit.edu" = "CSAIL.MIT.EDU";
        "media.mit.edu" = "MEDIA-LAB.MIT.EDU";
        "whoi.edu" = "ATHENA.MIT.EDU";
      };
    };
  };
}
