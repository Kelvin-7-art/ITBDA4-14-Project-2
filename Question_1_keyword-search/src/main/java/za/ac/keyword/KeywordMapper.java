package za.ac.keyword;

import java.io.IOException;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.apache.hadoop.io.LongWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Mapper;
import org.apache.hadoop.mapreduce.lib.input.FileSplit;

public class KeywordMapper extends Mapper<LongWritable, Text, Text, Text> {
    private Pattern pattern;
    private final Text document = new Text();
    private final Text position = new Text();
    private long row;

    @Override
    protected void setup(Context context) throws IOException {
        String keyword = context.getConfiguration().get("search.keyword");
        if (keyword == null || keyword.trim().isEmpty()) {
            throw new IOException("A non-empty search.keyword is required");
        }
        // Literal, Unicode-aware case-insensitive whole-word matching.
        // Letters, marks, numbers and underscore are word characters.
        pattern = Pattern.compile("(?<![\\p{L}\\p{M}\\p{N}_])"
                + Pattern.quote(keyword) + "(?![\\p{L}\\p{M}\\p{N}_])",
                Pattern.CASE_INSENSITIVE | Pattern.UNICODE_CASE);
        FileSplit split = (FileSplit) context.getInputSplit();
        document.set(split.getPath().toString()); // Full path avoids duplicate basenames.
        row = 0;
        context.getCounter("Search", "Documents").increment(1);
    }

    @Override
    protected void map(LongWritable byteOffset, Text value, Context context)
            throws IOException, InterruptedException {
        row++; // Includes empty lines; byteOffset is NOT a line number.
        String line = value.toString();
        Matcher matcher = pattern.matcher(line);
        while (matcher.find()) {
            // 1-based Unicode code-point column, not UTF-8 bytes or word index.
            int column = line.codePointCount(0, matcher.start()) + 1;
            position.set(row + "\t" + column);
            context.write(document, position);
            context.getCounter("Search", "Matches").increment(1);
        }
    }
}
