# Question 3: 

packages <- c('httr2','rvest','xml2','robotstxt','stringi','stopwords','igraph','ggplot2')
missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly=TRUE)]
if(length(missing)) install.packages(missing, repos='https://cloud.r-project.org')
library(ggplot2)
out <- 'question3_outputs'
dir.create(out, showWarnings=FALSE)
url <- 'https://en.wikipedia.org/wiki/Natural_language_processing'
ua <- Sys.getenv('WEBTEXT_USER_AGENT',
                 'WebTextCoursework/1.0 (single-page academic analysis)')
cache <- file.path(out, 'article.html')

# 3.1
if(!file.exists(cache)) {
  allowed <- robotstxt::paths_allowed(paths='/wiki/Natural_language_processing',
                                      domain='https://en.wikipedia.org', bot=ua)
  if(!isTRUE(all(allowed))) stop('Crawling is disallowed or could not be confirmed.')
  Sys.sleep(2)
  response <- httr2::request(url) |>
    httr2::req_user_agent(ua) |>
    httr2::req_timeout(60) |>
    httr2::req_perform()
  html <- httr2::resp_body_string(response)
  writeLines(html, cache, useBytes=TRUE)
  writeLines(format(Sys.time(), tz='UTC', usetz=TRUE),
             file.path(out, 'retrieved_utc.txt'))
}
page <- xml2::read_html(cache)
body <- rvest::html_element(page, '#mw-content-text .mw-parser-output')
if(inherits(body, 'xml_missing')) stop('Article selector changed: inspect the page.')
remove <- rvest::html_elements(body, paste(
  'script, style, table, .navbox, .infobox, .hatnote,',
  '.reflist, .references, .mw-editsection, sup.reference, .noprint'))
xml2::xml_remove(remove)
paragraphs <- rvest::html_elements(body, 'p') |> rvest::html_text2()
paragraphs <- trimws(paragraphs)
paragraphs <- paragraphs[nzchar(paragraphs)]
if(length(paragraphs)<3) stop('Too few paragraphs: inspect extraction before analysis.')
web_df <- data.frame(paragraph_id=seq_along(paragraphs),
                     source_url=url, content=paragraphs)
write.csv(web_df, file.path(out,'web_dataframe.csv'), row.names=FALSE)
saveRDS(web_df, file.path(out,'web_dataframe.rds'))

# 3.2 .
readable <- stringi::stri_trans_nfkc(web_df$content)
readable <- gsub('https?://[^[:space:]]+', ' ', readable)
readable <- gsub('[[:alnum:]._%+-]+@[[:alnum:].-]+\\.[[:alpha:]]+', ' ', readable)
readable <- gsub('\\[[0-9]+\\]', ' ', readable)
readable <- stringi::stri_replace_all_regex(readable, '\\s+', ' ')
readable <- trimws(readable)

readable <- readable[nzchar(readable) & !duplicated(readable)]
sentences <- unlist(stringi::stri_split_boundaries(readable, type='sentence'),
                    use.names=FALSE)
sentences <- trimws(sentences)
sentences <- sentences[nzchar(sentences)]
sw <- stopwords::stopwords('en', source='snowball')
tokenise <- function(s) {
  s <- stringi::stri_trans_tolower(s)
  s <- stringi::stri_replace_all_regex(s, "['’]s\\b", '')
  words <- stringi::stri_extract_all_regex(s, '\\p{L}+')[[1]]
  words <- words[!is.na(words)]
  words[nchar(words)>=3 & !words %in% sw]
}
tokens <- lapply(sentences, tokenise)

valid <- lengths(tokens)>0
sentence_df <- data.frame(sentence_id=which(valid), sentence=sentences[valid],
                          clean_content=vapply(tokens[valid], paste, '', collapse=' '))
tokens <- tokens[valid]
N <- nrow(sentence_df)
if(N<5) stop('At least five usable sentences are required.')
if(N>2000) stop('Proof of concept limited to 2000 sentences for matrix memory.')
write.csv(sentence_df, file.path(out,'preprocessed_sentences.csv'), row.names=FALSE)

# 3.3 Method A: 
vocab <- sort(unique(unlist(tokens)))
counts <- matrix(0, nrow=N, ncol=length(vocab), dimnames=list(NULL,vocab))
for(i in seq_len(N)) {
  frequency <- table(tokens[[i]])
  counts[i, match(names(frequency),vocab)] <- as.numeric(frequency)
}
tf <- counts / rowSums(counts)
idf <- log((N+1)/(colSums(counts>0)+1))+1
tfidf <- sweep(tf, 2, idf, '*')
tfidf_score <- rowSums(tfidf)

# Method B: 
norms <- sqrt(rowSums(tfidf^2))
unit_vectors <- tfidf / norms
similarity <- tcrossprod(unit_vectors)
diag(similarity) <- 0
similarity[similarity < 1e-12] <- 0
network <- igraph::graph_from_adjacency_matrix(
  similarity, mode='undirected', weighted=TRUE, diag=FALSE)
textrank_score <- igraph::page_rank(network, directed=FALSE,
                                  damping=.85, weights=igraph::E(network)$weight)$vector
word_count <- stringi::stri_count_words(sentence_df$sentence)
content_word_count <- lengths(tokens)

eligible <- which(
  word_count >= 8 &
    content_word_count >= 4
)

if (length(eligible) < 5) {
  stop("Fewer than five eligible sentences. Inspect the extracted text.")
}

n_summary <- 5L

a <- eligible[
  order(
    -tfidf_score[eligible],
    sentence_df$sentence_id[eligible]
  )
][seq_len(n_summary)]

b <- eligible[
  order(
    -textrank_score[eligible],
    sentence_df$sentence_id[eligible]
  )
][seq_len(n_summary)]
summary_a <- sentence_df$sentence[sort(a)]
summary_b <- sentence_df$sentence[sort(b)]
writeLines(summary_a,file.path(out,'summary_tfidf.txt'))
writeLines(summary_b,file.path(out,'summary_textrank.txt'))
sentence_df$tfidf_score <- tfidf_score
sentence_df$textrank_score <- textrank_score
sentence_df$selected_tfidf <- seq_len(N) %in% a
sentence_df$selected_textrank <- seq_len(N) %in% b
write.csv(sentence_df,file.path(out,'sentence_scores.csv'),row.names=FALSE)


frequency <- sort(colSums(counts),decreasing=TRUE)
top <- head(frequency,15)
term_df <- data.frame(word=names(top),frequency=as.numeric(top))
p1 <- ggplot(term_df,aes(x=reorder(word,frequency),y=frequency)) +
  geom_col(fill='#2563EB') + geom_text(aes(label=frequency),hjust=-.2) +
  coord_flip() + scale_y_continuous(expand=expansion(mult=c(0,.15))) +
  labs(title='Most frequent words in the NLP article',
       subtitle='Prose paragraphs after tokenisation and stop-word removal',
       x='Word',y='Occurrences',caption=paste('Source:',url)) + theme_minimal(base_size=11)
ggsave(file.path(out,'01_word_frequency.png'),p1,width=10,height=6,dpi=300)


score_df <- rbind(
 data.frame(sentence_id=sentence_df$sentence_id,
            score=tfidf_score/max(tfidf_score),method='TF-IDF'),
 data.frame(sentence_id=sentence_df$sentence_id,
            score=textrank_score/max(textrank_score),method='TextRank'))
score_df$selected <- c(seq_len(N)%in%a,seq_len(N)%in%b)
p2 <- ggplot(score_df,aes(sentence_id,score)) +
 geom_line(colour='grey65') + geom_point(aes(colour=selected),size=1.8) +
 facet_wrap(~method,ncol=1) +
 scale_colour_manual(values=c('FALSE'='grey55','TRUE'='#D97706'),
                     labels=c('Not selected','Selected')) +
 labs(title='Sentence importance under two summarisation methods',
      subtitle='Scores divided by each method maximum; five sentences selected per method',
      x='Sentence position in extracted prose',y='Relative score (0 to 1)',
      colour='Summary inclusion',caption=paste('Source:',url)) +
 theme_minimal(base_size=11)
ggsave(file.path(out,'02_sentence_scores.png'),p2,width=10,height=7,dpi=300)
print(p1);print(p2)


overlap <- length(intersect(a,b))
jaccard <- overlap/length(union(a,b))
findings <- c(
 sprintf('Extracted paragraphs: %d; retained unique paragraphs: %d.',nrow(web_df),length(readable)),
 sprintf('Usable sentences: %d; analytical tokens: %d; vocabulary: %d.',N,sum(counts),length(vocab)),
 paste('Most frequent words:',paste(names(top)[1:min(5,length(top))],collapse=', ')),
 sprintf('Each summary contains %d sentences (%.1f%% of usable sentences).',n_summary,100*n_summary/N),
 sprintf('Shared selected sentences: %d; sentence-set Jaccard overlap: %.3f.',overlap,jaccard),
 'TF-IDF favours sentences containing terms distinctive across sentences.',
 'TextRank favours sentences connected to other sentences by shared weighted terms.',
 'Word frequency indicates repetition, not necessarily importance or factual correctness.',
 'Relative score peaks explain selection within each method, not accuracy between methods.',
 'Overlap measures agreement only. No reference summary was used to estimate accuracy.',
 'Read both summaries and assess coverage, coherence, redundancy and preserved meaning.',
 'Prose-only extraction excludes lists, images and tables and may omit useful information.',
 'Stemming was not used: retaining word forms keeps terms interpretable; variants may remain separate.'
)
writeLines(findings,file.path(out,'findings.txt'))
writeLines(c('Source: Wikipedia contributors, Natural language processing.',url,
 'License: Creative Commons Attribution-ShareAlike 4.0 International.',
 'https://creativecommons.org/licenses/by-sa/4.0/',
 'Changes: prose extracted, cleaned, tokenised and selected into extractive summaries.',
 'The reused and adapted article text is shared under CC BY-SA 4.0.',
 'No images from Wikipedia were downloaded.',
 'Retrieval timestamp is in retrieved_utc.txt. Original HTML is cached locally.'),
 file.path(out,'ATTRIBUTION.txt'))
cat('\nTF-IDF SUMMARY\n',paste(summary_a,collapse='\n\n'),
    '\n\nTEXTRANK SUMMARY\n',paste(summary_b,collapse='\n\n'),'\n\n')
cat(paste(findings,collapse='\n'),'\n')
cat('Results saved in:',normalizePath(out),'\n')
