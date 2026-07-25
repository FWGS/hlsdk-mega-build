# Mod patches

Patches in `patches/<branch>/*.patch` are applied with `git apply` in
lexicographic order after the branch (or pinned `commit`) is checked out,
before the build starts. A patch that fails to apply fails the mod's build
for that platform.

Use this as a last resort for changes upstream refuses to take — prefer
sending fixes upstream. Builds with patches applied are marked with
`"patched": true` in their `manifest.json` source metadata, since the
recorded tree hash refers to the unpatched upstream commit.

Layout example:

```
patches/
  field_intensity_1.7/
    0001-fix-cxx-standard.patch
    0002-something-else.patch
```

The directory name must match the manifest entry's `branch` value.
