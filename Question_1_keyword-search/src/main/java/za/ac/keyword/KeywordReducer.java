package za.ac.keyword;

import java.io.IOException;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Reducer;

/** Receives every location grouped by document; preserves all occurrences. */
public class KeywordReducer extends Reducer<Text, Text, Text, Text> {
    @Override
    protected void reduce(Text document, Iterable<Text> locations, Context context)
            throws IOException, InterruptedException {
        for (Text location : locations) {
            context.write(document, location);
        }
    }
}
