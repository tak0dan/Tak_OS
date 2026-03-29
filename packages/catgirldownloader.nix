# catgirldownloader.nix — GTK4 catgirl image browser
# Upstream: https://github.com/NyarchLinux/CatgirlDownloader
# Original package by yunfachi (NixOwOS); adapted for plain nixpkgs callPackage.
#
# Image-size fix (postPatch): upstream window.py calls the deprecated
# GtkPicture.set_pixbuf() which does not report natural image dimensions
# to GTK4's layout engine, causing images to render at ~20×30 px.
# Fixed by using Gdk.Texture.new_for_pixbuf() + set_paintable() instead.
{
  lib,
  python3,
  gtk4,
  libadwaita,
  gobject-introspection,
  wrapGAppsHook3,
  meson,
  ninja,
  pkg-config,
  gettext,
  desktop-file-utils,
  fetchFromGitHub,
}:

python3.pkgs.buildPythonApplication rec {
  pname = "catgirldownloader";
  version = "0.3.0";

  src = fetchFromGitHub {
    owner = "NyarchLinux";
    repo = "CatgirlDownloader";
    rev = version;
    sha256 = "sha256-EGnxa8PY1B5ZJa+0RAGE0x4yB1eU666yBZfnOeG7rxA=";
  };

  pyproject = false;

  postPatch = ''
    python3 - <<'EOF'
import re

with open("src/window.py", "r") as f:
    c = f.read()

# Add Gdk to the gi.repository import line
c = c.replace(
    "from gi.repository import Gtk, Adw, GdkPixbuf, GLib, Gio, GObject",
    "from gi.repository import Gtk, Adw, Gdk, GdkPixbuf, GLib, Gio, GObject",
)

# Replace deprecated set_pixbuf (GtkPicture doesn't report natural size via
# this path) with set_paintable(Gdk.Texture) so content-fit=contain works.
c = c.replace(
    "            self.image.set_pixbuf(loader.get_pixbuf())",
    "            pixbuf = loader.get_pixbuf()\n"
    "            if pixbuf:\n"
    "                texture = Gdk.Texture.new_for_pixbuf(pixbuf)\n"
    "                self.image.set_paintable(texture)",
)

with open("src/window.py", "w") as f:
    f.write(c)
EOF
  '';

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    desktop-file-utils
    gettext
    gobject-introspection
    wrapGAppsHook3
  ];

  buildInputs = [
    gtk4
    libadwaita
  ];

  propagatedBuildInputs = with python3.pkgs; [
    pygobject3
    requests
  ];

  doCheck = false;

  meta = {
    description = "GTK4 application that downloads images of catgirls from nekos.moe";
    homepage = "https://github.com/NyarchLinux/CatgirlDownloader";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [ yunfachi ];
    platforms = lib.platforms.all;
  };
}
