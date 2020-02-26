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

#setCockie tests

    (dockerNodeTest {
      description = "list ip's in ip-filter";
      action = "succeed";
      command = "curl -s 127.0.0.1/ip-filter/";
    })
    (dockerNodeTest {
      description = "add 127.0.0.2 to ip-filter (setCockie)";
      action = "succeed";
      command = "curl -s -i -XPUT '127.0.0.1/ip-filter/127.0.0.2?ttl=7200&action=setCookie'";
    })
    (dockerNodeTest {
      description = "ensure";
      action = "succeed";
      command = runCurlGrep "127.0.0.1/ip-filter" "127.0.0.2.*setCookie";
    })
    (dockerNodeTest {
      description = "test Cockie from 127.0.0.2 ";
      action = "succeed";
      command = runCurlGrep "--interface 127.0.0.2 http://127.0.0.1" "mj_anti_flood";
    })
    (dockerNodeTest {
      description = "delete 127.0.0.2 from ip-filter";
      action = "succeed";
      command = "curl -s -i -XDELETE '127.0.0.1/ip-filter/127.0.0.2'";
    })
    (dockerNodeTest {
      description = "list ip's in ip-filter";
      action = "succeed";
      command = "curl -s 127.0.0.1/ip-filter/";
    })
    (dockerNodeTest {
      description = "add 127.0.0.2 to ip-filter (setCockie) 2seconds";
      action = "succeed";
      command = "curl -s -i -XPUT '127.0.0.1/ip-filter/127.0.0.2?ttl=2&action=setCookie'";
    })
    (dockerNodeTest {
      description = "test from 127.0.0.2 ";
      action = "succeed";
      command = "sleep 3 && curl --interface 127.0.0.2 -s 127.0.0.1/ip-filter/";
    })

#return403 tests

    (dockerNodeTest {
      description = "list ip's in ip-filter";
      action = "succeed";
      command = "curl -s 127.0.0.1/ip-filter/";
    })
    (dockerNodeTest {
      description = "add 127.0.0.2 to ip-filter (return403) with Authorization";
      action = "succeed";
      command = "curl -s -i -H'Authorization: w5iwLomy2okyHDFLUiTimSuk84VLtY70pfiI' -XPUT '127.0.0.1/ip-filter/127.0.0.2?ttl=7200&action=return403'";
    })
    (dockerNodeTest {
      description = "ensure";
      action = "succeed";
      command = runCurlGrep "127.0.0.1/ip-filter" "127.0.0.2.*return403";
    })
    (dockerNodeTest {
      description = "test return403 from 127.0.0.2 ";
      action = "succeed";
      command = runCurlGrep "--interface 127.0.0.2 http://127.0.0.1/ip-filter" "403";
    })
    (dockerNodeTest {
      description = "delete 127.0.0.2 from ip-filter";
      action = "succeed";
      command = "curl -s -i -XDELETE '127.0.0.1/ip-filter/127.0.0.2'";
    })
    (dockerNodeTest {
      description = "list ip's in ip-filter";
      action = "succeed";
      command = "curl -s 127.0.0.1/ip-filter/";
    })
    (dockerNodeTest {
      description = "add 127.0.0.2 to ip-filter (return403) 2seconds  with Authorization";
      action = "succeed";
      command = "curl -s -i -H'Authorization: w5iwLomy2okyHDFLUiTimSuk84VLtY70pfiI' -XPUT '127.0.0.1/ip-filter/127.0.0.2?ttl=2&action=return403'";
    })
    (dockerNodeTest {
      description = "test from 127.0.0.2 ";
      action = "succeed";
      command = "sleep 3 && curl --interface 127.0.0.2 -s 127.0.0.1/ip-filter/";
    })

#connReset tests

    (dockerNodeTest {
      description = "list ip's in ip-filter";
      action = "succeed";
      command = "curl -s 127.0.0.1/ip-filter/";
    })
    (dockerNodeTest {
      description = "add 127.0.0.2 to ip-filter (connReset) with Authorization";
      action = "succeed";
      command = "curl -s -i -H'Authorization: w5iwLomy2okyHDFLUiTimSuk84VLtY70pfiI' -XPUT '127.0.0.1/ip-filter/127.0.0.2?ttl=7200&action=connReset'";
    })
    (dockerNodeTest {
      description = "ensure";
      action = "succeed";
      command = runCurlGrep "127.0.0.1/ip-filter" "127.0.0.2.*connReset";
    })
    (dockerNodeTest {
      description = "test connReset from 127.0.0.2 ";
      action = "fail";
      command = "curl -f --interface 127.0.0.2 -L -I -s 127.0.0.1/ip-filter";
    })
    (dockerNodeTest {
      description = "delete 127.0.0.2 from ip-filter";
      action = "succeed";
      command = "curl -s -i -XDELETE '127.0.0.1/ip-filter/127.0.0.2'";
    })
    (dockerNodeTest {
      description = "list ip's in ip-filter";
      action = "succeed";
      command = "curl -s 127.0.0.1/ip-filter/";
    })
    (dockerNodeTest {
      description = "add 127.0.0.2 to ip-filter (connReset) 2seconds with Authorization";
      action = "succeed";
      command = "curl -s -i -H'Authorization: w5iwLomy2okyHDFLUiTimSuk84VLtY70pfiI' -XPUT '127.0.0.1/ip-filter/127.0.0.2?ttl=2&action=connReset'";
    })
    (dockerNodeTest {
      description = "test from 127.0.0.2 ";
      action = "succeed";
      command = "sleep 3 && curl --interface 127.0.0.2 -s 127.0.0.1/ip-filter/";
    })

# ip-fliter docs

    (dockerNodeTest {
      description = "test ip-filter docs ";
      action = "succeed";
      command = runCurlGrep " -s -o /dev/null  -w '%{http_code}' 127.0.0.1/doc/ip-filter.html" "200";
    })

# nginx-module-vts
    (dockerNodeTest {
      description = "test nginx-module-vts ";
      action = "succeed";
      command = "curl -s  127.0.0.1/status/format/json | jq .sharedZones.name | grep vhost_traffic_status";
    })


  ];
}  { } 
