with import (import ./channels.nix).nixpkgs { };

let common = import ./common.nix;
in stdenv.mkDerivation {
  name = "nginx-environment";
  buildInputs = [
    common.nginx
    common.nginxConfLayer
  ];
}
