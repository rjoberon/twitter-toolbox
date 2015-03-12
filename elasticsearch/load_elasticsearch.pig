/*
  Loads tweets into ElasticSearch using Hadoop
  (cf. http://www.elastic.co/guide/en/elasticsearch/hadoop/current/pig.html)

  Parameters than can be overwritten:
  - LIBDIR - location of the JAR files (e.g., ElephantBird)
  - HOST - host name of one ElasticSearch node
  - INDEX - which index to use (including the document type)

  It is typically also necessary to adjust the memory configuration.

  Changes:
  2015-03-12 (rja)
  - initial version
*/

%DECLARE LIBDIR '/share/lib';
REGISTER '$LIBDIR/elephant-bird-core-4.6.jar';
REGISTER '$LIBDIR/elephant-bird-pig-4.6.jar';
REGISTER '$LIBDIR/elephant-bird-hadoop-compat-4.6.jar';
REGISTER '$LIBDIR/google-collections-1.0.jar';
REGISTER '$LIBDIR/json-simple-1.1.jar';
REGISTER '$LIBDIR/hadoop-lzo-0.4.17.jar';
-- TODO: move stable version to $LIBDIR
REGISTER '/home/jaeschke/es/elasticsearch-hadoop-2.1.0.Beta3/dist/elasticsearch-hadoop-pig-2.1.0.Beta3.jar';

-- settings according to
-- http://docs.hortonworks.com/HDPDocuments/HDP2/HDP-2.0.6.0/bk_installing_manually_book/content/rpm-chap1-11.html
-- with
--                   | old nodes | new nodes
-- containers        | 22        | 22 
-- RAM-per-container | 2GB       | 4GB
-- we take 2GB per RAM-per-container
SET yarn.nodemanager.resource.memory-mb	58000;    -- = containers * RAM-per-container
SET yarn.scheduler.minimum-allocation-mb 3000;    -- = RAM-per-container
SET yarn.scheduler.maximum-allocation-mb 58000;   -- = containers * RAM-per-container
SET mapreduce.map.memory.mb 3000;                 -- = RAM-per-container
SET mapreduce.reduce.memory.mb 6000;              -- = 2 * RAM-per-container
SET mapreduce.map.java.opts -Xmx2400m;            -- = 0.8 * RAM-per-container
SET mapreduce.reduce.java.opts -Xmx4800m;         -- = 0.8 * 2 * RAM-per-container
SET yarn.app.mapreduce.am.resource.mb 6000;       -- = 2 * RAM-per-container
SET yarn.app.mapreduce.am.command-opts -Xmx4800m; -- = 0.8 * 2 * RAM-per-container 
-- another source is http://hortonworks.com/blog/how-to-plan-and-configure-yarn-in-hdp-2-0/
-- mapreduce.(map|reduce).java.opts should be 80% of mapreduce.(map|reduce).memory.mb

-- avoid java.lang.OutOfMemoryError: Java heap space (execmode: -x local)
-- see http://stackoverflow.com/questions/16499432/pig-local-mode-group-or-join-java-lang-outofmemoryerror-java-heap-space
SET mapreduce.task.io.sort.mb 15;
-- otherwise (in cluster mode):
-- 0.25*mapred.child.java.opts < io.sort.mb < 0.5*mapred.child.java.opts
SET mapreduce.task.io.sort.mb 1000;

-- testing: setting parallelism to 100, see http://pig.apache.org/docs/r0.7.0/cookbook.html#Use+the+PARALLEL+Clause
SET default_parallel 256


/* 

  One problem we have with the Twitter data written by
  https://github.com/lintool/twitter-tools is that it contains status
  messages like

  Stream closed.
  Stream closed.
  Waiting for 250 milliseconds
  Establishing connection.
  Connection established.
  Receiving status stream.

  which confuse either ElasticSearch or the JSON parser of Pig. Hence,
  we need to filter these lines. We have two options for reading,
  filtering, and writing the data:

*/

-- configure ElasticSearch
%DECLARE HOST 'localhost:9200'
%DECLARE INDEX 'twitter/tweet'

-- this is our data
%DECLARE DATA '/data/twitter/streams/statuses.log.2015-01-*.gz'


/*

  1. We can read and parse the JSON and send it to ElasticSearch.
     Therefore, we need to use the JsonLoader from the ElephantBird
     library, since it is more robust towards broken JSON. We can then
     filter the relevant tweets, e.g., by checking for the key
     'created_at'.  */

records = LOAD '$DATA' USING com.twitter.elephantbird.pig.load.JsonLoader('-nestedLoad') AS (json:map[]);

-- filter the tweets (ignore "delete" statements and status messages)
tweets = FILTER records BY json#'created_at' IS NOT NULL;

STORE tweets INTO '$INDEX' USING org.elasticsearch.hadoop.pig.EsStorage
             ('es.http.timeout = 5m', 'es.index.auto.create = true', 'es.nodes = $HOST' );


/*

  2. We can read the JSON as a plain string and then send that string
     directly to ElasticSearch
     (cf. http://www.elastic.co/guide/en/elasticsearch/hadoop/current/pig.html#_writing_existing_json_to_elasticsearch_2)

http://www.elastic.co/guide/en/elasticsearch/hadoop/current/configuration.html

*/

/*
records = LOAD '$DATA' USING PigStorage() AS (json:chararray);

tweets = FILTER records BY SUBSTRING(json, 0, 13) == '{"created_at"';

STORE tweets INTO '$INDEX' USING org.elasticsearch.hadoop.pig.EsStorage
             ('es.http.timeout = 5m', 'es.index.auto.create = true', 'es.input.json = true', 'es.nodes = $HOST');
*/