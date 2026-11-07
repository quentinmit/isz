{
  antigravity-cli,
  vscode-utils,
  lib,
}: vscode-utils.extensionFromVscodeMarketplace {
  name = "google-antigravity";
  publisher = "Google";
  version = "1.11.0";
  hash = "sha256-KKhUKxsPYvuZhgkFTZemm2fMm/rLbrl0US7G5Jbo9Lg=";
  env.agy = lib.getExe antigravity-cli;
  postPatch = ''
    sed -E -i \
        -e "s|this\.binaryAcquirer=[A-Za-z0-9_\$]+;|this.binaryAcquirer=async()=>\"$agy\";|" \
        -e "s|getInstalledTargetPath\(\)\{return [A-Za-z0-9_\$]+\(\)\}|getInstalledTargetPath(){return \"$agy\"}|" \
        -e "s|getInstalledTargetPath=[A-Za-z0-9_\$]+;|getInstalledTargetPath=()=>\"$agy\";|" \
        extension.js
  '';
  meta.license = lib.licenses.mit;
}
