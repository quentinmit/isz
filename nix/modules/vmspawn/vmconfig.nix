{ config, pkgs, lib, ... }:
{
  # Support for running as a systemd-vmspawn VM
  # Based on https://blog.awoo.systems/posts/2025-06-23-lightweight-virtual-machines-nixos
  # and https://github.com/NixOS/nixpkgs/blob/master/nixos/tests/systemd-machinectl.nix

  # we don't need to load CPU firmware in a VM
  hardware.enableRedistributableFirmware = false;
  hardware.cpu.intel.updateMicrocode = false;
  hardware.cpu.amd.updateMicrocode = false;

  # ensure virtualization-related kernel modules are available
  boot.initrd.availableKernelModules = [
    "virtio_net"
    "virtio_pci"
    "virtio_mmio"
    "virtio_blk"
    "virtio_scsi"
    "9p"
    "9pnet_virtio"
    "virtiofs"
  ];
  boot.initrd.kernelModules = [
    "virtio_balloon"
    "virtio_console"
    "virtio_rng"
    "virtio_gpu"
  ];

  # we will direct boot the kernel, so there is no need for a bootloader
  boot.loader.grub.enable = false;
  boot.loader.systemd-boot.enable = false;
  boot.loader.supportsInitrdSecrets = true;

  boot.initrd.systemd.enable = true;
  boot.initrd.systemd.root = "gpt-auto";

  fileSystems."/nix/store" = {
    device = "mnt0";
    fsType = "virtiofs";
    neededForBoot = true;
  };

  networking = {
    useDHCP = true;
    useNetworkd = true;
    nftables.enable = true;
    firewall.enable = false;
  };

  systemd.oomd.enable = false;

  # for vmspawn sshd to work
  systemd.services."sshd@".serviceConfig = {
    ExecSearchPath = "${config.services.openssh.package}/bin";
  };
  systemd.services."sshd-vsock@" = {
    overrideStrategy = "asDropin";
    serviceConfig.ExecStart = [
      ""
      "-sshd -i -o 'AuthorizedKeysFile=%d/ssh.ephemeral-authorized_keys-all %h/.ssh/authorized_keys /etc/ssh/authorized_keys.d/%u' -D -f /etc/ssh/sshd_config"
    ];
  };
}
