## Example queries against the Statcast database
##
## Run AFTER build_statcast_db.R has populated statcast.db

suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
  library(dplyr)
})

script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(script_dir, "R", "schema.R"))
source(file.path(script_dir, "R", "fetch.R"))
source(file.path(script_dir, "R", "db.R"))
source(file.path(script_dir, "R", "query.R"))

`%||%` <- function(a, b) if (!is.null(a)) a else b

# ---------------------------------------------------------------------------
# Open connection
# ---------------------------------------------------------------------------
con <- open_db("statcast.db")

# ---------------------------------------------------------------------------
# 1. Database summary
# ---------------------------------------------------------------------------
cat("\n--- Database Summary ---\n")
print(db_summary(con))

# ---------------------------------------------------------------------------
# 2. Hard-hit rate leaders, 2024
# ---------------------------------------------------------------------------
cat("\n--- Hard-Hit Rate Leaders (2024, min 50 BIP) ---\n")
print(hard_hit_leaders(con, year = 2024, min_bip = 50, top_n = 10))

# ---------------------------------------------------------------------------
# 3. Whiff rate by pitch type, 2024
# ---------------------------------------------------------------------------
cat("\n--- Whiff Rate by Pitch Type (2024) ---\n")
print(whiff_by_pitch(con, year = 2024))

# ---------------------------------------------------------------------------
# 4. Shohei Ohtani pitch mix, 2023  (MLBAM ID: 660271)
# ---------------------------------------------------------------------------
cat("\n--- Ohtani Pitch Mix (2023, as pitcher) ---\n")
print(pitch_mix(con, pitcher_id = 660271, year = 2023))

# ---------------------------------------------------------------------------
# 5. Custom SQL – average exit velocity by ball-in-play type, 2024
# ---------------------------------------------------------------------------
cat("\n--- Avg Exit Velo & LA by BIP Type (2024) ---\n")
result <- DBI::dbGetQuery(
  con,
  "SELECT bb_type,
          COUNT(*)                         AS n,
          ROUND(AVG(launch_speed), 1)      AS avg_ev,
          ROUND(AVG(launch_angle), 1)      AS avg_la,
          ROUND(AVG(hit_distance_sc), 0)   AS avg_dist,
          ROUND(AVG(woba_value), 3)        AS avg_woba
   FROM   statcast
   WHERE  game_year = 2024
     AND  bb_type IS NOT NULL
   GROUP  BY bb_type
   ORDER  BY avg_ev DESC"
)
print(result)

# ---------------------------------------------------------------------------
# 6. dplyr interface – zone analysis
# ---------------------------------------------------------------------------
cat("\n--- Strike Zone Hit Rate by Zone (2024) ---\n")
zone_tbl <- dplyr::tbl(con, "statcast") |>
  dplyr::filter(game_year == 2024, !is.na(zone)) |>
  dplyr::group_by(zone) |>
  dplyr::summarise(
    pitches    = dplyr::n(),
    called_k   = sum(as.integer(description == "called_strike"), na.rm = TRUE),
    swing_miss = sum(as.integer(description == "swinging_strike"), na.rm = TRUE)
  ) |>
  dplyr::arrange(zone) |>
  dplyr::collect()
print(zone_tbl)

close_db(con)
