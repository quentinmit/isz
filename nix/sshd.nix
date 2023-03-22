{ lib, pkgs, config, ... }:
let
  cfg = config.isz.openssh;
in
{
  options = with lib; {
    isz.openssh = {
      hostKeyTypes = mkOption {
        default = [ "ecdsa" "ed25519" ];
        type = types.list;
        description = "Host key types to generate/load";
      };
      useSops = mkEnableOption "use sops";
    };
  };
  config = {
    services.openssh.hostKeys = map (t: { type = t; path = "/etc/ssh/ssh_host_${t}_key"; }) cfg.hostKeyTypes;
    sops.secrets = mkIf cfg.useSops (
      listToAttrs (
        map (t: { name = "ssh_host_keys/${t}"; value = { path = "/etc/ssh/ssh_host_${t}_key"; }; }) cfg.hostKeyTypes
      )
    );

    users.users."root".openssh.authorizedKeys.keys = [
      "ssh-dss AAAAB3NzaC1kc3MAAACBAKkmA85sGJjOMkH0lYj1apiCyvyBtKYJcM3sBn4lBrDV59E1FzgE2SvNnysgHVjVJtrqzt9AbYShDggAOgH3uSoc8wppETurUeTTiS59Y0WzWIHNTEAcsKvQw+2Zj3pU0vYU01cUhm2iV9Cw49gf7VwRtCoavVzsQaHMDWq4vMbpAAAAFQCtpPp74y1vTh14Z8I4/bO1/kWCNwAAAIBGCm5M6envG4iojPor4gXAIsZdlHVK/RNSl6jmisuMnx8a/e8H45LCBmEDYY7px8sSgSt85x6p6qd2UsPI1vHxd945PTKjbpiRNoCifKEBdKLVueYo2jlBIgKRYKJ4oMvyxFGuzaaMokO2AVlmeFjnQF4qIV6G2PhRIJ6+l+j3qAAAAIEAi5F+CBVmOvwazgI9aDmNXr+29Y6L7QW4EmA0pFiQG/aPhI37SeaArf7+/v2XSZMzqNa2VNiu8pDCUngU5YdZLb5DoHTSx4W5j3hgT5ken4WYd8SxxA5A/PEzLbZcEBiml5EN3EA/yymtyv34CzV5waOvyg80khraulngix5r2sY= quentins@209.177.24.26.dhcp.lightlink.com"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCUtRBFYPQ0OicLdAVNJih4JZp0JsGnKM/jRnG4GzGGW/bvNYtcNRCNWKHkMKAZvHSxLw8H3UVDDpyYWPnCw75rSR9aAIOVMAa4ScQyBKPvPNEM55XQT+AW8oapeSDkVrvhxJpLf8vCBz0jx15meQgQm9T/CnmHnigojcGbxtwe8znL2VQoZZnrd9KW69a94CEQuJZAKIur0Y00NoMuZYhgRFQMmuxXlqlwJSohTPHziHUxLpp/oqHnwh6er7bZwHfw7pBwSrwOyd4z4P1uWwJf2G0ShpVR07HtTtHLWIR+08ms0MiRpkgdPNFc4M9vlG4ZwOUVEuyJbJIj9VZIssLehKXXvOFj6nFqGTgMfflxd5vuS4bPJd2wRJymi+LXFMZcrg/8q8+6FJqUlp46hC3gR8iYQpLHQ4vpZgjNXncm5hAJsKDzQMrpHHkjR4jMibqsSMTHFNdXgzu4lZ2U/bxz33dEA/hOWmoWKK+zh6fjtRdMgT2ygnbVCrDtRW8zlmD4g88c1a02slOnK4tnM8XQ8xHP+n6cGfrwM1vCpNtxGWTrt+DvfTLhJhB74VTNYc4cLAQQf1d+k+wjjreswMCmLC8scmoyRqkhvEqatoRqQaeo9DG8OTUSZnmezZX4r5cF+fOsKbFRzAwKDBQqeA8oW6egTVNNxpQDOBUrrlopCw== quentin@GREEN-SEVEN-FIFTY.MIT.EDU"
      "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAsGMP08Nq2dliWfi3WnODNuaOrRUNuRegwC81atTgeNSndkYsgCXEPthiDrjRd2vpM06R4sMLAPUmvXQyEr8QqR+TUwrJq2eghhBycNXChXdPd9ahaSMsWReoyyRqc32OPidF6p/t9Rd+SAAAF6a+skcoV8Nu1HgGwMNe7ByuOub6HGTdvTo13PTuAlugcEhDfakaMkxZ41kXQbT5xPOWhKQY2vfZaC35gd86rPqM9Ols+4wEaByFXijsbWmEOr4wJmOfe4hWnO9sQFsC9oOrFBRd/XipQnMg522cepIY7nVMPi5UDYEe8O5dgs+7GrIKxWcwzdglBgE0nYp8xp6BDw== quentin@quentin-macbookpro.cam.corp.google.com"
    ];
  };
}

