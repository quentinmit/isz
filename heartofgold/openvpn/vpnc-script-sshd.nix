{ writeShellApplication
, iproute2
, dnsmasq
, openssh
, util-linux
, nsncd
, sudo
}:
writeShellApplication {
  name = "vpnc-script-sshd";
  runtimeEnv = {
    IP = "${iproute2}/bin/ip";
    DNSMASQ = "${dnsmasq}/bin/dnsmasq";
    SSHD = "${openssh}/bin/sshd";
    NSCD = "${nsncd}/bin/nsncd";
    MOUNT = "${util-linux}/bin/mount";
    SUDO = "${sudo}/bin/sudo";
  };
  text = builtins.readFile ./vpnc-script-sshd.bash;
}
