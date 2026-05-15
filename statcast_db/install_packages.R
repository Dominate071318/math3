## Install all required packages (run once before building the database)

pkgs <- c(
  "baseballr",   # Statcast / Baseball Savant scraping
  "DBI",         # Database interface
  "RSQLite",     # SQLite backend
  "dplyr",       # Data manipulation (optional but useful)
  "dbplyr"       # dplyr backend for DBI connections
)

missing <- pkgs[!pkgs %in% rownames(installed.packages())]
if (length(missing)) {
  install.packages(missing, repos = "https://cloud.r-project.org")
} else {
  message("All packages already installed.")
}
