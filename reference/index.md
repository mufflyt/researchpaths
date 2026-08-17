# Package index

## Volumes

Discover a mount point by glob rather than by hardcoded name. A
removable volume remounts as “Name 1” after an unclean unmount, and a
hardcoded path then silently reads nothing.

- [`resolve_volume()`](https://mufflyt.github.io/researchpaths/reference/resolve_volume.md)
  : Mounted volumes matching a pattern

## Files on a volume

Locate a file relative to a discovered volume, validating it before any
caller opens it.

- [`resolve_file_on_volume()`](https://mufflyt.github.io/researchpaths/reference/resolve_file_on_volume.md)
  : Resolve one file below a volume, whatever the volume is called

## DuckDB

The layer that exists because DuckDB CREATES a database at a path that
does not exist. A typo in a warehouse path is therefore not an error but
an empty database, and a pipeline that reports success having measured
nothing. These two refuse to open a database that fails a size check.

- [`resolve_duckdb()`](https://mufflyt.github.io/researchpaths/reference/resolve_duckdb.md)
  : Resolve a DuckDB warehouse, with a size floor by default
- [`open_duckdb_checked()`](https://mufflyt.github.io/researchpaths/reference/open_duckdb_checked.md)
  : Open a DuckDB warehouse read-only, asserting the tables the caller
  needs
