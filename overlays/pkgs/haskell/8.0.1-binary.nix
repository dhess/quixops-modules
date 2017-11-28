{stdenv, lib, fetchurl, llvm_37, dpkg, perl, ncurses5, gmp, libffi, binutils, coreutils, makeWrapper }:

let
  LD_LIBRARY_PATH = lib.makeLibraryPath
    [ gmp libffi ncurses5 ];
in
stdenv.mkDerivation rec {
  version = "8.0.1";

  name = "ghc-${version}-binary";

  src =
    if stdenv.system == "i686-linux" then
      fetchurl {
        url = "mirror://debian/pool/main/g/ghc/ghc_8.0.1-17+b1_i386.deb";
        sha256 = "6b98abfab0e53a0b08dae5044cbae36c3df36d8b13de3108f130c99ec582ec0b";
      }
    else if stdenv.system == "x86_64-linux" then
      fetchurl {
        url = "mirror://debian/pool/main/g/ghc/ghc_8.0.1-17+b1_amd64.deb";
        sha256 = "f7afab2b127b82637f741a8d8cd4cec4e688d8a85c05b5d732a2373b6dca7cbd";
      }
    else if stdenv.system == "armv7l-linux" then
      fetchurl {
        url = "mirror://debian/pool/main/g/ghc/ghc_8.0.1-17+b1_armhf.deb";
        sha256 = "eca4bac38246890b6e4a9ff20a6661b48e11f1ed87fcd166acde556ff7e09dcb";
      }
    else if stdenv.system == "aarch64-linux" then
      fetchurl {
        url = "mirror://debian/pool/main/g/ghc/ghc_8.0.1-17+b1_arm64.deb";
        sha256 = "d97f0cc49a18b2b9cb58abef4bf810ae0738de65bb448b4fc1cee2ccb14a4d64";
      }
    else throw "cannot bootstrap GHC on this platform";

  buildInputs = [ dpkg perl makeWrapper ];
  propagatedBuildInputs = [ llvm_37 ];

  dontConfigure = true;

  # Stripping combined with patchelf breaks the executables (they die
  # with a segfault or the kernel even refuses the execve). (NIXPKGS-85)
  dontStrip = true;

  # No building is necessary, but calling make without flags ironically
  # calls install-strip ...
  dontBuild = true;

  unpackPhase = "dpkg-deb -x $src .";

  # ARM-specific flags come from here:
  # https://wiki.debian.org/Haskell/GHC
  CC_FLAGS_ORIG = lib.optionalString (stdenv.system == "armv7l-linux") " -marm" + " -fno-stack-protector";
  CC_FLAGS = "-I ${libffi.dev}/include -I ${gmp.dev}/include" + "${CC_FLAGS_ORIG}";
  LD_FLAGS_ORIG = "" + lib.optionalString (stdenv.system == "armv7l-linux" || stdenv.system == "aarch64-linux") " -z noexecstack";
  LD_FLAGS = "-L ${gmp}/lib -L ${libffi}/lib" + "${LD_FLAGS_ORIG}";
  CC_LINK_FLAGS_ORIG = "" + lib.optionalString (stdenv.system == "armv7l-linux" || stdenv.system == "aarch64-linux") " -fuse-ld=gold -Wl,-z,noexecstack";
  CC_LINK_FLAGS = "-L ${gmp}/lib -L ${libffi}/lib" + "${CC_LINK_FLAGS_ORIG}";

  installPhase = ''
    mv usr/bin .
    rm usr/lib/ghc/package.conf.d
    mv usr/lib .
    mv var/lib/ghc/package.conf.d ./lib/ghc/package.conf.d
    rm -r usr/share/doc
    rm -r usr/share/lintian
    mv usr/share .

    rmdir usr
    rmdir var/lib/ghc
    rmdir var/lib
    rmdir var

    mkdir $out
    mv lib bin share $out
    cd $out

    # Patch settings/scripts to resemble Nix, rather than Debian.
    # Note: ghc-split doesn't exist on arm64.
    if [ -f lib/ghc/bin/ghc-split ] ; then
      substituteInPlace lib/ghc/bin/ghc-split --replace /usr/bin/perl ${perl}/bin/perl
    fi
    substituteInPlace lib/ghc/settings --replace /usr/bin/perl ${perl}/bin/perl
    substituteInPlace lib/ghc/settings --replace /usr/bin/gcc ${stdenv.cc}/bin/cc
    substituteInPlace lib/ghc/settings --replace /usr/bin/ld ${stdenv.cc}/bin/ld
    substituteInPlace lib/ghc/settings --replace /usr/bin/ar ${binutils}/bin/ar
    substituteInPlace lib/ghc/settings --replace '("C compiler supports -no-pie", "YES")' '("C compiler supports -no-pie", "NO")'
    substituteInPlace lib/ghc/settings --replace '("LLVM llc command", "llc-3.7")' '("LLVM llc command", "${llvm_37}/bin/llc")'
    substituteInPlace lib/ghc/settings --replace '("LLVM opt command", "opt-3.7")' '("LLVM opt command", "${llvm_37}/bin/opt")'

    for prog in ghc-8.0.1 ghci-8.0.1 ghc-pkg-8.0.1 haddock-ghc-8.0.1 hpc hsc2hs runghc-8.0.1; do
      substituteInPlace bin/$prog --replace /usr $out
    done

    for conf in $out/lib/ghc/package.conf.d/*.conf; do
      substituteInPlace $conf --replace /usr $out
    done

    find $out/lib -type f -name \*.so -exec ln -s {} lib/ghc \;

    find . -type f -perm -0100 \
        -exec patchelf --interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
        --set-rpath "${LD_LIBRARY_PATH}:$out/lib/ghc" {} \;

    # Need to tell ghc where to find gmp and ffi includes.
    substituteInPlace lib/ghc/settings --replace '("C compiler flags", "${CC_FLAGS_ORIG}")' '("C compiler flags", "${CC_FLAGS}")'
    # Need to tell ghc where to find libgmp.so and libffi.so at link time.
    substituteInPlace lib/ghc/settings --replace '("ld flags", "${LD_FLAGS_ORIG}")' '("ld flags", "${LD_FLAGS}")'
    substituteInPlace lib/ghc/settings --replace '("C compiler link flags", "${CC_LINK_FLAGS_ORIG}")' '("C compiler link flags", "${CC_LINK_FLAGS}")'

    # Generate the initial package.cache.
    $out/bin/ghc-pkg recache --global
  '';

  postInstall = ''
    paxmark m $out/lib/ghc/bin/{ghc,haddock}

    # Patch scripts to include "readelf" and "cat" in $PATH.
    for i in "$out/bin/"*; do
      test ! -h $i || continue
      egrep --quiet '^#!' <(head -n 1 $i) || continue
      sed -i -e '2i export PATH="$PATH:${stdenv.lib.makeBinPath [ binutils coreutils ]}"' $i
    done

    # Sanity check, can ghc create executables?
    cd $TMP
    mkdir test-ghc; cd test-ghc
    cat > main.hs << EOF
      {-# LANGUAGE TemplateHaskell #-}
      module Main where
      main = putStrLn \$([|"yes"|])
    EOF
    $out/bin/ghc --make main.hs || exit 1
    echo compilation ok
    [ $(./main) == "yes" ]
  '';

  meta.license = stdenv.lib.licenses.bsd3;
  meta.platforms = ["x86_64-linux" "i686-linux" "armv7l-linux" "aarch64-linux" ];
}
