{ pkgs ? import (import ./channels.nix).nixpkgs {
  overlays = (import ./channels.nix).overlays;
}
}:

with pkgs;

let
  inherit (builtins) toJSON;
  inherit (dockerTools) buildLayeredImage;
  inherit (lib) dockerRunCmd flattenSet;
  inherit (stdenv) mkDerivation;
  inherit (import ./common.nix { inherit pkgs; }) nginx nginxConfLayer dockerArgHints locales;
in buildLayeredImage rec {
  name = "docker-registry.intr/webservices/nginx";
  topLayer = nginxConfLayer;
  tag = "latest";
  contents = [ nginx nginxConfLayer tzdata locales ];
  extraCommands = ''
    mkdir -p {etc/nginx,usr/share/nginx/html,var/log/nginx,opt/nginx}
    echo 'root:x:0:0:root:/run:' > etc/passwd
    echo 'root:x:0:' > etc/group
    ln -sf /dev/stdout var/log/nginx/access.log
    ln -sf /read/ssl etc/nginx/ssl.key
    ln -sf /read/ssl opt/nginx/ssl
    for f in html/*; do
      ln -sf /$f usr/share/nginx/html/$(basename $f)
    done
    ln -sf /lua/anti_ddos_check_cookie_file.lua usr/share/nginx/html/anti_ddos_check_cookie_file.lua
    ln -sf /lua/anti_ddos_set_cookie_file.lua usr/share/nginx/html/anti_ddos_set_cookie_file.lua
    ln -sf /read/sites-available etc/nginx/sites-available
  '';
  config = {
    Entrypoint = [
      "${nginx}/bin/nginx"
      "-g"
      "daemon off; pid /var/run/nginx.pid;"
      "-p"
      "${nginxConfLayer}"
    ];
    Env = [
      "TZ=Europe/Moscow"
      "TZDIR=/share/zoneinfo"
      "LC_ALL=en_US.UTF-8"
      "LOCALE_ARCHIVE_2_27=${locales}/lib/locale/locale-archive"
    ];
    Labels = flattenSet rec {
      ru.majordomo.docker.arg-hints-json = toJSON dockerArgHints;
      ru.majordomo.docker.cmd = dockerRunCmd dockerArgHints "${name}:${tag}";
      ru.majordomo.docker.exec.reload-cmd = ''
        ${nginx}/bin/nginx -g "pid /var/run/nginx.pid;" -p ${nginxConfLayer} -s reload'';
      org.label-schema.schema-version = "1.0";
      org.label-schema.docker.cmd = ru.majordomo.docker.cmd;
    };
  };
}
