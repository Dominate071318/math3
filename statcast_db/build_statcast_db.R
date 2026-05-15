## Build (or update) a local SQLite Statcast database
##
## Usage:
##   Rscript build_statcast_db.R [--years 2023,2024] [--db path/to/statcast.db]
##                               [--game-type R] [--verbose]
##
## Defaults:
##   --years     current season
##   --db        statcast.db  (in the working directory)
##   --game-type R  (regular season; use W for World Series, etc.)

suppressPackageStartupMessages({
  library(baseballr)
  library(DBI)
  library(RSQLite)
})

# ---------------------------------------------------------------------------
# Source helper modules
# ---------------------------------------------------------------------------
script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(script_dir, "R", "schema.R"))
source(file.path(script_dir, "R", "fetch.R"))
source(file.path(script_dir, "R", "db.R"))

`%||%` <- function(a, b) if (!is.null(a)) a else b

# ---------------------------------------------------------------------------
# Parse command-line arguments
# ---------------------------------------------------------------------------
parse_args <- function() {
  args   <- commandArgs(trailingOnly = TRUE)
  result <- list(
    years      = as.integer(format(Sys.Date(), "%Y")),
    db         = "statcast.db",
    game_type  = "R",
    verbose    = FALSE
  )

  i <- 1L
  while (i <= length(args)) {
    switch(args[[i]],
      "--years" = {
        i <- i + 1L
        result$years <- as.integer(strsplit(args[[i]], ",")[[1]])
      },
      "--db" = {
        i <- i + 1L
        result$db <- args[[i]]
      },
      "--game-type" = {
        i <- i + 1L
        result$game_type <- args[[i]]
      },
      "--verbose" = {
        result$verbose <- TRUE
      }
    )
    i <- i + 1L
  }
  result
}

# ---------------------------------------------------------------------------
# Main build routine
# ---------------------------------------------------------------------------
build_db <- function(years, db_path, game_type = "R", verbose = FALSE) {
  message("Opening database: ", db_path)
  con <- open_db(db_path)
  on.exit(close_db(con), add = TRUE)

  # Ensure schema exists
  create_statcast_table(con)
  create_indexes(con)
  create_log_table(con)

  total_new <- 0L

  for (yr in years) {
    message("\n=== Season ", yr, " ===")
    dates <- season_dates(yr)
    dates <- dates[dates <= Sys.Date()]           # don't fetch future dates
    dates <- missing_dates(con, dates)

    if (length(dates) == 0) {
      message("  All dates already in database. Skipping.")
      next
    }
    message("  Fetching ", length(dates), " date(s) ...")

    for (d in dates) {
      df   <- fetch_day_with_retry(d, game_type, verbose = verbose)
      rows <- write_statcast(con, df)
      log_fetch(con, format(as.Date(d, origin = "1970-01-01"), "%Y-%m-%d"), rows)
      total_new <- total_new + rows
      if (verbose) message("    +", rows, " rows")
    }
  }

  summary <- db_summary(con)
  message(
    "\nDone. Total pitches in DB: ", summary$total_pitches,
    "  |  Years: ", paste(summary$years, collapse = ", "),
    "  |  Latest date: ", summary$latest_date,
    "\nNew rows added this run: ", total_new
  )
  invisible(summary)
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
cfg <- parse_args()
build_db(
  years     = cfg$years,
  db_path   = cfg$db,
  game_type = cfg$game_type,
  verbose   = cfg$verbose
)
