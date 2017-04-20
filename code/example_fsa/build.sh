#!/usr/bin/env bash

# This script build the image for a simple FSA

sentence="star of thor"

this=$(dirname $0)
tmp="$this/tmp"
report="$this/../../report/figures"

mkdir -p $tmp
mkdir -p $report

current=$(pwd)
cd $tmp

# lexicon
echo $sentence | ngramsymbols - > sentence.lex

# FSA
echo $sentence | farcompilestrings --generate_keys=1 --symbols=sentence.lex --unknown_symbol='<unk>' - > sentence.far
farextract --filename_suffix='.fsa' sentence.far

# print
cat 1.fsa | fstdraw --isymbols=sentence.lex --osymbols=sentence.lex --portrait | \
    dot -Teps > ../$report/fsa.eps

cd $current
