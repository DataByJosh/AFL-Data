library(dplyr)
library(data.table)
library(furrr)
library(purrr)

load_chains <- function(seasons = year(Sys.Date()),weeks = 1:30, file_type = "csv") {
  
  urls <- paste0("https://github.com/DataByJosh/AFL-Data/raw/main/AFLM_Match_Chains/csvs/match_chains_",
                 seasons,"_",ifelse(weeks < 10,paste0(0,weeks),weeks),".", file_type)
  
  out <- future_map(urls,possibly(data.table::fread,otherwise = data.table()))
  out <- data.table::rbindlist(out , use.names = TRUE)
  class(out) <- c("tbl_df","tbl","data.table","data.frame")
  out
}
