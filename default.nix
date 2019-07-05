with import <nixpkgs> {
  overlays = [
    (import (builtins.fetchGit { url = "git@gitlab.intr:_ci/nixpkgs.git"; ref = "master"; }))
  ];
};

let
  
inherit (builtins) concatMap getEnv toJSON;
inherit (dockerTools) buildLayeredImage;
inherit (lib) concatMapStringsSep firstNChars flattenSet dockerRunCmd;
inherit (stdenv) mkDerivation;

locales = glibcLocales.override {
  allLocales = false;
  locales = [ "en_US.UTF-8/UTF-8" "ru_RU.UTF-8/UTF-8" ];
};

nginx = with nginxModules; let modules = [ nginxLua nginxVts nginxSysGuard develkit ]; in
  mkDerivation rec {
    name = "nginx-${version}";
    version = "1.16.0";
    src = fetchurl {
      url = "https://nginx.org/download/nginx-${version}.tar.gz";
      sha256 = "0i8krbi1pc39myspwlvb8ck969c8207hz84lh3qyg5w7syx7dlsg";
    };
    buildInputs = [ openssl zlib pcre ] ++ concatMap (mod: mod.inputs or []) modules;
    patches = [ ./configure.patch ];
    configureFlags = [
      "--with-http_ssl_module"
      "--with-http_realip_module"
      "--with-http_sub_module"
      "--with-http_gunzip_module"
      "--with-http_gzip_static_module"
      "--with-threads"
      "--with-pcre-jit"
      "--with-file-aio"
      "--with-http_v2_module"
      "--with-http_stub_status_module"
      "--without-http_geo_module"
      "--without-http_empty_gif_module"
      "--without-http_fastcgi_module"
      "--without-http_uwsgi_module"
      "--without-http_scgi_module"
      "--without-http_grpc_module"
      "--without-http_memcached_module"
      "--without-http_charset_module"
      "--without-select_module"
      "--without-poll_module"
      "--user=root"
      "--error-log-path=/dev/stderr"
      "--http-log-path=/dev/stdout"
      "--pid-path=/run/nginx.pid"
      "--lock-path=/run/nginx.lock"
      "--http-client-body-temp-path=/run/client_body_temp"
      "--http-proxy-temp-path=/run/proxy_temp"
    ] ++ map (mod: "--add-module=${mod.src}") modules; 
    preConfigure = (concatMapStringsSep "\n" (mod: mod.preConfigure or "") modules);
    hardeningEnable = [ "pie" ];
    enableParallelBuilding = true;
    postInstall = ''
      shopt -s extglob
      mv $out/sbin $out/bin
      rm -f $out/conf/!(mime.types)
      rm -rf $out/html
    '';
};

nginxConfLayer = with luajitPackages; mkDerivation rec {
  name = "mj-nginx-config";
  srcs = [ ./lua ./conf ./doc ];
  sourceRoot = ".";
  luaPackages = [ luaRestyCore luaRestyLrucache luasocket ];
  buildInputs = [ nginx mjHttpErrorPages pandoc ] ++ luaPackages;
  luaPath = concatMapStringsSep ";" (p: getLuaPath p) luaPackages;
  luaCPath = concatMapStringsSep ";" (p: getLuaCPath p) luaPackages;
  phases = [ "unpackPhase" "buildPhase" "installPhase" ];
  buildPhase = ''
    cp -r ${mjHttpErrorPages}/html .
    cp ${nginx}/conf/mime.types conf
    chmod +w html
    mkdir html/doc
    pandoc --self-contained -s --toc -f markdown -t html5 -c doc/md.css \
      --metadata pagetitle="IP filter" \
      -o html/doc/ip-filter.html doc/ip-filter.md
    for each in conf/*; do
      substituteAllInPlace $each
    done
  '';
  installPhase = ''
    mkdir $out
    cp -pr lua conf html $out
  '';
};

dockerArgHints = {
  init = true;
  read_only = true;
  network = "host";
  volumes = [
    ({ type = "bind"; source = "/opt/nginx/conf"; target = "/read/conf"; read_only = true; })  
    ({ type = "bind"; source = "/etc/nginx/ssl.key"; target = "/read/ssl"; read_only = true; })
    ({ type = "bind"; source = "/etc/nginx/sites-available"; target = "/read/sites"; read_only = true; })
    ({ type = "bind"; source = "/home/nginx"; target = "/write/cache"; })
    ({ type = "bind"; source = "/home"; target = "/home"; read_only = true; })
    ({ type = "tmpfs"; target = "/run"; })
  ];
};

gitAbbrev = firstNChars 8 (getEnv "GIT_COMMIT");

in

buildLayeredImage rec {
  name = "docker-registry.intr/webservices/nginx";
  tag = if gitAbbrev != "" then gitAbbrev else "latest";
  maxLayers = 20;
  contents = [ nginx nginxConfLayer tzdata locales ];
  extraCommands=''
    mkdir -p {etc/nginx,usr/share/nginx/html,var/log/nginx}
    echo 'root:x:0:0:root:/run:' > etc/passwd
    echo 'root:x:0:' > etc/group
    ln -sf /dev/stdout var/log/nginx/access.log
    ln -sf /read/ssl etc/nginx/ssl.key
    for f in html/*; do
      ln -sf /$f usr/share/nginx/html/$(basename $f)
    done
    ln -sf /lua/anti_ddos_check_cookie_file.lua usr/share/nginx/html/anti_ddos_check_cookie_file.lua
    ln -sf /lua/anti_ddos_set_cookie_file.lua usr/share/nginx/html/anti_ddos_set_cookie_file.lua
    ln -sf /read/sites-available etc/nginx/sites-available
    touch 1
  '';
  config = {
    Entrypoint = [ "${nginx}/bin/nginx" "-g" "daemon off;" "-p" "${nginxConfLayer}" ];
    Env = [
      "TZ=Europe/Moscow"
      "TZDIR=/share/zoneinfo"
      "LC_ALL=en_US.UTF-8"
      "LOCALE_ARCHIVE_2_27=${locales}/lib/locale/locale-archive"
    ];
    Labels = flattenSet rec {
      ru.majordomo.docker.arg-hints-json = toJSON dockerArgHints;
      ru.majordomo.docker.cmd = dockerRunCmd dockerArgHints "${name}:${tag}";
      ru.majordomo.docker.exec.reload-cmd = "${nginx}/bin/nginx -p ${nginxConfLayer} -s reload";
      org.label-schema.schema-version = "1.0";
      org.label-schema.docker.cmd = ru.majordomo.docker.cmd;
    };
  };
}
