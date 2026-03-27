{ pkgs }:

[
  (pkgs.stdenv.mkDerivation rec {
    pname = "simplex-chat";
    version = "6.4.10";

    src = pkgs.fetchurl {
      url = "https://github.com/simplex-chat/simplex-chat/releases/download/v${version}/simplex-chat-ubuntu-22_04-x86_64";
      sha256 = "sha256-dJoi2mHqLxYWPqBtb6h5pLIvRUp2Q0b15wg+qoGsGK8=";
    };

    nativeBuildInputs = [ pkgs.autoPatchelfHook ];

    buildInputs = with pkgs; [
      gmp
      libffi
      zlib
      ncurses
      openssl
    ];

    dontUnpack = true;

    installPhase = ''
      mkdir -p $out/bin
      cp $src $out/bin/simplex-chat
      chmod +x $out/bin/simplex-chat
    '';

    meta = with pkgs.lib; {
      description = "SimpleX Chat — private and secure messenger";
      homepage = "https://github.com/simplex-chat/simplex-chat";
      license = licenses.agpl3Only;
      mainProgram = "simplex-chat";
      platforms = [ "x86_64-linux" ];
    };
  })
]
