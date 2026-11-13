QUESTION 3 — WEBTEXT PROOF OF CONCEPT IN R

RUN
1. Extract this ZIP into a folder on your Windows computer.
2. Open question3_webtext.R in RStudio.
3. Select Session > Set Working Directory > To Source File Location.
4. Click Source. The first run installs missing packages and requires internet.
5. Inspect question3_outputs. Subsequent runs reuse article.html.
If Wikipedia refuses the request, stop and report the response; do not bypass it.
The code is supplied for execution in R; it was not executed by the assistant.

SCOPE
One public webpage; prose paragraphs only, not an entire-site crawler.
The webpage URL is defined near the top of the script. Selectors and permission
checks are specific to this Wikipedia example, not arbitrary websites.
The scenario motivates an API, but the numbered questions request extraction,
preprocessing and analysis. This script implements that analysis core; it does
not claim to provide a deployed HTTP API.

REPORT STRUCTURE
3.1 (7 marks): identify the website and source URL, describe licensing and
robots checks, one-page cached access, main-content selection and the R data
frame. Show head(web_df), str(web_df), and actual paragraph count.
3.2 (5 marks): explain Unicode normalisation, whitespace and citation cleanup,
URL/email removal, paragraph deduplication, sentence splitting, lowercasing,
word tokenisation and stop-word removal. Show original and cleaned sentences.
Explain that readable sentences remain intact for summaries and stemming is
not used. Do not claim that every possible boilerplate item is removed.
3.3 (18 marks): explain TF-IDF sentence scoring and TextRank. Include both
actual five-sentence summaries and both generated figures with captions.
Describe leading words, selected sentence positions, overlap, differences in
coverage, redundancy and readability. Include the R script in an appendix.

IMPORTANT INTERPRETATION
Both approaches are extractive summarisation techniques. One ranks sentences
by distinctive term weights; the other ranks a graph of sentence similarities.
These are distinct techniques, not extractive versus abstractive categories.
Word frequencies alone are not the two summaries. No abstract or conclusion
should claim a quality score: there is no human reference summary here.
Do not invent findings before running the code. findings.txt contains computed
counts and explanatory prompts; add a content-specific interpretation after
reading your actual summaries. Wikipedia changes, so retain retrieval time,
source HTML and software sessionInfo() as evidence.

COPYRIGHT AND ACCESS
Use the article under its stated CC BY-SA terms rather than claiming that
academic use automatically constitutes fair use. Keep ATTRIBUTION.txt with
reused text and summaries and indicate transformations. robots.txt is an access
instruction, not a copyright license. Robots rules are checked on a fresh
retrieval. Cached reanalysis makes no article request.

SOURCE LINKS
https://en.wikipedia.org/wiki/Natural_language_processing
https://en.wikipedia.org/robots.txt
https://foundation.wikimedia.org/wiki/ToU
https://creativecommons.org/licenses/by-sa/4.0/
