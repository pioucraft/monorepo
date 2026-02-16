{ pkgs ? import <nixpkgs> {} }:

let
  nodejs = pkgs.nodejs_20;
  name = "server-software";
  src = builtins.path {
    path = ./.;
    name = "server-software-src";
    filter = path: type:
      let base = builtins.baseNameOf path; in
      base != ".svelte-kit"
      && base != "build"
      && base != "result"
      && base != ".env"
      && base != "node_modules";
  };
  node_modules = pkgs.stdenv.mkDerivation {
    name = "server-software-node_modules";
    inherit src;
    nativeBuildInputs = [ nodejs pkgs.makeWrapper ];
    buildPhase = ''
      export HOME=$(mktemp -d)
      npm install --ignore-scripts
    '';
    installPhase = ''
      cp -r node_modules $out
    '';
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-yUkMLb8Zl9btWLBukxoVKxbG13NzzwehqwYX5bAOs2k=";
  };
in
pkgs.stdenv.mkDerivation {
  inherit name src;

  nativeBuildInputs = [ nodejs pkgs.makeWrapper ];

  buildPhase = ''
    export HOME=$(mktemp -d)
    cp -r ${node_modules} node_modules
    chmod -R u+w node_modules
    node node_modules/.bin/svelte-kit sync
    node node_modules/.bin/vite build
  '';

  installPhase = ''
    mkdir -p $out/bin $out/share/${name}
    cp -r build/* $out/share/${name}/
    cp -r node_modules $out/share/${name}/
    makeWrapper ${nodejs}/bin/node $out/bin/${name} \
      --add-flags "$out/share/${name}/index.js"
  '';
}
