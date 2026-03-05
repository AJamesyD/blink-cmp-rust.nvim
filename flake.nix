{
  description = "blink-cmp-rust.nvim — Rust-aware completion sorting for blink.cmp";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.treefmt-nix.flakeModule ];

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      perSystem =
        { config, pkgs, ... }:
        {
          devShells.default = pkgs.mkShellNoCC {
            packages = [
              pkgs.lua5_1
              pkgs.luajitPackages.busted
              pkgs.luajitPackages.luacheck
              pkgs.markdownlint-cli2
              config.treefmt.build.wrapper
            ];
          };

          treefmt = {
            projectRootFile = "flake.nix";
            programs.stylua.enable = true;
          };
        };
    };
}
