# twitter-toolbox

Scripts for handling Twitter data


# content

These scripts help you to manipulate and analyze Twitter data:

- [elasticsearch](elasticsearch) scripts for indexing Twitter data
  with ElasticSearch
    - [index_config.json](elasticsearch/index_config.json) the index
      configuration for ElasticSearch to properly map and analyze
      tweet data. Used by
      [load_elasticsearch.sh](elasticsearch/load_elasticsearch.sh).
    - [kibana-dashboard.json](elasticsearch/kibana-dashboard.json) is
      a Kibana dashboard adopted to the Twitter data as it is loaded
      by
      [load_elasticsearch.sh](elasticsearch/load_elasticsearch.sh). It
      shows a
      [map](http://www.elasticsearch.org/guide/en/kibana/current/_bettermap.html),
      the distribution of hashtags, a
      [histogram](http://www.elasticsearch.org/guide/en/kibana/current/_histogram.html),
      and some more
      [panels](http://www.elasticsearch.org/guide/en/kibana/current/panels.html). It
      can be easily loaded by Kibana and is also available
      [as a Gist](https://gist.github.com/anonymous/495e740a8d8d1ab20e4b).
   - [elasticsearch.sh](elasticsearch/elasticsearch.sh) allows you to
     create
     [a specially configured index](elasticsearch/index_config.json)
     for Twitter data in ElasticSearch. It uses special analyzers for
     stopword removal, correctly parses the `created_at` field and
     lets ElasticSearch use the tweet id as document id.

# data collection

Since the beginning of 2013 we are continuously storing the
[sample stream](https://dev.twitter.com/streaming/reference/get/statuses/sample)
from the Twitter API. This stream is collected by the three machines
to ensure that the downtime of one machine does not cause gaps in the
collection. To get the best coverage, merge the data from the three
machines and remove duplicate tweets (using the tweet's id).

# data overview

Tweets contain very rich data, including the extracted hashtags, the
URLs, information about the user, retweets, etc.

## distinct URLs per host name

A common question is, how many of the URLs in the data are
shortened. To get an idea, we here list the top 30 host names by the
number of distinct URLs we could find in our dataset as of 2014-07-24:

| host name          | distinct urls   |     % |
| ------------------ | --------------: | ----: |
| fb.me              | 27,606,698      |    13 |
| bit.ly             | 21,004,418      |    10 |
| instagram.com      | 17,690,181      |     8 |
| ask.fm             | 10,735,327      |     5 |
| dlvr.it            | 7,311,653       |     3 |
| tmblr.co           | 6,173,834       |     3 |
| youtu.be           | 5,892,781       |     3 |
| ow.ly              | 4,833,328       |     2 |
| www.youtube.com    | 4,325,968       |     2 |
| 4sq.com            | 3,735,065       |     2 |
| goo.gl             | 3,657,036       |     2 |
| tinyurl.com        | 3,068,229       |     1 |
| twitpic.com        | 2,374,142       |     1 |
| ift.tt             | 2,149,996       |     1 |
| path.com           | 2,042,124       |     1 |
| vine.co            | 1,992,344       |     1 |
| knz.tv             | 1,865,585       |     1 |
| instagr.am         | 1,715,359       |     1 |
| amzn.to            | 1,638,267       |     1 |
| wp.me              | 1,596,059       |     1 |
| moi.st             | 1,527,789       |     1 |
| twitter.com        | 1,377,596       |     1 |
| www.facebook.com   | 1,133,897       |     1 |
| tl.gd              | 1,042,895       |     0 |
| vk.cc              | 949,620         |     0 |
| is.gd              | 895,753         |     0 |
| j.mp               | 799,771         |     0 |
| qurani.tv          | 758,901         |     0 |
| m.tmi.me           | 704,305         |     0 |
| nico.ms            | 684,888         |     0 |
| ALL                | 218,387,896     |   100 |
| TOP 10             | 109,309,253     |    52 |


# ElasticSearch

Data can be loaded into ElasticSearch using the script
[elasticsearch.sh](elasticsearch/elasticsearch.sh). It uses the index
configuration from
[index_config.json](elasticsearch/index_config.json). Before using the
script, it is highly recommended that you adopt that configuration to
your requirements.

## index configuration

resources:

- http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/_multi_fields.html#_multi_fields
- https://stackoverflow.com/questions/23867657/elasticsearch-aggregate-on-url-hostname
- http://andrewwhitby.com/2014/11/23/domain-name-analyzer-with-elasticsearch/
- http://www.elasticsearch.org/blog/stop-stopping-stop-words-a-look-at-common-terms-query/
- https://stackoverflow.com/questions/19137063/elasticsearch-what-analyzer-should-be-used-for-searching-for-both-url-fragment-a

We here discuss some options you should or might want to change:

### settings

- `number_of_shards` - the default of 2 is fine for a local
  installation of ElasticSearch. When your need to distribute your
  index over a cluster (because it is too large for a single machine),
  then you should set this at least to the number of nodes. Be aware
  that you can't change this later. So if you want to equipped for a
  cluster extension, use more shards. It is no problem to have 50 or
  100 shards.
- `number_of_shards` - increasing this gives you redundancy
  and reliability.

### analysis

#### filter

- `mylist_stop` - some hand-craftet stopwords which frequently appear
  in tweets.
- `de_stop` a German stopword list
- `en_stop` an English stopword list

#### analyzer

Here we basically plug together normalization to lowercase and
stopword filtering into the `tweet_analyzer`.

### mappings.tweet

### properties

- `created_at` we correctly parse this field as a date
- `text` we enable the `tweet_analyzer` for the text of the tweets.

#### _id

We ensure that the tweet id is also used as the ElasticSearch document
id.

