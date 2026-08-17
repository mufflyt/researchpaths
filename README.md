# researchpaths

Resolve data paths on removable volumes without guessing — and without silently
creating the thing you were looking for.

## The problem this exists for

Removable volumes mount under whatever name the operating system decides. macOS
in particular leaves a stale mount point in `/Volumes` after an unclean unmount
and then remounts the same physical drive as `Name 1`. Code that hardcodes a
mount path then reads nothing.

That alone would be an ordinary "file not found". What makes it dangerous is
DuckDB: **`dbConnect()` creates a database when the path does not exist.** So the
failure is not an error. It is an empty warehouse, zero rows from every query,
and a pipeline that reports success having measured nothing.

This is not hypothetical. In the research repository this package came from,
two files with the same name sat on one drive:

| Path | Size | Tables |
|---|---:|---:|
| `…/DuckDB/nber_my_duckdb.duckdb` | 84.3 GB | 454 |
| `…/nber_my_duckdb.duckdb` | **12 KB** | **0** |

The second was created by scripts pointed at a path that no longer existed. 80
executable lines across 75 files referenced it. Eleven of those only called
`dbListTables()`, so an empty database answered without complaint and they
reported *"this warehouse has no tables"* as a finding.

## Rules

1. Discovery is a **glob** over the volume name, never a literal.
2. Discovery **never creates, opens or modifies** a candidate — it touches the
   filesystem only through `Sys.glob()` and `file.info()`.
3. A candidate must **look like** the real thing (size floor) before it is
   accepted.
4. Zero candidates is an error. Several plausible candidates is an error.
   Guessing between two mounted drives silently decides which data an analysis
   ran on.
5. An environment override is honoured but **still validated**. A typo in
   `RESEARCHPATHS_ROOT` must fail, not create a database somewhere new.
6. Connections are **read-only** unless a caller deliberately asks otherwise.

## Usage

```r
# Where is the drive, whatever it is called today?
root <- resolve_volume("MyDrive*")

# One file below it
csv <- resolve_file_on_volume("NPPES/npidata_pfile.csv", "MyDrive*")

# A DuckDB warehouse, with a mandatory size floor
db <- resolve_duckdb("DuckDB/warehouse.duckdb", "MyDrive*")

# ...or open it read-only, asserting the tables you need exist AND are non-empty
con <- open_duckdb_checked(
  relative_path   = "DuckDB/warehouse.duckdb",
  volume_pattern  = "MyDrive*",
  required_tables = c("npi_org_all")
)
```

An empty required table is treated as a **missing** one. That is the whole point:
a caller that proceeds from an empty table produces a confident answer about
nothing.

## Per-repo wrappers

Keep the filesystem mechanics here and let each repository declare what *it*
considers valid:

```r
my_warehouse <- function(required_tables = character()) {
  researchpaths::open_duckdb_checked(
    relative_path   = "DuckDB/warehouse.duckdb",
    volume_pattern  = "MyDrive*",
    required_tables = required_tables
  )
}
```

If your repository **already** has a generic path resolver, use it and layer only
the DuckDB guarantees on top. Two independently maintained implementations of a
safety-critical filesystem rule is the failure mode, not the fix — a migration
that added a second resolver to 324 files before noticing the first one is what
prompted that sentence.

## Tests

The canonical bug reproduction ships with the package: a 100-byte decoy under one
mount spelling, a valid fixture under another. The resolver must choose the valid
one and leave **both files byte- and mtime-identical**, because if discovery
could modify a candidate then merely looking for the database would manufacture
the decoy.

```r
testthat::test_dir("tests/testthat")
```

## Install

```r
remotes::install_github("mufflyt/researchpaths")
```

## Licence

MIT
