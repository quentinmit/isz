{
  stdenv,
  lib,
  fetchFromGitHub,
  nix-update-script,
  kdePackages,
  ...
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "plasma-homeassistant";
  version = "1.2.0";

  src = fetchFromGitHub {
    owner = "korapp";
    repo = finalAttrs.pname;
    tag = "v${finalAttrs.version}";
    hash = "sha256-7Q9WTLrRQJCKtMDmum3YViKWk6V1vusGBjEqVrllbc4=";
    fetchSubmodules = true;
  };

  propagatedUserEnvPkgs = [
    kdePackages.qtwebsockets
  ];

  dontWrapQtApps = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/plasma/plasmoids
    cp -r package $out/share/plasma/plasmoids/com.github.korapp.homeassistant

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Add Home Assistant to your plasma desktop";
    homepage = "https://github.com/korapp/plasma-homeassistant/";
    license = lib.licenses.gpl3Plus;
    maintainers = with lib.maintainers; [ quentin ];
    inherit (kdePackages.kwindowsystem.meta) platforms;
  };
})
