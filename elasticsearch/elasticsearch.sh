#!/bin/bash

# 
# Loads Twitter data from a local file into ElasticSearch
#
# See function "usage" below for usage details or call with "-h"-
#
# Changes:
# 2015-01-17 (rja)
# - using env variable ELASTICSEARCH to point to ElasticSearch
# - added function and parameter to print status
# - added function to query by document, term and hashtag
# - renamed to elasticsearch.sh
# 2015-01-16 (rja)
# - moved JSON for index into separate file
# 2015-01-15 (rja)
# - refactored
# - added logging
# - added mapping of tweets' "id" field to the ElasticSearch "_id"
# - added command line parsing using getopts
# - initial version by Asmelash Teka Hadgu
# TODO: 
# - move ElasticSearch functions into separate module
#

if [ $ELASTICSEARCH ]; then
    HOST=$ELASTICSEARCH
else
    # default ElasticSearch host
    HOST="http://localhost:9200"
fi

# write log output into this file
LOGFILE=$(basename $0).log
# document type (relevant for the mapping created in create_index)
DOC_TYPE="tweet"
# where is the index definition?
INDEX_DEF=$(dirname $0)/index_config.json


########################################################################
# functions

function usage() {
    cat <<EOF
Usage: ${0##*/} [-h] [-d] [-c] [-s] [-q TERM] [-D DOC] [-l FILE] INDEX
Loads Twitter data from file FILE into ElasticSearch

    -h          display this help and exit
    -d          delete the index INDEX
    -c          create the index INDEX
    -s          print the status of index INDEX
    -q TERM     query the index INDEX for TERM
    -D DOC      query the index INDEX for document DOC
    -t HASHTAG  query the index INDEX for hashtag HASHTAG
    -l FILE     load the data from FILE into the index INDEX

The parameters can be combined, i.e., used together (order of
operations is then delete, create, load).
EOF
}


function delete_index {
    INDEX=$1
    curl -XDELETE  $HOST/$INDEX
}

#
# This function creates an index for Twitter with appropriate
# analyzers, proper date parsing and _id mapping.
#
function create_index {
    INDEX=$1
    curl -XPUT $HOST/$INDEX -d @$INDEX_DEF
    # see
    # http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/mapping-id-field.html
    # for the _id mapping
}

function print_status {
    INDEX=$1
    curl -XGET "$HOST/_cat/indices?v"
}

function query_index {
    INDEX=$1
    QUERY=$2
    curl -XGET "$HOST/$INDEX/_search?q=$QUERY&pretty=true&fields=text,entities.hashtags.text,created_at,user.screen_name,entities.urls.url"
}

function query_hashtag {
    INDEX=$1
    HASHTAG=$2
    curl -XGET "$HOST/$INDEX/_search?q=entities.hashtags.text:$HASHTAG&pretty=true&fields=text,entities.hashtags.text,created_at,user.screen_name,entities.urls.url"
}

function query_document {
    INDEX=$1
    DOC=$2
    curl -XGET "$HOST/$INDEX/$DOC_TYPE/$DOC?pretty=true"
}

# loads data to ElasticSearch using stream2es
function load_data {
    DATA_FILE=$1
    INDEX=$2
    DOC_TYPE=$3
    #
    # Instead of zgrep we used "gunzip --to-stdout" here
    # before. However, the stored stream contains lines like
    #
    # Stream closed.
    # Stream closed.
    # Waiting for 250 milliseconds
    # Establishing connection.
    # Connection established.
    # Receiving status stream.
    #
    # and this caused errors in the JSON parser. Hence, we only grep
    # lines that start with "{". Note that we did a `zgrep -v "^{"` on
    # a sample of 15 days and found no lines which would be
    # erroneously omitted by this approach.
    #
    zgrep "^{" $DATA_FILE | ./stream2es stdin --target $HOST/$INDEX/$DOC_TYPE
}


function log {
    TEXT=$1
    NOW=$(date +"%Y-%m-%d %H:%M:%S")
    echo "$NOW: $TEXT" >> $LOGFILE
}

# Create alias
# curl -XPOST '$HOST/_aliases' -d '
# {
#     "actions" : [
#         { "add" : { "index" : "24h_location", "alias" : "24hpolizei" } },
#         { "add" : { "index" : "24h_keywords", "alias" : "24hpolizei" } }
#     ]
# }'
# 


########################################################################
# parsing command line parameters
#
# cf. https://stackoverflow.com/questions/192249/

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

# initialize our own variables
INDEX=""
DATA_FILE=""
QUERY=""
DOC=""
HASHTAG=""
DELETE=0
CREATE=0
STATUS=0

while getopts "hdcsq:D:l:t:" opt; do
    case "$opt" in
	h)  usage
	    exit
	    ;;
	d)  DELETE=1
            ;;
	c)  CREATE=1
            ;;
	s)  STATUS=1
            ;;
	l)  DATA_FILE=$OPTARG
            ;;
	D)  DOC=$OPTARG
            ;;
	q)  QUERY=$OPTARG
            ;;
	t)  HASHTAG=$OPTARG
            ;;
	'?')
	    usage >&2
	    exit 1
	    ;;
    esac
done

shift $((OPTIND-1))

[ "$1" = "--" ] && shift

if [ $# -lt 1 ]; then
    echo "$0: index name is missing" >&2
    usage >&2
    exit 1
fi 

INDEX=$@

########################################################################
# do the work

if [ $DELETE -eq 1 ]; then
    echo "deleting index $INDEX"
    delete_index $INDEX
fi

if [ $CREATE -eq 1 ]; then
    echo "creating index $INDEX"
    create_index $INDEX $DOC_TYPE
fi

if [ $DATA_FILE ]; then
    echo "#--------------------------------------------------------------------------------" >> $LOGFILE
    log "loading data $DATA_FILE into $INDEX"
    load_data $DATA_FILE $INDEX $DOC_TYPE >> $LOGFILE
    log "finished loading data from $DATA_FILE" 
    # print statistics into logfile
    print_status $INDEX >> $LOGFILE
    echo "#--------------------------------------------------------------------------------" >> $LOGFILE
fi

if [ $QUERY ]; then
    echo "querying index $INDEX for $QUERY"
    query_index $INDEX $QUERY
fi

if [ $DOC ]; then
    echo "querying index $INDEX for doc $DOC"
    query_document $INDEX $DOC
fi

if [ $HASHTAG ]; then
    echo "querying index $INDEX for hashtag $HASHTAG"
    query_hashtag $INDEX $HASHTAG
fi

if [ $STATUS -eq 1 ]; then
    print_status $INDEX
fi
