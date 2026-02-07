{ pkgs ? import <nixpkgs> {} }:

let
  bun = pkgs.bun;
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
    nativeBuildInputs = [ bun ];
    buildPhase = ''
      export HOME=$(mktemp -d)
      bun install --frozen-lockfile --ignore-scripts
    '';
    installPhase = ''
      cp -r node_modules $out
    '';
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "";
  };
in
pkgs.stdenv.mkDerivation {
  inherit name src;

  nativeBuildInputs = [ bun pkgs.makeWrapper ];

  buildPhase = ''
    export HOME=$(mktemp -d)
    cp -r ${node_modules} node_modules
    chmod -R u+w node_modules
    bun node_modules/.bin/svelte-kit sync
    bun node_modules/.bin/vite build
  '';

  installPhase = ''
    mkdir -p $out/bin $out/share/${name}
    cp -r build/* $out/share/${name}/
    makeWrapper ${bun}/bin/bun $out/bin/${name} \
      --add-flags "$out/share/${name}/index.js"
  '';
}
