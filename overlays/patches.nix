self: super:

let

in
{
  gitaly = super.stdenv.lib.overrideDerivation super.gitaly (oldAttrs: {
    patches = (oldAttrs.patches or []) ++ [ ./patches/gitaly.patch ];
  });
}
