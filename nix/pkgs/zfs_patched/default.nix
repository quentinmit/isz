{
  callPackage,
  fetchpatch,
  nixosTests,
  path,
  pkgs,
  lib,
  ...
}@args:

assert (!lib.versionAtLeast pkgs.zfs.version "2.4.5");
callPackage "${path}/pkgs/os-specific/linux/zfs/generic.nix" args {
  kernelModuleAttribute = "zfs_patched";

  kernelMinSupportedMajorMinor = "4.18";
  kernelMaxSupportedMajorMinor = "7.3";
  version = "2.4.4";
  extraPatches = let
    hashes = {
      "linux-7.3-iops-create-no-flag.patch" = "sha256-JiRkMlGNBwZytgoojCVb3tp8oRCygtpobYelb+KUrOs=";
      "linux-7.3-bvec-iter-bi-offset.patch" = "sha256-zvE85+MPkdLH926ca7TRziBzktkhKKZSqOgueQuulBA=";
      "linux-cpu-feature-enabled.patch" = "sha256-+Nr5xdpFfLiYr62w+w0I950JJWi8TOyUa5ro6fzYc2k=";
      "linux-7.3-kthread-init-fs.patch" = "sha256-4/MLbYQIV/SJEckUHLjh/jBWYhIRk9nU3lNfHRFUb2w=";
      "bump-Linux-Maximum-7.3.patch" = "sha256-iq3xJHq5gCyhCwlqnpbwoc8QrLh+Tn+KpbKyUAVNigY=";
    };
  in lib.mapAttrsToList (name: hash: fetchpatch {
    inherit name hash;
    url = "https://git.launchpad.net/ubuntu/+source/zfs-linux/plain/debian/patches/${name}?h=import/2.4.4-1ubuntu4";
  }) hashes;
  tests = {
    inherit (nixosTests.zfs) patched;
  };
  hash = "sha256-ZgfHTPsNoeDq6GKP4Xiti7Keis3vIZLDaTGQjgCItIc=";
}
