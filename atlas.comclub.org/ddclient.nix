{ config, ... }:
{
  sops.secrets."ddclient/login" = {};
  sops.secrets."ddclient/password" = {};
  # FIXME: Enable exec
  sops.templates."ddclient.conf".content = ''
    cache=/var/lib/ddclient/ddclient.cache
    foreground=YES
    usev4=webv4
    webv4=dyndns
    login=${config.sops.placeholder."ddclient/login"}
    password=${config.sops.placeholder."ddclient/password"}
    protocol=dyndns2
    server=members.dyndns.org
    ssl=true
    mail=root@comclub.org
    mail-failure=quentins@comclub.org
    wildcard=yes comclub.dyndns.org,theposers.kicks-ass.org
    comclub.org,hb-rights.org,atlas.comclub.org,www.comclub.org,mail.comclub.org,hercules.comclub.org,chameleon.comclub.org
  '';
  services.ddclient = {
    enable = true;
    configFile = config.sops.templates."ddclient.conf".path;
  };
  systemd.services.ddclient.path = [
    # sendmail is in /run/wrappers/bin
    "/run/wrappers"
  ];
}
