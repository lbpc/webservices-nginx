with import <nixpkgs> {
  overlays = [
    (self: super: {
      glibcLocales = super.glibcLocales.override {
        allLocales = false;
        locales = [ "en_US.UTF-8/UTF-8" "ru_RU.UTF-8/UTF-8" ];
      };
    })
  ];
};
with stdenv.lib;

let
  
openrestyLuajit2 = stdenv.mkDerivation rec {
  name = "openresty-luajit2";
  version = "2.1-20190507";
  src = fetchFromGitHub {
    owner = "openresty";
    repo = "luajit2";
    rev = "v${version}";
    sha256 = "0vy9kgjh8ihx7qg3qiwnlpqgxh6mpqq25rj96bzj1449fq38xbbq";
  };
  patchPhase = ''
    substituteInPlace Makefile --replace /usr/local "$out"
    substituteInPlace src/Makefile --replace gcc cc
    substituteInPlace Makefile --replace ldconfig ${stdenv.cc.libc.bin or stdenv.cc.libc}/bin/ldconfig
  '';
  configurePhase = false;
  buildFlags = [ "amalg" ];
  enableParallelBuilding = true;
  installPhase   = ''
    make install PREFIX="$out"
    ( cd "$out/include"; ln -s luajit-*/* . )
    ln -s "$out"/bin/luajit-* "$out"/bin/lua
  '';
};

nginxLua = {
  name = "lua-nginx-module";
  version = "0.10.15";
  src = fetchFromGitHub {
    owner = "openresty";
    repo = "lua-nginx-module";
    rev = "28cf5ce3b6ec8e7ab44eadac9cc1c3b6f5c387ba";
    sha256 = "1j216isp0546hycklbr5wi8mlga5hq170hk7f2sm16sfavlkh5gz";
  };
  inputs = [ openrestyLuajit2 ];
  preConfigure = ''
    export LUAJIT_LIB="${openrestyLuajit2}/lib"
    export LUAJIT_INC="${openrestyLuajit2}/include/luajit-2.0"
  '';
};

nginxVts = {
  name = "vts-nginx-module";
  version = "0.1.18";
  src = fetchFromGitHub {
    owner = "vozlt";
    repo = "nginx-module-vts";
    rev = "d6aead19ab52834ad748f14dc536b9128ee22372";
    sha256 = "1jq2s9k7hah3b317hfn9y3g1q4g4x58k209psrfsqs718a9sw8c7";
  };
};

nginxSysGuard = {
  name = "sysguard-nginx-module";
  version = "0.1.0";
  src = fetchFromGitHub {
    owner = "vozlt";
    repo = "nginx-module-sysguard";
    rev = "e512897f5aba4f79ccaeeebb51138f1704a58608";
    sha256 = "19c6w6wscbq9phnx7vzbdf4ay6p2ys0g7kp2rmc9d4fb53phrhfx";
  };
};

luaRestyCore = lua51Packages.buildLuaPackage rec {
  name = "lua-resty-core";
  version = "0.1.17";
  src = fetchFromGitHub {
    owner = "openresty";
    repo = "lua-resty-core";
    rev = "v${version}";
    sha256 = "11fyli6yrg7b91nv9v2sbrc6y7z3h9lgf4lrrhcjk2bb906576a0";
  };
  buildPhase = ":";
  installPhase = ''
    mkdir -p $out/lib/lua/5.1
    cp -pr lib/* $out/lib/lua/5.1
  '';
};

luaRestyLrucache = lua51Packages.buildLuaPackage rec {
  name = "lua-resty-lrucache";
  version = "0.0.9";
  src = fetchFromGitHub {
    owner = "openresty";
    repo = "lua-resty-lrucache";
    rev = "v0.09";
    sha256 = "1mwiy55qs8bija1kpgizmqgk15ijizzv4sa1giaz9qlqs2kqd7q2";
  };
  buildPhase = ":";
  installPhase = ''
    mkdir -p $out/lib/lua/5.1
    cp -pr lib/resty $out/lib/lua/5.1
  '';
};

mjerrors = stdenv.mkDerivation rec {
  name = "mjerrors";
  buildInputs = [ gettext ];
  src = fetchGit {
    url = "git@gitlab.intr:shared/http_errors.git";
    ref = "master";
    rev = "f83136c7e6027cb28804172ff3582f635a8d2af7";
  };
  outputs = [ "out" ];
  postInstall = ''
    mkdir $out/html
    cp -pr /tmp/mj_http_errors/* $out/html/
  '';
};

nginx = stdenv.mkDerivation rec {
  name = "nginx-${version}";
  version = "1.16.0";
  src = fetchurl {
    url = "https://nginx.org/download/nginx-${version}.tar.gz";
    sha256 = "0i8krbi1pc39myspwlvb8ck969c8207hz84lh3qyg5w7syx7dlsg";
  };
  buildInputs = [ openssl zlib pcre nginxLua.inputs ];
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
    "--add-module=${nginxLua.src}"
    "--add-module=${nginxVts.src}"
    "--add-module=${nginxSysGuard.src}"
    "--add-module=${nginxModules.develkit.src}"
  ]; 
  preConfigure = nginxLua.preConfigure;
  hardeningEnable = [ "pie" ];
  enableParallelBuilding = true;
  postInstall = ''
    shopt -s extglob
    mv $out/sbin $out/bin
    rm -f $out/conf/!(mime.types)
    rm -rf $out/html
  '';
};

nginxConfLayer = stdenv.mkDerivation rec {
  name = "mj-nginx-config";
  srcs = [ ./lua ./conf ./doc ];
  sourceRoot = ".";
  luaPackages = [ luaRestyCore luaRestyLrucache lua51Packages.luasocket ];
  buildInputs = [ nginx mjerrors pandoc ] ++ luaPackages;
  luaPath = concatMapStringsSep ";" (p: lua51Packages.getLuaPath p) luaPackages;
  luaCPath = concatMapStringsSep ";" (p: lua51Packages.getLuaCPath p) luaPackages;
  buildPhase = ''
    cp -r ${mjerrors}/html .
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

keyValOrBoolKey = k: v: if isBool v then (if v then "${k}" else "") else "${k}=${v}";

setToCommaSep = x: concatStringsSep "," (mapAttrsToList keyValOrBoolKey x);

setToKeyVal = x: mapAttrsToList (k: v: "${k}=${v}") x;

dockerRunCmd = {
    init ? false,
    read_only ? false,
    network ? null,
    volumes ? null,
    environment ? null,
    ...
  }: image:
  concatStringsSep " " (
    [ "docker run"]
    ++ optional init "--init"
    ++ optional read_only "--read-only"
    ++ optional (network != null) "--network=${network}"
    ++ optionals (volumes != null) (map (v: "--mount ${setToCommaSep v}") volumes)
    ++ optionals (environment != null) (map (e: "-e ${e}") (setToKeyVal environment))
    ++ [ image ]
);


dockerAnnotations = {
  argHints = {
    init = true;
    read_only = true;
    network = "host";
    environment = { CACHE_PATH = "/home/nginx"; };
    volumes = [
      ({ type = "bind"; source = "/etc/nginx"; destination = "/read"; readonly = true; })  
      ({ type = "bind"; source = "/home"; destination = "/home"; readonly = true; })
      ({ type = "tmpfs"; destination = "/run"; })
    ];
  };
};

in

pkgs.dockerTools.buildLayeredImage rec {
  name = "docker-registry.intr/webservices/nginx";
  tag = "latest";
  maxLayers = 128;
  contents = [ nginx glibcLocales tzdata nginxConfLayer ];
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
  '';
  config = {
    Entrypoint = [ "${nginx}/bin/nginx" "-g" "daemon off;" "-p" "${nginxConfLayer}" ];
    Env = [
      "TZ=Europe/Moscow"
      "TZDIR=/share/zoneinfo"
      "LC_ALL=en_US.UTF-8"
      "LOCALE_ARCHIVE_2_27=${glibcLocales}/lib/locale/locale-archive"
    ];
    Labels = rec {
      "ru.majordomo.docker.arg-hints-json" = builtins.toJSON dockerAnnotations.argHints;
      "ru.majordomo.docker.cmd" = dockerRunCmd dockerAnnotations.argHints "${name}:${tag}";
      "ru.majordomo.docker.exec.reload-cmd" = "nginx -p ${nginxConfLayer} -s reload";
    };
  };
}
