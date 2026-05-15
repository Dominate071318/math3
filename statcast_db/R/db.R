## Database connection and write helpers

open_db <- function(db_path) {
  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  DBI::dbExecute(con, "PRAGMA journal_mode = WAL")
  DBI::dbExecute(con, "PRAGMA synchronous  = NORMAL")
  DBI::dbExecute(con, "PRAGMA foreign_keys = ON")
  con
}

close_db <- function(con) {
  DBI::dbDisconnect(con)
}

# Append a data frame to the statcast table, skipping duplicate sv_id rows
write_statcast <- function(con, df) {
  if (is.null(df) || nrow(df) == 0) return(0L)
  df <- normalise_columns(df)
  df <- df[!is.na(df$sv_id) & nchar(df$sv_id) > 0, ]
  if (nrow(df) == 0) return(0L)

  # Remove rows whose sv_id already exists (idempotent loads)
  existing_sv <- DBI::dbGetQuery(
    con,
    sprintf(
      "SELECT sv_id FROM statcast WHERE sv_id IN (%s)",
      paste(sprintf("'%s'", df$sv_id), collapse = ",")
    )
  )$sv_id
  df <- df[!df$sv_id %in% existing_sv, ]
  if (nrow(df) == 0) return(0L)

  DBI::dbAppendTable(con, "statcast", df)
  nrow(df)
}

log_fetch <- function(con, date_str, rows_added) {
  DBI::dbExecute(
    con,
    "INSERT INTO fetch_log (date_pulled, rows_added) VALUES (?, ?)",
    params = list(date_str, rows_added)
  )
}

db_summary <- function(con) {
  total  <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM statcast")$n
  years  <- DBI::dbGetQuery(
    con, "SELECT DISTINCT game_year FROM statcast ORDER BY game_year"
  )$game_year
  latest <- DBI::dbGetQuery(
    con, "SELECT MAX(game_date) AS d FROM statcast"
  )$d
  list(total_pitches = total, years = years, latest_date = latest)
}
