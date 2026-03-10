{ pkgs ? import <nixpkgs> {} }:

let
  nodejs = pkgs.nodejs_20;
  name = "telegram-bot";
  src = builtins.path {
    path = ./.;
    name = "telegram-bot-src";
    filter = path: type:
      let base = builtins.baseNameOf path; in
      base != ".env"
      && base != "result"
      && base != "node_modules";
  };
  node_modules = pkgs.stdenv.mkDerivation {
    name = "server-software-node_modules";
    inherit src;
     nativeBuildInputs = [ nodejs pkgs.makeWrapper pkgs.cacert ];
     buildPhase = ''
       export HOME=$(mktemp -d)
       export NODE_EXTRA_CA_CERTS=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
       npm config set cafile ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
       echo '>>> Installing dependencies (npm ci)...'
       npm ci --ignore-scripts
     '';

    installPhase = ''
      cp -r node_modules $out
    '';
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-T0D49nuRhj8WCEBKfUaBWDHL2bwZhBkWM65bIP2vlyo=";
  };
in
pkgs.stdenv.mkDerivation {
  inherit name src;

  nativeBuildInputs = [ nodejs pkgs.makeWrapper ];

   buildPhase = ''
    export HOME=$(mktemp -d)
    cp -r ${node_modules} node_modules
    chmod -R u+w node_modules
  '';


  installPhase = ''
    mkdir -p $out/bin $out/share/${name}
    cp -r bot.js package.json $out/share/${name}/
    cp -r node_modules $out/share/${name}/
    makeWrapper ${nodejs}/bin/node $out/bin/${name} \
      --add-flags "$out/share/${name}/bot.js"
  '';
}
