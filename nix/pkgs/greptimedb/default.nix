{
  cacert,
  protobuf,
  lib,
  fetchFromGitHub,
  rust-bin,
  makeRustPlatform,
  testers,
  stdenv,
  nodejs,
  pnpmBuildHook,
  pnpmConfigHook,
  pnpm_9,
  fetchPnpmDeps,
  withEnterprise ? false,
}:
let
  rust = rust-bin.nightly."2026-03-21".default;
  rustPlatform = makeRustPlatform {
    cargo = rust;
    rustc = rust;
  };
  pnpm = pnpm_9.override {
    # Vulnerabilities in package fetching do not matter when the result is hashed by Nix.
    knownVulnerabilities = [];
  };
in rustPlatform.buildRustPackage (finalAttrs: {
  pname = "greptimedb";
  version = "1.1.2";

  src = fetchFromGitHub {
    owner = "GreptimeTeam";
    repo = "greptimedb";
    tag = "v${finalAttrs.version}";
    hash = "sha256-K2E5eGNXSGgd62bU8zk/eEhzGgNsvtnQev/bM057V14=";
  };

  cargoHash = "sha256-OnrlHPmZ8DHV6I0a7IBAGLR5pAYvuwsVtu3A9Njkvk8=";

  dashboard = stdenv.mkDerivation (finalAttrs: {
    pname = "greptimedb-dashboard";
    version = "0.13.6";

    src = fetchFromGitHub {
      owner = "GreptimeTeam";
      repo = "dashboard";
      rev = "v${finalAttrs.version}";
      hash = "sha256-iPix9eKWrPqAxaCgu+e+gcFs/pTfAzGig/9iB2YiC5w=";
    };

    nativeBuildInputs = [
      nodejs
      pnpmConfigHook
      pnpmBuildHook
      pnpm
    ];

    pnpmDeps = fetchPnpmDeps {
      inherit (finalAttrs) pname version src;
      inherit pnpm;
      fetcherVersion = 4;
      hash = "sha256-TpB+gKdHRW4FMrz/qcqcp8SFpcG3wehBgsEXdhtwVRI=";
    };

    installPhase = ''
      runHook preInstall
      cp -R dist $out
      runHook postInstall
    '';
  });

  nativeBuildInputs = [
    protobuf
  ];

  depsExtraArgs.postBuild = ''
    mv $out/git/5da284414e9b14f678344b51e5292229e4b5f8d2/proto $out/git/5da284414e9b14f678344b51e5292229e4b5f8d2/rust/otel-arrow-rust/proto
    substituteInPlace $out/git/5da284414e9b14f678344b51e5292229e4b5f8d2/rust/otel-arrow-rust/build.rs \
      --replace-fail "{base}/../../proto" "{base}/proto"
  '';

  postPatch = ''
    ln -s $dashboard src/servers/dashboard/dist
  '';

  cargoBuildFlags = [ "--bin" "greptime" ];

  # Tests are currently still flaky - don't run them by default.
  doCheck = false;

  preCheck = ''
    # Without this tests fails with
    # Client::new(): reqwest::Error { kind: Builder, source: General("No CA certificates were loaded from the system") }
    export SSL_CERT_FILE="${cacert}/etc/ssl/certs/ca-bundle.crt"

    cargoTestFlags="--build-jobs ''${NIX_BUILD_CORES:-1} $cargoTestFlags"
  '';
  # Plain "cargo test" fails in common-query prelude::tests
  useNextest = true;
  # Match the default cargo-nextest arguments from Makefile
  cargoCheckFeatures = [
    "pg_kvbackend"
    "mysql_kvbackend"
  ];
  cargoTestFlags = [
    "--retries" "3"
  ];
  # Parallel tests will use conflicting binds.
  dontUseCargoParallelTests = true;

  buildFeatures = [
    "dashboard"
  ] ++ lib.optional withEnterprise "enterprise";

  meta = {
    description = "The open-source Observability 2.0 database";
    mainProgram = "greptime";
    homepage = "https://greptime.com/";
    license = if withEnterprise then lib.licenses.unfree else lib.licenses.asl20;
    maintainers = [ lib.maintainers.quentin ];
  };

  passthru.tests.default = testers.runNixOSTest {
    imports = [
      ./test.nix
    ];
    defaults = {
      imports = [ ../../modules/greptimedb.nix ];
      services.greptimedb.package = finalAttrs.finalPackage;
    };
  };
})
