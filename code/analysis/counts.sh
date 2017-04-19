#!/usr/bin/env bash

# This script computes the some information about
# the corpora and saves them in LaTeX files.

function column_to_lines() {
	cat - | sed 's/^ *$/#/g' | tr '\n' ' ' | sed 's/ # /\n/g'
}

function get_number() {
    cat - | sed 's/^ *//' | tr -d '\n'
}

this=$(dirname $0)
data="$this/../data_raw"
report="$this/../../report/counts"

mkdir -p $report

for type in "train" "test"; do
    echo -n "$type: "

    # number of sentences
    cat $data/NLSPARQL.$type.data | column_to_lines | wc -l | get_number | \
        tee >(cat - > $report/$type.sentences)
    echo -n " sentences, "

    # number of tokens, without spaces
    cat $data/NLSPARQL.$type.data | sed '/^ *$/d' | wc -l | get_number | \
        tee >(cat - > $report/$type.tokens)
    echo " tokens"

done
