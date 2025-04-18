{ writeShellApplication
, iproute2
}:
writeShellApplication {
  name = "vpnc-script-container";
  runtimeEnv = {
    IP = "${iproute2}/bin/ip";
  };
  text = builtins.readFile ./vpnc-script-container.bash;
}
