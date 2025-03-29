{ pkgs ? import <nixpkgs> {} }:

pkgs.rustPlatform.buildRustPackage {
  name = "dfinity-sdk";
  src = ./.;

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "derive_more-0.99.8-alpha.0" = pkgs.lib.fakeHash;
      "ic-agent-0.39.3" = pkgs.lib.fakeHash;
      "ic-base-types-0.9.0" = pkgs.lib.fakeHash;
      "ic-btc-interface-0.1.0" = pkgs.lib.fakeHash;
      "ic-certification-2.3.0" = pkgs.lib.fakeHash;
      "pocket-ic-7.0.0" = pkgs.lib.fakeHash;
  };
  };

  # Specify the Rust version
  rustc = pkgs.rustup.profile {
    profile = "minimal";
    toolchain = "stable";
    version = "1.85";
    components = [ "rust-std" "rustc" "cargo" ];
  };

  # Dependencies
  buildInputs = [
    pkgs.rustfmt
    pkgs.clippy
    pkgs.protobuf
    pkgs.git
  ];

  # Enable tests and benchmarks
  doCheck = true;
  doBenchmark = false;

  # Additional build steps (e.g., generating protobuf files)
  preBuild = ''
    ${pkgs.protobuf}/bin/protoc --proto_path=./proto --rust_out=./src/proto
  '';

  meta = {
    description = "Dfinity SDK";
    homepage = https://github.com/dfinity/sdk;
    license = { type = "BSD"; };
  };
}
