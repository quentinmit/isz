{
  fetchzip,
}:
let
  name = "mac-hard-disk-drivers.zip";
in fetchzip {
  inherit name;
  url = "https://www.dropbox.com/s/gcs4v5pcmk7rxtb/${name}?dl=1";
  extension = "zip";
  stripRoot = false;
  hash = "sha256-LQFMv3g4KGpvXP/can/4g3N+IRbiyvvWn3rsqWsp9Rw=";
}
