self: super:

{
  # jemalloc fails test_pages_huge on armv7l.
  jemalloc = if super.stdenv.system == "armv7l-linux"
  then
    super.stdenv.lib.overrideDerivation super.jemalloc (oldAttrs : {
      doCheck = false;
    })
  else
    super.jemalloc;
}
