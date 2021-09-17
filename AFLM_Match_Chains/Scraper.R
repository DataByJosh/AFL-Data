library(httr)
library(jsonlite)
library(dplyr)
library(lubridate)
library(purrr)
library(furrr)
library(progressr)

### future::plan("multisession") ### USE MULTISESSION FOR QUICKEST RESULTS
### USER FUNCTION

get_match_chains <- function(season = year(Sys.Date()), round = NA) {
  if (season < 2021) {
    stop("Match chain data is not available for seasons prior to 2021.")
  }

  if (is.na(round)) {
    cat("No round value supplied.\nFunction will scrape all rounds in the season.\nThis may take some time.\n")
    games <- get_season_games(season)
    games_vector <- games[, "matchId"]
  } else {
    games <- get_round_games(season, round)
    games_vector <- games[, "matchId"]
  }

  if (length(games) == 0) {
    stop("No data available for the season or round selected.")
  }

  cat("\nScraping match chains...\n\n")
  chains <- with_progress({
    get_many_game_chains(games_vector)
  })
  players <- get_players()
  chains <- inner_join(chains, games, by = "matchId")
  chains <- left_join(chains, players, by = "playerId")
  chains <- chains %>% select(
    matchId, season, roundNumber, utcStartTime, homeTeam.teamName:date, venue.name:venue.state,
    venueWidth:homeTeamDirectionQtr1, displayOrder, chain_number,
    initialState, finalState, period, periodSeconds,
    playerId, playerName.givenName, playerName.surname, teamId, team.teamName, description,
    disposal:y
  )

  cat("\n\nSuccess!\n\n")

  return(chains)
}

### API SCRAPING FUNCTIONS
get_token <- function() {
  response <- POST("https://api.afl.com.au/cfs/afl/WMCTok")
  token <- content(response)$token

  return(token)
}

access_api <- function(url) {
  token <- get_token()

  response <- GET(
    url = url,
    add_headers("x-media-mis-token" = token)
  )

  content <- response %>%
    content(as = "text", encoding = "UTF-8") %>%
    fromJSON(flatten = TRUE)

  return(content)
}

### MATCH DATA FUNCTIONS
get_round_games <- function(season, round) {
  round <- ifelse(round < 10, paste0("0", round), round)
  url <- paste0("https://api.afl.com.au/cfs/afl/fixturesAndResults/season/CD_S", season, "014/round/CD_R", season, "014", round)
  games <- access_api(url)
  games <- games[[5]]

  if (length(games) > 0) {
    games <- games %>% filter(status == "CONCLUDED")
    if (nrow(games) > 0) {
      games <- games %>% select(
        matchId, utcStartTime, roundNumber, venue.name, venue.location, venue.state,
        homeTeam.teamName, awayTeam.teamName,
        homeTeamScore.totalScore, awayTeamScore.totalScore
      )
      games$date <- substr(games$utcStartTime, 1, 10)
      games$date <- as.Date(games$utcStartTime)
      games$season <- year(games$utcStartTime)

      return(games)
    }
  }
}

get_season_games <- function(season) {
  games <- map_df(1:30, ~ get_round_games(season, .))

  return(games)
}

### PLAYER DATA FUNCTIONS
get_players <- function() {
  url <- paste0("https://api.afl.com.au/cfs/afl/players")
  players <- access_api(url)
  players <- players[[5]]
  players <- players %>% select(playerId, playerName.givenName, playerName.surname, team.teamName)

  return(players)
}

### CHAIN DATA FUNCTIONS
get_many_game_chains <- function(games_vector) {
  p <- progressor(steps = length(games_vector))

  chains <- future_map_dfr(games_vector,
    ~ {
      p()
      get_game_chains(.)
    },
    .progress = FALSE
  )

  return(chains)
}

get_game_chains <- function(match_id) {
  url <- paste0("https://api.afl.com.au/cfs/afl/matchChains/", match_id)
  chains_t1 <- access_api(url)
  chains_t2 <- chains_t1[[8]]

  if (!is.null(dim(chains_t2))) {
    if (nrow(chains_t2) > 0) {
      chains <- map_df(1:nrow(chains_t2), ~ get_single_chain(chains_t2, .))

      chains$matchId <- chains_t1$matchId
      chains$venueWidth <- chains_t1$venueWidth
      chains$venueLength <- chains_t1$venueLength
      chains$homeTeamDirectionQtr1 <- chains_t1$homeTeamDirectionQtr1

      return(chains)
    }
  }
}

get_single_chain <- function(chains_t2, chain_number) {
  if (length(chains_t2) > 5) {
    chains_t3 <- chains_t2[[chain_number, 6]]

    if (length(chains_t3 > 0)) {
      chains_t3$finalState <- chains_t2$finalState[chain_number]
      chains_t3$initialState <- chains_t2$initialState[chain_number]
      chains_t3$period <- chains_t2$period[chain_number]
      chains_t3$chain_number <- chain_number

      return(chains_t3)
    }
  }
}
