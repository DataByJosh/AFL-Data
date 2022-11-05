# AFL Data: Public Tips

This folder contains csv files of data scraped from public tipping competitions in past and current AFLW and AFLM seasons. Each file represents a single season and will be updated on a round-by-round basis as the season progresses. The competition and season are identified in the file name.

Currently available:  
AFLM 2022  
AFLW 2022B

The dataset in each file contains 11 variables. These variables are defined as follows:

**game_id** - My personally created unique idenitfier for each game.  
**competition** - An acronym signifying which competition the match took place in.  
**season** - The season in which the match took place.  
**round** - The round in which the match took place.  
**home_team** - A two-letter code identifying the home team in the match.  
**away_team** - A two-letter code identifying the away team in the match.  
**provider** - The organisation which ran the tipping competition from which data is drawn.  
**home_pct** - The percentage of participants who tipped the home team.  
**away_pct** - The percentage of participants who tipped the away team.  
**home_count** - The total count of participants who tipped the home team.  
**away_count** - The total count of participants who tipped the away team.

The dataset in each file should contain one and only one observation for each combination of game_id and provider.

None of the competitions data has been scraped from currently include finals matches, so data is available for home and away matches only.

Because the sum total of home_count and away_count fluctuates from match to match, it is assumed that this data only captures tips actually entered by participants, and therefore any incidences of missed tips being automatically assigned the away team are not counted.
