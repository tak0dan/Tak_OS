{ lib, stdenvNoCC, makeWrapper, bash, git, findutils }:

stdenvNoCC.mkDerivation {
  pname = "update-git-repos";
  version = "1.0.0";
  src = ../../scripts/update-git-repos.sh;
  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/libexec/update-git-repos"
    makeWrapper ${bash}/bin/bash "$out/bin/update-git-repos" \
      --add-flags "$out/libexec/update-git-repos" \
      --prefix PATH : ${lib.makeBinPath [ git findutils ]}
    runHook postInstall
  '';

  meta = with lib; {
    description = "Update configured Git repositories";
    platforms = platforms.linux;
    mainProgram = "update-git-repos";
  };
}
