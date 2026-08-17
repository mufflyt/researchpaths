# =============================================================================
# The canonical reproduction of the bug this package exists for
# =============================================================================
#   <mount_root>/
#     MufflySamsung/   DuckDB/warehouse.duckdb    100 bytes  <- decoy stub
#     MufflySamsung 1/ DuckDB/warehouse.duckdb  5,000 bytes  <- the real thing
#
# The resolver must choose the real one, and must leave BOTH files byte- and
# mtime-identical: if discovery could create or modify a candidate, then merely
# looking for the database would manufacture the decoy.
#
# Fixtures are scaled (5,000 vs 100 bytes with a scaled floor) because the
# invariant is "a size floor separates a real warehouse from a freshly-created
# stub", which holds at any scale. Writing multi-GB fixtures would test the
# filesystem instead. The shipped default floor is asserted separately.
# =============================================================================

fixture <- function(vols) {
  root <- withr_tempdir()
  for (nm in names(vols)) {
    d <- file.path(root, nm, "DuckDB")
    dir.create(d, recursive = TRUE, showWarnings = FALSE)
    con <- file(file.path(d, "warehouse.duckdb"), "wb")
    writeBin(as.raw(rep(0L, vols[[nm]])), con); close(con)
  }
  root
}
withr_tempdir <- function() {
  p <- file.path(tempdir(), paste0("rp-", sample.int(1e9, 1)))
  dir.create(p, recursive = TRUE, showWarnings = FALSE)
  p
}
MINB <- 1000

test_that("the real warehouse is chosen over the decoy stub", {
  root <- fixture(list("MufflySamsung" = 100, "MufflySamsung 1" = 5000))
  real  <- file.path(root, "MufflySamsung 1", "DuckDB", "warehouse.duckdb")
  decoy <- file.path(root, "MufflySamsung",   "DuckDB", "warehouse.duckdb")
  before <- file.info(c(real, decoy))[, c("size", "mtime")]

  got <- resolve_file_on_volume("DuckDB/warehouse.duckdb", "MufflySamsung*",
                                min_bytes = MINB, mount_root = root)
  expect_equal(normalizePath(got), normalizePath(real))

  # The load-bearing assertion: discovery touched nothing.
  expect_identical(file.info(c(real, decoy))[, c("size", "mtime")], before)
  expect_true(file.exists(decoy))   # left in place, not "cleaned up"
})

test_that("the volume name does not matter", {
  for (nm in c("MufflySamsung", "MufflySamsung 1", "MufflySamsung 2")) {
    root <- fixture(stats::setNames(list(5000), nm))
    got <- resolve_file_on_volume("DuckDB/warehouse.duckdb", "MufflySamsung*",
                                  min_bytes = MINB, mount_root = root)
    expect_equal(normalizePath(got),
                 normalizePath(file.path(root, nm, "DuckDB", "warehouse.duckdb")))
  }
})

test_that("zero candidates is an error, never a hardcoded fallback", {
  root <- withr_tempdir()
  expect_error(resolve_file_on_volume("DuckDB/warehouse.duckdb", "MufflySamsung*",
                                      min_bytes = MINB, mount_root = root),
               "no mounted volume matches")
})

test_that("only-implausible candidates is an error, not 'use the biggest'", {
  root <- fixture(list("MufflySamsung" = 100, "MufflySamsung 1" = 200))
  expect_error(resolve_file_on_volume("DuckDB/warehouse.duckdb", "MufflySamsung*",
                                      min_bytes = MINB, mount_root = root),
               "below the")
})

test_that("two plausible warehouses is an error, not a silent choice", {
  root <- fixture(list("MufflySamsung 2" = 5000, "MufflySamsung 3" = 6000))
  expect_error(resolve_file_on_volume("DuckDB/warehouse.duckdb", "MufflySamsung*",
                                      min_bytes = MINB, mount_root = root),
               "resolves on 2 volumes")
})

test_that("a bad environment override fails instead of creating anything", {
  withr_env <- function(k, v, expr) {
    old <- Sys.getenv(k, unset = NA)
    do.call(Sys.setenv, stats::setNames(list(v), k))
    on.exit(if (is.na(old)) Sys.unsetenv(k)
            else do.call(Sys.setenv, stats::setNames(list(old), k)))
    force(expr)
  }
  root <- fixture(list("MufflySamsung 1" = 5000))
  withr_env("RP_TEST_DB", file.path(tempdir(), "definitely-not-here.duckdb"), {
    expect_error(resolve_file_on_volume("DuckDB/warehouse.duckdb", "MufflySamsung*",
                                        min_bytes = MINB, mount_root = root,
                                        env_var = "RP_TEST_DB"),
                 "does not exist")
  })
  # A typo'd ROOT must fail too, not fall through to discovery.
  withr_env("RESEARCHPATHS_ROOT", "/Volumes/MuflySamsung", {
    expect_error(resolve_volume("MufflySamsung*", mount_root = root),
                 "does not exist")
  })
})

test_that("discovery never opens a database", {
  # resolve_* must not depend on DBI/duckdb at all: if it needed a connection to
  # decide, it could create the file it was inspecting.
  fns <- c(deparse(resolve_volume), deparse(resolve_file_on_volume),
           deparse(resolve_duckdb))
  expect_false(any(grepl("dbConnect|duckdb::duckdb", fns)))
})

test_that("the shipped DuckDB floor would reject a real stub", {
  # 12,288 bytes is the actual size of the empty database the original bug left
  # behind on the drive.
  expect_true(formals(resolve_duckdb)$min_bytes >= 1e9)
  expect_lt(12288, eval(formals(resolve_duckdb)$min_bytes))
})

test_that("resolve_volume refuses to guess between two mounted drives", {
  root <- fixture(list("MufflySamsung" = 5000, "MufflySamsung 1" = 5000))
  expect_error(resolve_volume("MufflySamsung*", mount_root = root),
               "volumes match")
  # ...but allows several when the caller will disambiguate by content, which
  # is exactly how the decoy case is resolved.
  expect_length(resolve_volume("MufflySamsung*", mount_root = root,
                               require_unique = FALSE), 2L)
})
