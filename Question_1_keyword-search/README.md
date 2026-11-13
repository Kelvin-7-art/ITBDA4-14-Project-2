# Hadoop keyword search — Question 1

Java project for the supplied seven news articles. Start with `ANSWER.md` for the explanation, diagram and complete source listing.

## Search contract

- Dynamic keyword: third application argument, quoted if it contains spaces.
- Case-insensitive, literal whole-word/whole-phrase matching. `africa` matches `Africa` and `AFRICA`, but not `African`, `panAfrica`, `africa2` or `_africa`.
- UTF-8 input. Rows and columns start at 1. Rows count physical lines including blank lines; editor word-wrap does not add rows. Columns count Unicode code points, including spaces; tabs count as one character, not their displayed width.
- Every occurrence is emitted as `document_path<TAB>row<TAB>column`. Documents without a match produce no output record. The full path distinguishes identically named documents in different directories.
- Hadoop groups by document, but locations within a document have no promised order. Sort for presentation if needed. No combiner is used.

## Build and run

Use a JDK (Java 11 recommended for a Hadoop 3.4.2 installation), Maven 3.8+ and Hadoop 3.4.2. On Windows, run Hadoop in WSL2/Linux. Install and configure those prerequisites first; do not run the Linux commands directly in PowerShell. Java source targets Java 8 bytecode. Dependencies require internet access on the first Maven build.

From the extracted `keyword-search` directory:

```bash
mvn clean package
hadoop jar target/keyword-search-1.0.0.jar \
  -Dmapreduce.framework.name=local -Dfs.defaultFS=file:/// \
  input output-africa africa
cat output-africa/part-r-*
python3 scripts/verify.py input output-africa africa
```

A precompiled `target/keyword-search-1.0.0.jar` is included. The Hadoop libraries are supplied by your Hadoop installation, not bundled into the jar.

Change the keyword without changing/recompiling the program:

```bash
hadoop jar target/keyword-search-1.0.0.jar \
  -Dmapreduce.framework.name=local -Dfs.defaultFS=file:/// \
  input output-sars SARS
```

The output directory must not already exist. Use a new name for each run; Hadoop deliberately refuses to overwrite existing output. Pass only extracted article text files as input, never the ZIP or the macOS metadata directory.

## HDFS / YARN cluster execution

With a working Hadoop cluster and its `core-site.xml`, `hdfs-site.xml`, `mapred-site.xml`, and `yarn-site.xml` available to the Hadoop command:

```bash
hdfs dfs -mkdir -p /user/$USER/keyword-input
hdfs dfs -put input/*.txt /user/$USER/keyword-input/
hadoop jar target/keyword-search-1.0.0.jar \
  -Dmapreduce.framework.name=yarn -Dsearch.reducers=2 \
  /user/$USER/keyword-input /user/$USER/keyword-output-africa africa
hdfs dfs -cat /user/$USER/keyword-output-africa/part-r-*
```

Generic `-D` options precede the three application arguments. Cluster mode uses the cluster's configured default filesystem; do not set `fs.defaultFS=file:///` for this command. A cluster run is provided as instructions, not claimed as executed evidence.

## Demonstration evidence

`evidence/hadoop-africa.log` and `evidence/run-africa/` are actual Hadoop LocalJobRunner output, not a Python simulation. Seven maps processed seven articles; 16 matches were emitted. `evidence/verification.txt` compares every result to an independent Python oracle. `evidence/results-africa.tsv` is the same result sorted and shortened to basenames for readability; raw output retains full paths.

Additional actual runs use `SARS` to prove dynamic input and `AFRICA` against `tests/input` to check case, blank lines, repeated hits, CRLF, Unicode columns, word boundaries and a document with no matches. The oracle is for these fixtures and corpus; it is not a general proof of all Unicode case-folding equivalences between Java and Python.

## Design limit

`DocumentInputFormat` disables splitting within a document, while still streaming one line at a time. This keeps exact line numbers and parallelizes across documents. A single enormous file cannot be processed by multiple mappers in this implementation. At that scale, preprocess records with document IDs and global line numbers, or use a two-pass split-prefix line-count scheme. The reducer streams locations rather than holding an entire document's results in memory.

## Files

- `src/main/java/za/ac/keyword/KeywordMapper.java`: Q1.2.
- `src/main/java/za/ac/keyword/KeywordReducer.java`: Q1.3.
- `src/main/java/za/ac/keyword/KeywordSearch.java`: Q1.4 and executable driver.
- `src/main/java/za/ac/keyword/DocumentInputFormat.java`: exact row-number support.
- `pom.xml`: reproducible Maven build configuration.
- `input/`: original seven article files, unchanged.
- `ANSWER.md`: Q1.1–Q1.4 written answer with code.
- `evidence/`: execution logs, raw results, verification and environment details.
