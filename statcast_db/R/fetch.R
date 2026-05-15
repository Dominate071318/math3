## Statcast data fetching helpers using baseballr

MAX_ROWS_PER_CALL <- 25000   # Baseball Savant caps ~40k; stay under it

# Pull one day of Statcast data with retry logic
fetch_day <- function(date, game_type = "R", verbose = TRUE) {
  date_str <- format(as.Date(date), "%Y-%m-%d")
  if (verbose) message("  Fetching ", date_str, " ...")

  result <- tryCatch(
    baseballr::statcast_search(
      start_date = date_str,
      end_date   = date_str,
      player_type = "batter",
      game_type  = game_type
    ),
    error = function(e) {
      message("  ERROR on ", date_str, ": ", conditionMessage(e))
      NULL
    }
  )

  if (is.null(result) || nrow(result) == 0) return(NULL)
  result
}

# Retry wrapper with exponential back-off
fetch_day_with_retry <- function(date, game_type = "R", max_tries = 3,
                                 verbose = TRUE) {
  for (attempt in seq_len(max_tries)) {
    out <- fetch_day(date, game_type, verbose)
    if (!is.null(out)) return(out)
    if (attempt < max_tries) {
      wait <- 2^attempt
      message("  Retrying in ", wait, "s ...")
      Sys.sleep(wait)
    }
  }
  NULL
}

# Enumerate all MLB regular-season dates for a given year
season_dates <- function(year) {
  # Baseball Savant holds data back to 2015; Statcast tracking started 2015-04-05
  start <- as.Date(paste0(year, "-03-20"))
  end   <- as.Date(paste0(year, "-11-05"))
  seq(start, end, by = "day")
}

# Determine which dates are not yet in the DB
missing_dates <- function(con, dates) {
  if (!DBI::dbExistsTable(con, "statcast")) return(dates)

  present <- DBI::dbGetQuery(
    con,
    "SELECT DISTINCT game_date FROM statcast"
  )$game_date

  dates[!format(dates, "%Y-%m-%d") %in% present]
}

# Normalise column names coming from baseballr so they match the schema
normalise_columns <- function(df) {
  schema_cols <- c(
    "game_date", "game_pk", "at_bat_number", "pitch_number",
    "batter", "pitcher", "batter_name", "pitcher_name",
    "home_team", "away_team", "inning", "inning_topbot",
    "outs_when_up", "balls", "strikes",
    "on_1b", "on_2b", "on_3b", "stand", "p_throws",
    "pitch_type", "pitch_name", "release_speed", "release_spin_rate",
    "release_extension", "release_pos_x", "release_pos_y", "release_pos_z",
    "spin_axis", "pfx_x", "pfx_z", "plate_x", "plate_z",
    "vx0", "vy0", "vz0", "ax", "ay", "az", "zone",
    "description", "type", "events", "bb_type", "hit_location",
    "hc_x", "hc_y",
    "launch_speed", "launch_angle", "launch_speed_angle",
    "estimated_ba_using_speedangle", "estimated_woba_using_speedangle",
    "woba_value", "woba_denom", "babip_value", "iso_value",
    "hit_distance_sc", "if_fielding_alignment", "of_fielding_alignment",
    "delta_run_exp", "delta_home_win_exp",
    "bat_score", "fld_score", "post_bat_score", "post_fld_score",
    "game_year", "game_type", "sv_id"
  )

  # Keep only columns present in both the data and the schema
  keep <- intersect(names(df), schema_cols)
  df   <- df[, keep, drop = FALSE]

  # Add any missing schema columns as NA
  missing <- setdiff(schema_cols, names(df))
  for (col in missing) df[[col]] <- NA

  df[, schema_cols]
}
