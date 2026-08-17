# Resolve one file below a volume, whatever the volume is called

Searches EVERY matching volume, then narrows by existence and
(optionally) size. That is what separates the real database from the
stub left behind by the original bug: both volumes match the pattern,
only one holds a file big enough to be real.

## Usage

``` r
resolve_file_on_volume(
  relative_path,
  volume_pattern,
  must_exist = TRUE,
  min_bytes = NULL,
  mount_root = getOption("researchpaths.mount_root", "/Volumes"),
  env_var = NULL,
  quiet = TRUE
)
```

## Arguments

- relative_path:

  \[character\] path below the volume root.

- volume_pattern:

  \[character\] volume-name glob.

- must_exist:

  \[logical\] stop when nothing matches.

- min_bytes:

  \[numeric\] optional size floor; candidates below it are rejected as
  implausible.

- mount_root:

  \[character\] see resolve_volume().

- env_var:

  \[character\] optional variable naming an explicit full path.

- quiet:

  \[logical\] suppress progress messages.

## Value

\[character\] one resolved path, or NA when absent and must_exist.
