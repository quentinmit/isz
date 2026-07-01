{
  cacert,
  protobuf,
  lib,
  fetchFromGitHub,
  rust-bin,
  makeRustPlatform,
  testers,
  withEnterprise ? false,
}:
let
  rust = rust-bin.nightly."2026-03-21".default;
  rustPlatform = makeRustPlatform {
    cargo = rust;
    rustc = rust;
  };
in rustPlatform.buildRustPackage (finalAttrs: {
  pname = "greptimedb";
  version = "1.1.1";

  src = fetchFromGitHub {
    owner = "GreptimeTeam";
    repo = "greptimedb";
    tag = "v${finalAttrs.version}";
    hash = "sha256-srHhOQP4yxosuj+XxeyrpwhAiJO7MVETLzr/LuhbchM=";
  };

  cargoHash = "sha256-Phi+NeywAdsq4kHJJOmzrfLg1CCLMbFetdkEzjvJgjw=";

  nativeBuildInputs = [
    protobuf
  ];

  depsExtraArgs.postBuild = ''
    mv $out/git/5da284414e9b14f678344b51e5292229e4b5f8d2/proto $out/git/5da284414e9b14f678344b51e5292229e4b5f8d2/rust/otel-arrow-rust/proto
    substituteInPlace $out/git/5da284414e9b14f678344b51e5292229e4b5f8d2/rust/otel-arrow-rust/build.rs \
      --replace-fail "{base}/../../proto" "{base}/proto"
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

  buildFeatures = lib.optional withEnterprise "enterprise";

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
