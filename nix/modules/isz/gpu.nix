{ config, lib, pkgs, ... }:
{
  options = with lib; {
    isz.gpu = {
      enable = mkEnableOption "GPU";
      amd = mkEnableOption "AMD GPU";
    };
  };
  config = lib.mkMerge [
    (lib.mkIf config.isz.gpu.enable {
      hardware.opengl.driSupport32Bit = true;
      environment.systemPackages = with pkgs; [
        clinfo
        glxinfo
        libva-utils
        vulkan-tools
      ];
    })
    (lib.mkIf (config.isz.gpu.enable && config.isz.gpu.amd) {
      hardware.opengl.extraPackages = with pkgs; [
        # https://nixos.org/manual/nixos/stable/#sec-gpu-accel-opencl-amd
        rocmPackages.clr.icd
        # https://nixos.org/manual/nixos/stable/#sec-gpu-accel-vulkan-amd
        # Disable for now (radv driver in mesa should handle)
        #amdvlk
      ];
      #hardware.opengl.extraPackages32 = with pkgs; [
      #  driversi686Linux.amdvlk
      #];
      environment.systemPackages = with pkgs; [
        nvtopPackages.amd
        radeontop
      ];
    })
  ];
}
