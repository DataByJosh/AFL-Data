require(httr)
require(jsonlite)
require(dplyr)
require(lubridate)

### USER FUNCTION

get_match_chains <- function(season = year(Sys.Date()), round = NA) {

  if(season < 2021) {
    stop("Match chain data is not available for seasons prior to 2021.")
  }

  if (is.na(round)) {
    cat("No round value supplied.\nFunction will scrape all rounds in the season.\nThis may take some time.\n")
    games <- get_season_games(season)
  }
  else
    games <- get_round_games(season,round)

  if(length(games) == 0) {
    stop("No data available for the season or round selected.")
  }

  cat("\nScraping match chains...\n\n")
  chains <- get_many_game_chains(games)
  players <- get_players()
  chains <- inner_join(chains, games, by = "matchId")
  chains <- left_join(chains, players, by = "playerId")
  chains <- chains %>% select(season,roundNumber,homeTeam.teamName:date,venue.name,venueWidth:homeTeamDirectionQtr1,displayOrder,chain_number,initialState,finalState,period,periodSeconds,playerName.givenName:team.teamName,description,disposal:y)

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
    add_headers("x-media-mis-token" = token))
  
  content <- response %>%
    content(as = "text", encoding = "UTF-8") %>%
    fromJSON(flatten = TRUE)
  
  return(content)
}

### MATCH DATA FUNCTIONS
get_round_games <- function(season,round) {

  round <- ifelse(round < 10, paste0("0",round), round)
  url <- paste0("https://api.afl.com.au/cfs/afl/fixturesAndResults/season/CD_S",season,"014/round/CD_R",season,"014",round)
  games <- access_api(url)
  games <- games[[5]]

  if (length(games) > 0) {
    games <- games %>% filter(status == "CONCLUDED")
    if (nrow(games) > 0) {
      games <- games %>% select(matchId,utcStartTime,roundNumber,venue.name,homeTeam.teamName,awayTeam.teamName,homeTeamScore.totalScore,awayTeamScore.totalScore)
      games$date <- substr(games$utcStartTime, 1, 10)
      games$date <- as.Date(games$utcStartTime)
      games$season <- year(games$utcStartTime)

      return(games)
    }
  }
}

get_season_games <- function(season) {

  games <- get_round_games(season,1)

  for (i in 2:30) {
    new <- get_round_games(season,i)
    games <- bind_rows(games, new)
  }

  return(games)
}

### PLAYER DATA FUNCTIONS
get_players <- function() {

  url <- paste0("https://api.afl.com.au/cfs/afl/players")
  players <- access_api(url)
  players <- players[[5]]
  players <- players %>% select(playerId,playerName.givenName,playerName.surname,team.teamName)

  return(players)
}

### CHAIN DATA FUNCTIONS
get_many_game_chains <- function(games) {

  pb <- txtProgressBar(max = nrow(games), style = 3, width = 50, char = ">")
  pb %>% getTxtProgressBar()
  
  chains <- get_game_chains(games[[1,1]])
  
  pb %>% setTxtProgressBar(value = 1)
  pb %>% getTxtProgressBar()

  for (i in 2:nrow(games)) {
    new <- get_game_chains(games[[i,1]])
    chains <- bind_rows(chains,new)
    pb %>% setTxtProgressBar(value = i)
    pb %>% getTxtProgressBar()
  }

  return(chains)
}

get_game_chains <- function(match_id) {


  url <- paste0("https://api.afl.com.au/cfs/afl/matchChains/",match_id)
  chains_t1 <- access_api(url)
  chains_t2 <- chains_t1[[8]]

  chains <- get_single_chain(chains_t2,1)

  for (i in 2:nrow(chains_t2)) {
    new <- get_single_chain(chains_t2,i)
    chains <- bind_rows(chains,new)
  }

  chains$matchId <- chains_t1$matchId
  chains$venueWidth <- chains_t1$venueWidth
  chains$venueLength <- chains_t1$venueLength
  chains$homeTeamDirectionQtr1 <- chains_t1$homeTeamDirectionQtr1

  return(chains)
}

get_single_chain <- function(chains_t2,chain_number) {
  chains_t3 <- chains_t2[[chain_number,6]]

  if(length(chains_t3 > 0)) {
  chains_t3$finalState <- chains_t2$finalState[chain_number]
  chains_t3$initialState <- chains_t2$initialState[chain_number]
  chains_t3$period <- chains_t2$period[chain_number]
  chains_t3$chain_number <- chain_number

  return(chains_t3)
  }
}