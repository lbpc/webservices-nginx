{
  nixpkgs = (import <nixpkgs> { }).fetchgit {
    url = "https://github.com/NixOS/nixpkgs";
    rev = "ce9f1aaa39ee2a5b76a9c9580c859a74de65ead5";
    sha256 = "1s2b9rvpyamiagvpl5cggdb2nmx4f7lpylipd397wz8f0wngygpi";
  };
  overlays = [
    (import (builtins.fetchGit {
      url = "git@gitlab.intr:_ci/nixpkgs.git";
      ref = "master";
    }))
  ];
}
