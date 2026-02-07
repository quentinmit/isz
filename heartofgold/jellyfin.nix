{ config, pkgs, lib, ... }:
{
  services.jellyfin = {
    enable = true;
# TODO: Implement declarative configuration
#     config.BrandingOptions.LoginDisclaimer = ''
#       <form action="https://jellyfin.isz.wtf/sso/OID/start/ISZ">
#         <button class="raised block emby-button button-submit">
#           Sign in with SSO
#         </button>
#       </form>
#     '';
#     config.NetworkConfiguration = {
#       LocalNetworkSubnets = [
#         "172.30.96.0/22"
#       ];
#       KnownProxies = [
#         "127.0.0.1"
#         "172.30.96.32"
#         "172.30.97.32"
#       ];
#     };
#     config.ServerConfiguration = {
#       ServerName = config.networking.hostName;
#     };
#     pluginConfig.SSO-Auth.OIDConfigs.ISZ.PluginConfiguration = {
#       OidEndpoint = "https://auth.isz.wtf/application/o/jellyfin/";
#       OidClientId = FIXME;
#       OidSecret = FIXME;
#       Enabled = true;
#       EnableAuthorization = true;
#       EnableAllFolders = true;
#       AdminRoles = ["Admin"];
#       EnableLiveTv = true;
#       LiveTvManagementRoles = ["Admin"];
#       RoleClaim = "roles";
#       OidScopes = [
#         "entitlements"
#         "email"
#         "openid"
#         "profile"
#       ];
#       SchemeOverride = "https";
#       NewPath = true;
#     };
  };
  systemd.services.jellyfin.serviceConfig = {
    # Allow hardware acceleration
    SupplementaryGroups = [
      "video"
      "render"
    ];
  };
}
