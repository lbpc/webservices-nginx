{
  description = "Docker container with NGINX builded by Nix";

  inputs = {
    nixpkgs-unstable.url = "nixpkgs/nixpkgs-unstable";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    deploy-rs.url = "github:serokell/deploy-rs";
    utils.url = "github:numtide/flake-utils";

    nixpkgs.url = "nixpkgs/nixos-20.09";
    nixpkgs-20-03 = { url = "github:NixOS/nixpkgs?ref=20.03"; flake = false; };
    majordomo.url = "git+https://gitlab.intr/_ci/nixpkgs";
    ssl-certificates.url = "git+ssh://git@gitlab.intr/office/ssl-certificates";
  };

  outputs = { self
            , nixpkgs
            , nixpkgs-20-03
            , nixpkgs-unstable
            , majordomo
            , ssl-certificates
            , ... } @ inputs:
    let
      pkgs = import nixpkgs { inherit system; };
      system = "x86_64-linux";
      inherit (pkgs) callPackage;
      inherit (pkgs) lib;

      pkgs-20-03 = import nixpkgs-20-03 { inherit system; };

      pkgs-unstable = import nixpkgs-unstable { inherit system; };
    in {

      packages.${system} = {
        container = import ./default.nix { pkgs = majordomo.outputs.nixpkgs; };
        deploy = majordomo.outputs.deploy { tag = "webservices/nginx"; };
      };

      defaultPackage.${system} = self.packages.x86_64-linux.container;

      devShell.${system} = pkgs-unstable.mkShell {
        buildInputs = [ pkgs-unstable.nixUnstable ];
      };

      checks.${system}.container =
        import ./test.nix {
          pkgs = majordomo.outputs.nixpkgs;
          keydir = ssl-certificates.packages.${system}.certificates.outPath + "/ssl";
        };
    };
}
