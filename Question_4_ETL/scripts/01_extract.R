library(httr2)
library(rvest)
library(dplyr)
library(stringr)
library(readr)

project_dir <- file.path(path.expand("~"), "Question_4_ETL")
setwd(project_dir)

dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)

base_url <- "https://quotes.toscrape.com"
user_agent <- "AcademicETLDemo/1.0"

page_numbers <- 1:3

allowed <- robotstxt::paths_allowed(
  paths = paste0("/page/", page_numbers, "/"),
  domain = base_url,
  bot = user_agent
)

if (!isTRUE(all(allowed))) {
  stop("Scraping permission could not be confirmed. Inspect robots.txt.")
}

word_pattern <- "\\p{L}+(?:['’-]\\p{L}+)*"

page_records <- vector("list", length(page_numbers))

for (i in seq_along(page_numbers)) {
  
  page_number <- page_numbers[i]
  page_url <- paste0(base_url, "/page/", page_number, "/")
  cache_file <- sprintf("data/raw/page_%02d.html", page_number)
  
  if (!file.exists(cache_file)) {
    
    Sys.sleep(2)
    
    response <- request(page_url) |>
      req_user_agent(user_agent) |>
      req_timeout(60) |>
      req_perform()
    
    writeBin(resp_body_raw(response), cache_file)
  }
  
  page <- read_html(cache_file)
  cards <- html_elements(page, "div.quote")
  
  if (length(cards) == 0) {
    stop("No quotation records found at: ", page_url)
  }
  
  records <- lapply(seq_along(cards), function(j) {
    
    card <- cards[[j]]
    
    quote_node <- html_element(card, "span.text")
    author_node <- html_element(card, "small.author")
    tags_node <- html_element(card, "div.tags")
    
    quote_raw <- html_text(quote_node, trim = FALSE)
    author_raw <- html_text(author_node, trim = FALSE)
    tags_raw <- html_text(tags_node, trim = FALSE)
    
    data.frame(
      record_id = sprintf("p%02d_q%02d", page_number, j),
      source_url = page_url,
      page_number = as.integer(page_number),
      quote_raw = quote_raw,
      author_raw = author_raw,
      tags_raw = tags_raw,
      
      raw_html = as.character(card),
      
      word_count_raw = str_count(quote_raw, word_pattern),
      
      stringsAsFactors = FALSE
    )
  })
  
  page_records[[i]] <- bind_rows(records)
  
  cat("Page", page_number, ":", length(cards), "records\n")
}

raw_df <- bind_rows(page_records)

if (nrow(raw_df) < 20) {
  stop("Fewer than 20 records collected. Check the extraction.")
}

write_csv(raw_df, "data/raw/quotes_raw.csv", na = "")

saveRDS(raw_df, "data/raw/quotes_raw.rds")

is_missing_text <- function(x) {
  is.na(x) | str_trim(x) == ""
}

audit <- data.frame(
  field = c("quote_raw", "author_raw", "tags_raw"),
  missing_or_blank = c(
    sum(is_missing_text(raw_df$quote_raw)),
    sum(is_missing_text(raw_df$author_raw)),
    sum(is_missing_text(raw_df$tags_raw))
  )
)

write_csv(audit, "data/raw/missing_value_audit.csv")

cat("\nTotal records:", nrow(raw_df), "\n")
cat("Distinct quotation texts:",
    n_distinct(raw_df$quote_raw), "\n")

cat("\nMissing-value audit:\n")
print(audit)

cat("\nFirst six records:\n")
print(
  raw_df |>
    select(record_id, author_raw, word_count_raw) |>
    head()
)

cat("\nExample of raw text containing layout noise:\n")
dput(raw_df$tags_raw[1])

cat("\nSaved raw CSV:\n")
cat(normalizePath("data/raw/quotes_raw.csv"), "\n")

View(raw_df)