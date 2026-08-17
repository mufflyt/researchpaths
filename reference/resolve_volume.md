# Mounted volumes matching a pattern

Mounted volumes matching a pattern

## Usage

``` r
resolve_volume(
  pattern,
  mount_root = getOption("researchpaths.mount_root", "/Volumes"),
  require_unique = TRUE
)
```

## Arguments

- pattern:

  \[character\] volume-name glob, e.g. "ExternalDrive\*".

- mount_root:

  \[character\] where volumes appear. "/Volumes" on macOS,
  "/media"/"/mnt" elsewhere; parameterised so this is testable without
  one.

- require_unique:

  \[logical\] stop when more than one matches. FALSE when a caller will
  disambiguate by validating what is ON each volume – which is the decoy
  case: two volumes match, only one holds a real database.

## Value

\[character\] absolute paths to matching volume roots.
