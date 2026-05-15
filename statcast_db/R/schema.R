## Database schema creation and index management

create_statcast_table <- function(con) {
  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS statcast (
      pitch_id          INTEGER PRIMARY KEY AUTOINCREMENT,
      game_date         TEXT,
      game_pk           INTEGER,
      at_bat_number     INTEGER,
      pitch_number      INTEGER,

      -- Identifiers
      batter            INTEGER,
      pitcher           INTEGER,
      batter_name       TEXT,
      pitcher_name      TEXT,
      home_team         TEXT,
      away_team         TEXT,
      inning            INTEGER,
      inning_topbot     TEXT,
      outs_when_up      INTEGER,
      balls             INTEGER,
      strikes           INTEGER,
      on_1b             INTEGER,
      on_2b             INTEGER,
      on_3b             INTEGER,
      stand             TEXT,
      p_throws          TEXT,

      -- Pitch characteristics
      pitch_type        TEXT,
      pitch_name        TEXT,
      release_speed     REAL,
      release_spin_rate REAL,
      release_extension REAL,
      release_pos_x     REAL,
      release_pos_y     REAL,
      release_pos_z     REAL,
      spin_axis         REAL,
      pfx_x             REAL,
      pfx_z             REAL,
      plate_x           REAL,
      plate_z           REAL,
      vx0               REAL,
      vy0               REAL,
      vz0               REAL,
      ax                REAL,
      ay                REAL,
      az                REAL,
      zone              INTEGER,

      -- Outcome
      description       TEXT,
      type              TEXT,
      events            TEXT,
      bb_type           TEXT,
      hit_location      INTEGER,
      hc_x              REAL,
      hc_y              REAL,

      -- Batted ball metrics
      launch_speed      REAL,
      launch_angle      REAL,
      launch_speed_angle INTEGER,
      estimated_ba_using_speedangle  REAL,
      estimated_woba_using_speedangle REAL,
      woba_value        REAL,
      woba_denom        INTEGER,
      babip_value       REAL,
      iso_value         REAL,

      -- Hit distance / trajectory
      hit_distance_sc   REAL,
      if_fielding_alignment TEXT,
      of_fielding_alignment TEXT,

      -- Run expectancy / value
      delta_run_exp     REAL,
      delta_home_win_exp REAL,
      bat_score         INTEGER,
      fld_score         INTEGER,
      post_bat_score    INTEGER,
      post_fld_score    INTEGER,

      -- Game context
      game_year         INTEGER,
      game_type         TEXT,
      sv_id             TEXT UNIQUE
    )
  ")
}

create_indexes <- function(con) {
  indexes <- list(
    "CREATE INDEX IF NOT EXISTS idx_game_date  ON statcast(game_date)",
    "CREATE INDEX IF NOT EXISTS idx_game_pk    ON statcast(game_pk)",
    "CREATE INDEX IF NOT EXISTS idx_batter     ON statcast(batter)",
    "CREATE INDEX IF NOT EXISTS idx_pitcher    ON statcast(pitcher)",
    "CREATE INDEX IF NOT EXISTS idx_game_year  ON statcast(game_year)",
    "CREATE INDEX IF NOT EXISTS idx_pitch_type ON statcast(pitch_type)",
    "CREATE INDEX IF NOT EXISTS idx_events     ON statcast(events)"
  )
  for (sql in indexes) DBI::dbExecute(con, sql)
}

create_log_table <- function(con) {
  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS fetch_log (
      log_id      INTEGER PRIMARY KEY AUTOINCREMENT,
      date_pulled TEXT NOT NULL,
      rows_added  INTEGER,
      fetched_at  TEXT DEFAULT (datetime('now'))
    )
  ")
}
