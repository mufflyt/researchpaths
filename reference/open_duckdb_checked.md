# Open a DuckDB warehouse read-only, asserting the tables the caller needs

A table that exists but is EMPTY is treated as missing. An empty table
is the signature of the stub database, and a caller that proceeds from
it produces a confident answer about nothing.

## Usage

``` r
open_duckdb_checked(
  relative_path,
  volume_pattern,
  required_tables = character(),
  min_bytes = 1e+09,
  read_only = TRUE,
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

- required_tables:

  \[character\] must exist and be non-empty.

- min_bytes:

  \[numeric\] size floor. Default 1 GB: production warehouses are tens
  of GB and a freshly-created empty one is a few KB.

- read_only:

  \[logical\] TRUE. Set FALSE only to deliberately write.

- mount_root:

  \[character\] see resolve_volume().

- env_var:

  \[character\] optional variable naming an explicit full path.

- quiet:

  \[logical\] suppress progress messages.

## Value

a DBI connection; the caller must dbDisconnect().
