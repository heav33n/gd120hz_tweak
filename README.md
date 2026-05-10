# GD120Hz Tweak
This tweak pushes Vanilla GD into achieving 120hz, in iOS.

This isn't normally in the main game, so I did this if you want to do this.

## Requirements
You need to provide your own decypted and unzipped IPA for Geometry Dash.
You are required to use Linux for the ``install.sh`` script. You can compile this tweak on macOS also, but I don't really know if it's possible to compile this on Windows.
Needs to have ``theos`` at home and ``ldid`` installed.

## Installation

<details>
  <summary><b>Automatic</b></summary>
  <br>
  Simply just run <code>install.sh</code> inside a terminal.
</details>

<details>
  <summary><b>Manual</b></summary>
  <br>
  You need to install the following packages:
  
  <code>git curl make perl python3 python3-pip python3-venv wget unzip llvm</code>

  Then create a python virtual environment where you will install lief:
  
  ```bash
python3 -m venv .venv

# if you have bash/zsh
source .venv/bin/activate
# if you have fish
source .venv/bin/activate.fish

pip install -q lief
```

  Then you can proceed to build the tweak with ``make``.

  ### Patching

  After building, run the following steps to patch the binary. Replace `/path/to/GeometryDash.app` with the actual path to your `.app` folder where `GeometryJump` is located.

  Copy the dylib into the app:

  ```bash
cp build/gd120hz.dylib /path/to/GeometryDash.app/gd120hz.dylib
```

  Inject rpath `@executable_path/.`:

  ```bash
llvm-install-name-tool -add_rpath "@executable_path/." /path/to/GeometryDash.app/GeometryJump
```

  Inject the dylib:

  ```bash
python3 - <<EOF
import lief
b = lief.MachO.parse("/path/to/GeometryDash.app/GeometryJump").at(0)
b.add_library("@executable_path/gd120hz.dylib")
b.write("/path/to/GeometryDash.app/GeometryJump")
EOF
```

  Inject rpath `@executable_path/Frameworks`:

  ```bash
llvm-install-name-tool -add_rpath "@executable_path/Frameworks" /path/to/GeometryDash.app/GeometryJump
```

  Replace OpenGLES with ANGLEGLKit:

  ```bash
llvm-install-name-tool -change \
    /System/Library/Frameworks/OpenGLES.framework/OpenGLES \
    @rpath/ANGLEGLKit.framework/ANGLEGLKit \
    /path/to/GeometryDash.app/GeometryJump
```

  Sign the binary and dylib:

  ```bash
ldid -S /path/to/GeometryDash.app/GeometryJump
ldid -S /path/to/GeometryDash.app/gd120hz.dylib
```
  
  Re-sign the IPA with a signing method of your choice (KravaSign, Sideloadly, AltStore, etc.) or reinstall it directly via a sideload method.
</details>

## License
MIT
