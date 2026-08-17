# =============================================================================
# Removable volumes mount under whatever name the OS decides. Code should not
# care, and must never be able to silently create the thing it was looking for.
# =============================================================================
# THE INCIDENT THIS PACKAGE EXISTS FOR.
#
# macOS leaves a stale mount point in /Volumes after an unclean unmount and then
# mounts the real disk with " 1" appended. The same physical drive is
# /Volumes/MufflySamsung on one boot and /Volumes/MufflySamsung 1 on the next.
# A research repo had hardcoded the first spelling in eight scripts.
#
# That alone would be a trivial "file not found". What made it dangerous is that
# DuckDB CREATES a database when the path does not exist. So the failure was not
# an error: it was a 12 KB empty warehouse, zero rows from every query, and a
# pipeline that reported success having measured nothing. Both files were left
# on the drive:
#
#   /Volumes/MufflySamsung 1/DuckDB/nber_my_duckdb.duckdb   84.3 GB, 454 tables
#   /Volumes/MufflySamsung 1/nber_my_duckdb.duckdb           12 KB,   0 tables
#
# An analysis run against the second finds nothing and looks clean.
#
# THE RULES THIS PACKAGE ENFORCES.
#
#   1. Discovery is a GLOB over the volume name, never a literal.
#   2. Discovery NEVER creates, opens or modifies a candidate. It touches the
#      filesystem only through Sys.glob() and file.info().
#   3. A candidate must LOOK like the real thing (size floor) before it is
#      accepted.
#   4. Zero candidates is an error. Several plausible candidates is an error.
#      Guessing between two mounted drives silently decides which data an
#      analysis ran on.
#   5. An environment override is honoured but still validated. A typo in
#      RESEARCHPATHS_ROOT must fail, not create a new database.
#   6. Connections are read-only unless a caller deliberately asks otherwise.
# =============================================================================

RESEARCHPATHS_ROOT_ENV <- "RESEARCHPATHS_ROOT"

#' Mounted volumes matching a pattern
#'
#' @param pattern [character] volume-name glob, e.g. "MufflySamsung*".
#' @param mount_root [character] where volumes appear. "/Volumes" on macOS,
#'   "/media"/"/mnt" elsewhere; parameterised so this is testable without one.
#' @param require_unique [logical] stop when more than one matches. FALSE when a
#'   caller will disambiguate by validating what is ON each volume -- which is
#'   the decoy case: two volumes match, only one holds a real database.
#' @return [character] absolute paths to matching volume roots.
#' @export
resolve_volume <- function(pattern,
                           mount_root = getOption("researchpaths.mount_root", "/Volumes"),
                           require_unique = TRUE) {
  root <- Sys.getenv(RESEARCHPATHS_ROOT_ENV, "")
  if (nzchar(root)) {
    if (!dir.exists(root))
      stop(sprintf(paste("%s points at a directory that does not exist:\n  %s\n",
                         " Refusing to continue -- a typo here is how an empty",
                         "database gets created at a wrong path."),
                   RESEARCHPATHS_ROOT_ENV, root), call. = FALSE)
    return(root)
  }
  hits <- Sys.glob(file.path(mount_root, pattern))
  hits <- hits[dir.exists(hits)]
  if (!length(hits))
    stop(sprintf(paste("no mounted volume matches %s under %s.\n",
                       " Mount the drive or set %s."),
                 pattern, mount_root, RESEARCHPATHS_ROOT_ENV), call. = FALSE)
  if (require_unique && length(hits) > 1L)
    stop(sprintf(paste("%d volumes match %s:\n  %s\n",
                       " Choosing one would silently decide which drive's data",
                       "was used. Set %s."),
                 length(hits), pattern, paste(hits, collapse = "\n  "),
                 RESEARCHPATHS_ROOT_ENV), call. = FALSE)
  hits
}

#' Resolve one file below a volume, whatever the volume is called
#'
#' Searches EVERY matching volume, then narrows by existence and (optionally)
#' size. That is what separates the real database from the stub left behind by
#' the original bug: both volumes match the pattern, only one holds a file big
#' enough to be real.
#'
#' @param relative_path [character] path below the volume root.
#' @param volume_pattern [character] volume-name glob.
#' @param must_exist [logical] stop when nothing matches.
#' @param min_bytes [numeric] optional size floor; candidates below it are
#'   rejected as implausible.
#' @param mount_root [character] see resolve_volume().
#' @param env_var [character] optional variable naming an explicit full path.
#' @param quiet [logical] suppress progress messages.
#' @return [character] one resolved path, or NA when absent and must_exist.
#' @export
resolve_file_on_volume <- function(relative_path,
                                   volume_pattern,
                                   must_exist = TRUE,
                                   min_bytes = NULL,
                                   mount_root = getOption("researchpaths.mount_root", "/Volumes"),
                                   env_var = NULL,
                                   quiet = TRUE) {
  if (!is.null(env_var) && nzchar(env_var)) {
    ov <- Sys.getenv(env_var, "")
    if (nzchar(ov)) {
      if (!file.exists(ov))
        stop(sprintf(paste("%s points at a file that does not exist:\n  %s\n",
                           " Refusing to continue -- an unvalidated override is",
                           "how an empty database gets created."), env_var, ov),
             call. = FALSE)
      if (!quiet) message("Resolved from ", env_var, ": ", ov)
      return(ov)
    }
  }
  vols <- resolve_volume(volume_pattern, mount_root = mount_root,
                         require_unique = FALSE)
  cand <- file.path(vols, relative_path)
  cand <- cand[file.exists(cand)]
  if (!quiet) message("Candidates found: ", length(cand))

  if (!is.null(min_bytes)) {
    sz <- file.info(cand)$size
    kept <- cand[!is.na(sz) & sz >= min_bytes]
    if (!quiet) message("Plausible after size validation: ", length(kept))
    if (length(cand) && !length(kept) && must_exist)
      stop(sprintf(paste("every candidate for %s is below the %.0f-byte floor:",
                         "\n  %s\n  A file this small is a stub created by",
                         "pointing at a wrong path, not the real data."),
                   relative_path, min_bytes,
                   paste(sprintf("%s (%d bytes)", cand, file.info(cand)$size),
                         collapse = "\n  ")), call. = FALSE)
    cand <- kept
  }

  if (length(cand) == 1L) {
    if (!quiet) message("Resolved: ", cand)
    return(cand)
  }
  if (length(cand) > 1L)
    stop(sprintf(paste("%s resolves on %d volumes:\n  %s\n",
                       " Guessing would silently pick one drive's data over",
                       "another's. Set %s."),
                 relative_path, length(cand), paste(cand, collapse = "\n  "),
                 RESEARCHPATHS_ROOT_ENV), call. = FALSE)
  if (must_exist)
    stop(sprintf(paste("%s not found on any volume matching %s.\n",
                       " Refusing to fall back to a hardcoded path."),
                 relative_path, volume_pattern), call. = FALSE)
  NA_character_
}

#' Resolve a DuckDB warehouse, with a size floor by default
#'
#' A separate entry point from resolve_file_on_volume() because the size floor
#' is not optional here: a DuckDB path that does not exist gets CREATED on
#' connect, so an unvalidated warehouse path is the whole hazard.
#'
#' @inheritParams resolve_file_on_volume
#' @param min_bytes [numeric] size floor. Default 1 GB: production warehouses
#'   are tens of GB and a freshly-created empty one is a few KB.
#' @export
resolve_duckdb <- function(relative_path,
                           volume_pattern,
                           min_bytes = 1e9,
                           mount_root = getOption("researchpaths.mount_root", "/Volumes"),
                           env_var = NULL,
                           quiet = TRUE) {
  resolve_file_on_volume(relative_path, volume_pattern, must_exist = TRUE,
                         min_bytes = min_bytes, mount_root = mount_root,
                         env_var = env_var, quiet = quiet)
}

#' Open a DuckDB warehouse read-only, asserting the tables the caller needs
#'
#' A table that exists but is EMPTY is treated as missing. An empty table is the
#' signature of the stub database, and a caller that proceeds from it produces a
#' confident answer about nothing.
#'
#' @inheritParams resolve_duckdb
#' @param required_tables [character] must exist and be non-empty.
#' @param read_only [logical] TRUE. Set FALSE only to deliberately write.
#' @return a DBI connection; the caller must dbDisconnect().
#' @export
open_duckdb_checked <- function(relative_path,
                                volume_pattern,
                                required_tables = character(),
                                min_bytes = 1e9,
                                read_only = TRUE,
                                mount_root = getOption("researchpaths.mount_root", "/Volumes"),
                                env_var = NULL,
                                quiet = TRUE) {
  if (!requireNamespace("DBI", quietly = TRUE) ||
      !requireNamespace("duckdb", quietly = TRUE))
    stop("open_duckdb_checked() needs DBI and duckdb installed.", call. = FALSE)

  p <- resolve_duckdb(relative_path, volume_pattern, min_bytes = min_bytes,
                      mount_root = mount_root, env_var = env_var, quiet = quiet)
  # Belt and braces: resolve_duckdb() already required existence, but this is
  # the last line before a call that would CREATE the file.
  if (!file.exists(p))
    stop(sprintf("refusing to open a warehouse that does not exist: %s", p),
         call. = FALSE)

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = p, read_only = read_only)
  ok <- FALSE
  on.exit(if (!ok) try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE),
          add = TRUE)

  have <- DBI::dbListTables(con)
  missing <- setdiff(required_tables, have)
  if (length(missing))
    stop(sprintf("%s has %d table(s) but not: %s\n  This is the wrong database.",
                 p, length(have), paste(missing, collapse = ", ")), call. = FALSE)
  for (tb in required_tables) {
    n <- DBI::dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM %s", tb))$n
    if (!length(n) || is.na(n) || n == 0L)
      stop(sprintf(paste("%s in %s is EMPTY.\n  An empty table is treated as a",
                         "missing one: a run over it reports zero findings and",
                         "looks like a clean result."), tb, p), call. = FALSE)
  }
  ok <- TRUE
  con
}
