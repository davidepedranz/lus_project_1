#!/usr/bin/env bash

# This script computes the frequencies of the concepts
# in the provided data set and generate a piece of a latex table

# this removes the O tag
function count() {
    cat - | cut -f 2 | sed '/^ *$/d' | sed 's/^[IB]-//' | sed '/^O$/d' | sort | uniq -c | awk '{OFS="\t"; print $2,$1}'
}

# the format is: concept, #train, #test
function format_latex() {
    cat - | sed 's/ / \& /g' | sed 's/$/ \\\\/' | sed 's/_/\\_/g'
}

# parse the output of wc -l
function get_number() {
    cat - | sed 's/^ *//' | tr -d '\n'
}

this=$(dirname $0)
data="$this/../data_raw"
table="$this/../../report/table"
counts="$this/../../report/counts"

mkdir -p $table
mkdir -p $counts

# count the concepts in both train and test file
# join the 2 counts on the concept column, replace missing attributes with 0
# save it in a LaTeX file in the report folder
join -a 1 -a 2 -e'0' -o '0,1.2,2.2' \
    <(cat $data/NLSPARQL.train.data | count) \
    <(cat $data/NLSPARQL.test.data | count) | \
    tee >(format_latex > $table/concepts.tex) | \
    tee >(cat - | wc -l | get_number > $counts/corpora.concepts)
