{ ref ? "master", debug ? false }:

with import <nixpkgs> {
  overlays = [
    (import (builtins.fetchGit { url = "git@gitlab.intr:_ci/nixpkgs.git"; inherit ref  ; }))
  ];
};

let
  image = callPackage ./default.nix  { inherit ref; };
  keydir = (fetchGit {url = "git@gitlab.intr:office/ssl-certificates"; ref = "master";}).outPath;
  confdir = ./tests/conf;
  reloadNginx = writeScript "reloadNginx.sh" ''
  #!/bin/sh -eux                                                                                                                                                                           
   ${docker}/bin/docker exec nginx ${(lib.importJSON (image.baseJson)).config.Labels."ru.majordomo.docker.exec.reload-cmd"} 
  '';

in maketestNginx {
  inherit image;
  inherit debug;
  inherit keydir;
  inherit confdir;
  testSuite = [
    (dockerNodeTest {
      description = "ls configs";
      action = "succeed";
      command = "ls -la /opt/nginx/conf/default_server.conf && ls -la /opt/nginx/conf/upstreams.conf";
    })
     (dockerNodeTest {                                                                                                                                                                      
      description = "check for nginx container exists";                                                                                                                               
      action = "succeed";                                                                                                                                                                   
      command = "docker ps -a | grep [n]ginx";
     })
     (dockerNodeTest {                                                                                                                                                                      
      description = "check for nginx container is running";                                                                                                                             
      action = "succeed";                                                                                                                                                                   
      command = "docker ps | grep [n]ginx";
     })
     (dockerNodeTest {                                                                                                                                                                      
      description = "check nginx proccess";                                                                                                                                                 
      action = "succeed";                                                                                                                                                                   
      command = " ps aux | grep [n]ginx";
     })
    (dockerNodeTest {
      description = "403 test";
      action = "succeed";
      command = runCurlGrep "127.0.0.1" "' 403'";
    })
    (dockerNodeTest {
      description = "403 mj-error test";
      action = "succeed";
      command = runCurlGrep "127.0.0.1" "majordomo";
    })
  ];
}  { } 
