library(dplyr)
library(stringr)
library(readr)
library(rvest)

project_dir <- file.path(path.expand("~"), "Question_4_ETL")
setwd(project_dir)

dir.create("data/clean", recursive = TRUE, showWarnings = FALSE)
dir.create("evidence", recursive = TRUE, showWarnings = FALSE)

raw_df <- readRDS("data/raw/quotes_raw.rds")

clean_text <- function(x) {
  x <- stringi::stri_trans_nfkc(x)
  x <- str_replace_all(x, "\u00A0", " ")
  x <- str_squish(x)
  x[x == ""] <- NA_character_
  x
}

extract_tags <- function(html) {
  if (is.na(html) || !nzchar(html)) {
    return(NA_character_)
  }
  
  tags <- read_html(html) |>
    html_elements("a.tag") |>
    html_text(trim = TRUE)
  
  tags <- clean_text(tags)
  tags <- str_to_lower(tags)
  tags <- sort(unique(tags[!is.na(tags)]))
  
  if (length(tags) == 0) {
    return(NA_character_)
  }
  
  paste(tags, collapse = "; ")
}

word_pattern <- "\\p{L}+(?:['’-]\\p{L}+)*"

clean_df <- raw_df |>
  transmute(
    record_id,
    source_url,
    page_number = as.integer(page_number),
    quote = clean_text(quote_raw),
    author = clean_text(author_raw),
    tags = vapply(raw_html, extract_tags, character(1))
  ) |>
  mutate(
    quote = str_remove(quote, '^[“"]'),
    quote = str_remove(quote, '[”"]$'),
    quote = clean_text(quote),
    
    tags_imputed = is.na(tags),
    tags = coalesce(tags, "Uncategorised"),
    
    author_imputed = is.na(author),
    author = coalesce(author, "Unknown"),
    
]    word_count = as.integer(str_count(quote, word_pattern))
  )

rejected <- clean_df |>
  filter(is.na(quote) | is.na(word_count) | word_count < 1)

usable <- clean_df |>
  filter(!is.na(quote), !is.na(word_count), word_count >= 1)

duplicate_count <- sum(duplicated(usable[c("quote", "author")]))

clean_df <- usable |>
  distinct(quote, author, .keep_all = TRUE)

stopifnot(
  nrow(clean_df) >= 20,
  !anyDuplicated(clean_df$record_id),
  !anyNA(clean_df),
  all(clean_df$word_count > 0)
)

cleaning_audit <- data.frame(
  measure = c(
    "Raw records",
    "Rejected records without usable quotation text",
    "Duplicate quotation-author pairs removed",
    "Retained records",
    "Missing tags replaced with Uncategorised",
    "Missing authors replaced with Unknown"
  ),
  value = c(
    nrow(raw_df),
    nrow(rejected),
    duplicate_count,
    nrow(clean_df),
    sum(clean_df$tags_imputed),
    sum(clean_df$author_imputed)
  )
)

write_csv(
  clean_df,
  "data/clean/quotes_clean.csv",
  na = ""
)

saveRDS(clean_df, "data/clean/quotes_clean.rds")

write_csv(
  cleaning_audit,
  "evidence/cleaning_audit.csv"
)

write_csv(
  rejected,
  "evidence/rejected_records.csv",
  na = ""
)

cat("\nCLEANING AUDIT\n")
print(cleaning_audit, row.names = FALSE)

cat("\nRECORDS WITH IMPUTED TAGS\n")
print(
  clean_df |>
    filter(tags_imputed) |>
    select(record_id, author, tags, tags_imputed)
)

cat("\nWORD COUNT SUMMARY\n")
print(summary(clean_df$word_count))

cat("\nFIRST SIX CLEANED RECORDS\n")
print(
  clean_df |>
    select(record_id, author, word_count, tags) |>
    head()
)

cat("\nClean CSV saved at:\n")
cat(normalizePath("data/clean/quotes_clean.csv"), "\n")

View(clean_df)