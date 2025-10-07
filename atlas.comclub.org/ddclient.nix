{ config, ... }:
{
  sops.secrets."ddclient/login" = {};
  sops.secrets."ddclient/password" = {};
  # FIXME: Enable exec
  sops.templates."ddclient.conf".content = ''
    exec=no
    cache=/var/lib/ddclient/ddclient.cache
    foreground=YES
    usev4=ifv4
    ifv4=eth0
    login=${config.sops.placeholder."ddclient/login"}
    password=${config.sops.placeholder."ddclient/password"}
    protocol=dyndns2
    server=members.dyndns.org
    ssl=true
    mail=root@comclub.org
    mail-failure=quentins@comclub.org
    wildcard=yes comclub.dyndns.org theposers.kicks-ass.org
    comclub.org,hb-rights.org,win01.comclub.org,www.comclub.org,mail.comclub.org,hercules.comclub.org,chameleon.comclub.org
  '';
  services.ddclient = {
    enable = true;
    configFile = config.sops.templates."ddclient.conf".path;
  };
}
