package za.ac.keyword;

import org.apache.hadoop.conf.Configured;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;
import org.apache.hadoop.mapreduce.lib.output.TextOutputFormat;
import org.apache.hadoop.util.Tool;
import org.apache.hadoop.util.ToolRunner;

public class KeywordSearch extends Configured implements Tool {
    @Override
    public int run(String[] args) throws Exception {
        if (args.length != 3 || args[2].trim().isEmpty()
                || args[2].contains("\n") || args[2].contains("\r")) {
            System.err.println("Usage: KeywordSearch [generic -D options] <input> <new-output> <keyword>");
            return 2;
        }
        getConf().set("search.keyword", args[2]); // Runtime argument, never hardcoded.
        getConf().setBoolean("mapreduce.input.fileinputformat.input.dir.recursive", true);
        // Do not silently skip a long article line.
        getConf().setInt("mapreduce.input.linerecordreader.line.maxlength", Integer.MAX_VALUE);
        Job job = Job.getInstance(getConf(), "Case-insensitive keyword locations");
        job.setJarByClass(KeywordSearch.class);
        job.setInputFormatClass(DocumentInputFormat.class);
        job.setMapperClass(KeywordMapper.class);
        job.setReducerClass(KeywordReducer.class);
        job.setMapOutputKeyClass(Text.class);
        job.setMapOutputValueClass(Text.class);
        job.setOutputKeyClass(Text.class);
        job.setOutputValueClass(Text.class);
        job.setOutputFormatClass(TextOutputFormat.class);
        int reducers = getConf().getInt("search.reducers", 1);
        if (reducers < 1) {
            System.err.println("search.reducers must be at least 1");
            return 2;
        }
        job.setNumReduceTasks(reducers);
        FileInputFormat.addInputPath(job, new Path(args[0]));
        FileOutputFormat.setOutputPath(job, new Path(args[1]));
        // No combiner: no count or aggregation is being computed.
        return job.waitForCompletion(true) ? 0 : 1;
    }
    public static void main(String[] args) throws Exception {
        System.exit(ToolRunner.run(new KeywordSearch(), args));
    }
}
