# Resolve a DuckDB warehouse, with a size floor by default

A separate entry point from resolve_file_on_volume() because the size
floor is not optional here: a DuckDB path that does not exist gets
CREATED on connect, so an unvalidated warehouse path is the whole
hazard.

## Usage

``` r
resolve_duckdb(
  relative_path,
  volume_pattern,
  min_bytes = 1e+09,
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

- min_bytes:

  \[numeric\] size floor. Default 1 GB: production warehouses are tens
  of GB and a freshly-created empty one is a few KB.

- mount_root:

  \[character\] see resolve_volume().

- env_var:

  \[character\] optional variable naming an explicit full path.

- quiet:

  \[logical\] suppress progress messages.
