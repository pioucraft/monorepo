{ pkgs ? import <nixpkgs> {} }:

let
  bun = pkgs.bun;
  name = "server-software";
  src = ./.;
in
pkgs.stdenv.mkDerivation {
  inherit name src;

  nativeBuildInputs = [ bun pkgs.makeWrapper ];

  buildPhase = ''
    export HOME=$(mktemp -d)
    bun install --frozen-lockfile --ignore-scripts
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
