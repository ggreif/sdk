{ pkgs ? import <nixpkgs> {} }:

pkgs.rustPlatform.buildRustPackage {
  name = "dfinity-sdk";
  src = ./.;

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHash = "your-cargo-lock-hash";  # Replace with the actual hash of your Cargo.lock
  };

  # Specify the Rust version
  rustc = pkgs.rustup.rustToolchainFromProfile {
    profile = "minimal";
    toolchain = "stable";
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
  doBenchmark = true;

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
