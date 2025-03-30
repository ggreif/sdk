{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = {
    self,
    nixpkgs,
    rust-overlay,
  }: let
    system = "aarch64-darwin";
    pkgs = import nixpkgs {
      inherit system;
      overlays = [rust-overlay.overlays.default];
    };
    toolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
  in {
    devShells.${system}.default = pkgs.mkShell {
      packages = [
        toolchain
      ];

      nativeBuildInputs = [
        pkgs.clang_19
        pkgs.cmake
      ];

      CXXFLAGS_aarch64_apple_darwin = "--target=aarch64-apple-darwin";

    };

    packages.${system}.default = pkgs.rustPlatform.buildRustPackage rec {
      pname = "dfx";
      version = "0.25.1";
      cargoLock.lockFile = ./Cargo.lock;
      src = pkgs.lib.cleanSource ./.;
      cargoLock = {
        outputHashes = {
          "derive_more-0.99.8-alpha.0" = "sha256-tEsfYC9oCAsDjinCsUDgRg3q6ruvayuA1lRmsEP9cys=";
          "ic-agent-0.39.3" = "sha256-klkObvVY4GpIUYcN9lAs/cQT/az2TP2VdY8t4duGOGc=";
          "ic-base-types-0.9.0" = "sha256-mM1FekwR0ZEyFTgs8aeN4kReksBSg8qcxK9wIEBv3vo=";
          "ic-btc-interface-0.1.0" = "sha256-BbFLvf9TKWxqVnzjFPEQZ6Vl45/Vbq7592B3ywqeyI0=";
          "ic-certification-2.3.0" = "sha256-nzJY2WLWIfRKNTReXYVTlxfRB9AS5oTyZ372kkKJLAg=";
          "pocket-ic-7.0.0" = "sha256-ECYsWivtd1as6ZRfjiRfv2v0q0amj1QZibl5U8v83Mg=";
        };
      };
    };
  };
}

