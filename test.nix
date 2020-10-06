with import (import ./channels.nix).nixpkgs {
  overlays = (import ./channels.nix).overlays;
};

let
  image = callPackage ./default.nix { };
  keydir = (fetchGit {url = "git@gitlab.intr:office/ssl-certificates"; ref = "master";}).outPath + "/ssl" ;
  confdir = ./tests/conf;
  reloadNginx = writeScript "reloadNginx.sh" ''
  #!/bin/sh -eux
   ${docker}/bin/docker exec nginx ${(lib.importJSON (image.baseJson)).config.Labels."ru.majordomo.docker.exec.reload-cmd"}
  '';

in maketestNginx {
  inherit image keydir confdir;
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
    (dockerNodeTest {
      description = "502 test";
      action = "succeed";
      command = runCurlGrep "-H 'Host: test.ru' 127.0.0.1" "' 502'";
    })
    (dockerNodeTest {
      description = "502 mj-error test";
      action = "succeed";
      command = runCurlGrep "-H 'Host: test.ru' 127.0.0.1" "majordomo";
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

#host-protect tests

    (dockerNodeTest {
      description = "generate test.ru html content";
      action = "succeed";
      command = "mkdir -p /home/u12/testru/www/ ; echo 'hello from nix-test' > /home/u12/testru/www/index.html";
    })
    (dockerNodeTest {
      description = "list host's in host-protected location";
      action = "succeed";
      command = "curl -s 127.0.0.1/protected";
    })
    (dockerNodeTest {
      description = "test vhost without protection";
      action = "succeed";
      command = runCurlGrep "-H 'Host: test.ru' 127.0.0.1/index.html" "'hello'";
    })
    (dockerNodeTest {
      description = "add test.ru host to host-protected location";
      action = "succeed";
      command = "curl -XPUT 127.0.0.1/protected/test.ru";
    })
    (dockerNodeTest {
      description = "list test.ru in protected sites" ;
      action = "succeed";
      command = runCurlGrep "127.0.0.1/protected" "test.ru";
    })
    (dockerNodeTest {
      description = "curl test protection";
      action = "succeed";
      command = runCurlGrep "-H 'Host: test.ru' 127.0.0.1/index.html" "'mj_anti_flood'";
    })



#[0713/134021.919133:ERROR:headless_shell.cc(482)] Failed to serialize document: Uncaught
#    (dockerNodeTest {
#      description = "test protection with chromium";
#      action = "succeed";
#      command = "google-chrome-stable --no-sandbox --headless --dump-dom http://test.ru/index.html  | grep hello";
#    })

#    (dockerNodeTest {
#      description = "test protection with firefox";
#      action = "succeed";
#      command = "strace -f -s 10000 firefox --screenshot=/dev/null --headless http://test.ru/index.html  | grep hello";
#    })

    (dockerNodeTest {
      description = "test protection with chromium";
      action = "succeed";
      command = "strace -f -s 10000 google-chrome-stable --no-sandbox --headless --dump-dom http://test.ru/index.html 2>&1 | grep hello";
    })


    (dockerNodeTest {
      description = "delete test.ru from host-protected location";
      action = "succeed";
      command = "curl -XDELETE 127.0.0.1/protected/test.ru";
    })
    (dockerNodeTest {
      description = "test vhost without protection after delete";
      action = "succeed";
      command = runCurlGrep "-H 'Host: test.ru' 127.0.0.1/index.html" "'hello'";
    })
    (dockerNodeTest {
      description = "add test.ru to protection 2seconds with Authorization";
      action = "succeed";
      command = "curl -s -i -H'Authorization: w5iwLomy2okyHDFLUiTimSuk84VLtY70pfiI' -XPUT '127.0.0.1/protected/test.ru?ttl=2'";
    })
    (dockerNodeTest {
      description = "test from 127.0.0.2 ";
      action = "succeed";
      command = "sleep 3 && curl -H 'Host: test.ru' 127.0.0.1/index.html | grep hello ";
    })


# ip-fliter docs

    (dockerNodeTest {
      description = "test ip-filter docs ";
      action = "succeed";
      command = runCurlGrep " -s -o /dev/null  -w '%{http_code}' 127.0.0.1/doc/ip-filter.html" "200";
    })

# host-protected docs

    (dockerNodeTest {
      description = "test host-protected docs ";
      action = "succeed";
      command = runCurlGrep " -s -o /dev/null  -w '%{http_code}' 127.0.0.1/doc/host-protection.html" "200";
    })


# nginx-module-vts
    (dockerNodeTest {
      description = "test nginx-module-vts ";
      action = "succeed";
      command = "curl -s  127.0.0.1/status/format/json | jq .sharedZones.name | grep vhost_traffic_status";
    })

    (dockerNodeTest {
      description = "reload";
      action = "succeed";
      command = "${reloadNginx}";
    })
  ];
}  { }
