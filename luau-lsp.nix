{ lib, stdenv, fetchzip, pkgs }:

stdenv.mkDerivation rec {
  name = "luau-lsp";
  src = fetchzip {
    url =
      "https://github.com/JohnnyMorganz/luau-lsp/releases/download/1.58.0/luau-lsp-linux-x86_64.zip";
    sha256 = "aZP3pjcNWfrkb3ADE/R2sEYdSuPYuW2d9zCj2La80X4=";
  };

  nativeBuildInputs = [ pkgs.autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];

  installPhase = ''
    mkdir -p $out/bin
    cp -r $src/luau-lsp $out/bin
  '';
}
