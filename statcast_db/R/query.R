## Convenience query functions for the Statcast database

# Return every pitch thrown by a pitcher (by MLBAM ID)
pitcher_pitches <- function(con, pitcher_id, year = NULL) {
  sql <- "SELECT * FROM statcast WHERE pitcher = ?"
  params <- list(pitcher_id)
  if (!is.null(year)) {
    sql    <- paste(sql, "AND game_year = ?")
    params <- c(params, list(year))
  }
  DBI::dbGetQuery(con, sql, params = params)
}

# Return every plate appearance for a batter (by MLBAM ID)
batter_pa <- function(con, batter_id, year = NULL) {
  sql <- "SELECT * FROM statcast WHERE batter = ?"
  params <- list(batter_id)
  if (!is.null(year)) {
    sql    <- paste(sql, "AND game_year = ?")
    params <- c(params, list(year))
  }
  DBI::dbGetQuery(con, sql, params = params)
}

# Pitch-type mix for a pitcher in a season
pitch_mix <- function(con, pitcher_id, year) {
  DBI::dbGetQuery(
    con,
    "SELECT pitch_name,
            COUNT(*)                                  AS n,
            ROUND(AVG(release_speed),    1)           AS avg_velo,
            ROUND(AVG(release_spin_rate), 0)          AS avg_spin,
            ROUND(AVG(pfx_x), 2)                      AS avg_hbreak,
            ROUND(AVG(pfx_z), 2)                      AS avg_vbreak
     FROM   statcast
     WHERE  pitcher = ? AND game_year = ?
     GROUP  BY pitch_name
     ORDER  BY n DESC",
    params = list(pitcher_id, year)
  )
}

# Batted-ball summary for a batter in a season
batted_ball_summary <- function(con, batter_id, year) {
  DBI::dbGetQuery(
    con,
    "SELECT bb_type,
            COUNT(*)                              AS n,
            ROUND(AVG(launch_speed),  1)          AS avg_ev,
            ROUND(AVG(launch_angle),  1)          AS avg_la,
            ROUND(AVG(hit_distance_sc), 0)        AS avg_dist
     FROM   statcast
     WHERE  batter = ? AND game_year = ?
       AND  bb_type IS NOT NULL
     GROUP  BY bb_type
     ORDER  BY n DESC",
    params = list(batter_id, year)
  )
}

# Hard-hit rate (EV >= 95 mph) leader board for a season
hard_hit_leaders <- function(con, year, min_bip = 50, top_n = 20) {
  DBI::dbGetQuery(
    con,
    sprintf(
      "SELECT batter_name,
              COUNT(*)                                 AS bip,
              ROUND(AVG(launch_speed), 1)              AS avg_ev,
              ROUND(100.0 * SUM(CASE WHEN launch_speed >= 95 THEN 1 ELSE 0 END)
                    / COUNT(*), 1)                     AS hard_hit_pct,
              ROUND(AVG(launch_angle),  1)             AS avg_la,
              ROUND(AVG(estimated_woba_using_speedangle), 3) AS xwoba
       FROM   statcast
       WHERE  game_year = %d
         AND  launch_speed IS NOT NULL
       GROUP  BY batter
       HAVING bip >= %d
       ORDER  BY hard_hit_pct DESC
       LIMIT  %d",
      year, min_bip, top_n
    )
  )
}

# Whiff rate by pitch type, league-wide, for a season
whiff_by_pitch <- function(con, year) {
  DBI::dbGetQuery(
    con,
    sprintf(
      "SELECT pitch_name,
              COUNT(*)                                          AS swings,
              SUM(CASE WHEN description LIKE '%%swinging%%' THEN 1 ELSE 0 END)
                                                               AS whiffs,
              ROUND(100.0 *
                SUM(CASE WHEN description LIKE '%%swinging%%' THEN 1 ELSE 0 END)
                / COUNT(*), 1)                                 AS whiff_pct
       FROM   statcast
       WHERE  game_year = %d
         AND  description IN (
                'swinging_strike', 'swinging_strike_blocked',
                'foul', 'foul_tip', 'hit_into_play'
              )
         AND  pitch_name IS NOT NULL
       GROUP  BY pitch_name
       ORDER  BY whiff_pct DESC",
      year
    )
  )
}
