# Nixorcist — Python DSL-based package/profile management tool.
# Declared as a plain package (NOT a flake input) via nixpkgs' callPackage.
# Source: github.com/tak0dan/nixorcist-py
#
# Pinned to the nixorcist-py revision the config is verified against.
# Bump `rev` and `sha256` together (nix-prefetch-url --unpack <archive-url>).
{ lib
, python3
, fetchFromGitHub
}:

python3.pkgs.buildPythonApplication rec {
  pname = "nixorcist";
  version = "0.1.0";
  format = "pyproject";

  src = fetchFromGitHub {
    owner = "tak0dan";
    repo = "nixorcist-py";
    rev = "118b425c0b5ca1d0c61177e04e8f7f71efa5c4ee";
    sha256 = "sha256-lr9itOVeqA/vXpJnztxI1k6Aa2yWqFkBIg3mIpthNvs=";
  };

  nativeBuildInputs = [ python3.pkgs.setuptools ];

  postInstall = ''
    mkdir -p $out/share/zsh/site-functions
    cp $src/src/nixorcist/cli/_nist $out/share/zsh/site-functions/_nist
  '';

  pythonImportsCheck = [ "nixorcist" ];

  meta = with lib; {
    description = "Higher-level Nix package/profile management and configuration promotion tool";
    homepage = "https://github.com/tak0dan/nixorcist-py";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "nixorcist";
  };
}
