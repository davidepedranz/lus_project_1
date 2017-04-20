#!/usr/bin/env bash

#---------------------------------------------------------
# some useful functions
#---------------------------------------------------------

function count() {
	cat - | sed '/^[ \t]*$/d' | sort | uniq -c | sed 's/^ *//'
}

function column_to_lines() {
	cat - | sed 's/^ *$/#/g' | tr '\n' ' ' | sed 's/ # /\n/g'
}


#---------------------------------------------------------
# 0) prepare the environment
#---------------------------------------------------------

# check the input parameters, exit if wrong input
if [[ ! "$#" == 4 ]]; then 
    echo "Wrong number of parameters."
	echo ""
	echo "Usage: $0 feature feature_O order method"
	echo ""
	echo "Model 2: this model is an improvment over model 1, since"
	echo "it takes in account the feature to compute the language model."
	echo ""
	echo "Arguments:"
	echo "   feature     Feature to use to train the model ('word', 'pos' or 'radix')"
	echo "   feature_O   Feature to use to improve the language model for O tags"
	echo "   order       n-gram order to use for the concepts language model"
	echo "   method      Smoothing method to use for the concepts language model"
	echo "               ('witten_bell', 'absolute', 'katz', 'kneser_ney', 'presmoothed' or 'unsmoothed')"
	echo ""
    exit 1
fi

# decide what feature to use for the training
case $1 in
	"word")
		o=1
		;;
	"pos")
		o=2
		;;
	"radix")
		o=3
		;;
	*)
		echo "ERROR: feature not found. Please use 'word', 'pos' or 'radix'"
		exit 1
		;;
esac

# decide which column to use for the O concepts
case $2 in
	"word")
		f=5
		;;
	"pos")
		f=6
		;;
	"radix")
		f=7
		;;
	*)
		echo "ERROR: feature not found. Please use 'word', 'pos' or 'radix'"
		exit 1
		;;
esac

# read the meta-parameters for the model
ngram_order=$3				# ngram order for the concepts' model
ngram_method=$4				# method for the discouning for the concepts' model

# compute useful dictories where to put the various parts of the model
this=$(dirname $0)
base="$this/.."
data_raw="${base}/data_raw"
path="${base}/computations/v2-$1-$2-${ngram_order}-${ngram_method}"
data="${path}/data"
lexicon="${path}/lexicon"
lm="${path}/lm"
tagger="${path}/tagger"
normalizer="${path}/normalizer"
performances="${path}/performances"
test_folder="${performances}/test"

# create the needed folders
mkdir -p $path
mkdir -p $data
mkdir -p $lexicon
mkdir -p $tagger
mkdir -p $lm
mkdir -p $normalizer
mkdir -p $performances
mkdir -p $test_folder


#---------------------------------------------------------
# 1) prepare the training and test data
#---------------------------------------------------------
for type in "train" "test"; do

	# compute files with all the features
	paste $data_raw/NLSPARQL.$type.feats.txt $data_raw/NLSPARQL.$type.data | cut -f 1,2,3,5 > $data/$type.base

	# compute the additional "features"
	cut -f 1,4 $data/$type.base | sed 's/^\(.*\)\t\(O\)/\1\tO-\1/' | cut -f 2 > $data/$type.concept_word
	cut -f 2,4 $data/$type.base | sed 's/^\(.*\)\t\(O\)/\1\tO-\1/' | cut -f 2 > $data/$type.concept_pos
	cut -f 3,4 $data/$type.base | sed 's/^\(.*\)\t\(O\)/\1\tO-\1/' | cut -f 2 > $data/$type.concept_radix

	# put all togheter
	paste $data/$type.base $data/$type.concept_word $data/$type.concept_pos $data/$type.concept_radix > $data/$type.txt
done


#---------------------------------------------------------
# 2) create the lexicons
#---------------------------------------------------------
cut -f $o $data/train.txt | ngramsymbols - > $lexicon/feature.lex 			# input feature
cut -f $f $data/train.txt | ngramsymbols - > $lexicon/concept.lex 		# concept (modified to include the feature if O)
cut -f 4 $data/train.txt | ngramsymbols - > $lexicon/concept_iob.lex 		# concept cleaned, IOB notation


#---------------------------------------------------------
# 3) compute the tranducer feature2concept
#---------------------------------------------------------

# compute the counts
cut -f $o $data/train.txt | count | awk '{OFS="\t"; print $2,$1}' > $tagger/feature.counts
cut -f $f $data/train.txt | count | awk '{OFS="\t"; print $2,$1}' > $tagger/concept.counts
cut -f $o,$f $data/train.txt | count | awk '{OFS="\t"; print $2,$3,$1}' > $tagger/feature_concept.counts

# compute the cost (as negative log of the probability) of the feature given the concept
while read feature concept count
do
	# calculate probability
    concept_count=$(grep "^$concept\t" $tagger/concept.counts | cut -f 2)
    prob=$(echo "-l($count / $concept_count)" | bc -l)

    # print
    echo -e "$feature\t$concept\t$prob"
done < $tagger/feature_concept.counts > $tagger/feature_concept.costs

# compute the tranducer from the feature to the concept
cat $tagger/feature_concept.costs | sed 's/^/0\t0\t/' > $tagger/feature2concept.txt

# handle <unk>
n=$(wc -l $path/tagger/concept.counts | sed 's/^ *\([0-9]\+\).*$/\1/')
prob=$(echo "-l(1/$n)" | bc -l)
while read concept ___
do
   echo -e "0\t0\t<unk>\t$concept\t$prob"
done < $tagger/concept.counts >> $tagger/feature2concept.txt

# end state
echo "0" >> $tagger/feature2concept.txt

# compile it
fstcompile --isymbols=$lexicon/feature.lex --osymbols=$lexicon/concept.lex $tagger/feature2concept.txt | fstarcsort - > $tagger/feature2concept.fst


#---------------------------------------------------------
# 4) compute the concepts' language model
#---------------------------------------------------------

# concepts -> far
cut -f $f $data/train.txt | column_to_lines > $lm/concepts.phrases
farcompilestrings --symbols=$path/lexicon/concept.lex --unknown_symbol='<unk>' --keep_symbols=1 $lm/concepts.phrases > $lm/concepts.far

# n-grams model
ngramcount --order=$ngram_order $lm/concepts.far > $lm/concepts.counts
ngrammake --method=$ngram_method $lm/concepts.counts > $lm/concepts.lm

#---------------------------------------------------------
# 5) translate O-xxx back to O
# this part of the model is just a 1:1 map
# and does not change the assigned concepts
#---------------------------------------------------------

# compute the tranducer from concept_plus_feature to concept_iob
cut -f $f $data/train.txt | sort | uniq | sed '/^ *$/d' | \
while read concept
do
	# translate O-xxx to O
	# do not touch I,B tags
	iob=$(echo $concept | sed 's/^O-.*$/O/')
	echo -e "0\t0\t$concept\t$iob\t0"
done > $normalizer/concept2iob.txt
echo "0" >> $normalizer/concept2iob.txt

# compile it
fstcompile --isymbols=$lexicon/concept.lex --osymbols=$lexicon/concept_iob.lex $normalizer/concept2iob.txt | fstarcsort - > $normalizer/concept2iob.fst


#---------------------------------------------------------
# 6) compute final model
#---------------------------------------------------------
fstcompose $tagger/feature2concept.fst $lm/concepts.lm | fstcompose - $normalizer/concept2iob.fst > $path/model.fst


#---------------------------------------------------------
# 7) evalutate the model on the test data
#---------------------------------------------------------

# tranform the test data into sentences
cut -f $o $data/test.txt | column_to_lines > $performances/sentences.txt
farcompilestrings --symbols=$lexicon/feature.lex --unknown_symbol='<unk>' $performances/sentences.txt > $performances/sentences.far

# compile the sentences to fsa
current=$(pwd)
cd $test_folder
farextract --filename_suffix='.fsa' $current/$performances/sentences.far 
cd $current

# for each sentence, compute the concepts
for filename in $test_folder/*.fsa; do
    fstcompose $filename $path/model.fst | fstshortestpath | fstrmepsilon | fsttopsort | \
		fstprint --isymbols=$lexicon/feature.lex --osymbols=$lexicon/concept_iob.lex | \
		sed 's/^[0-9]*$//' | cut -f 3,4 > $filename.result
done

# compose all files togheter
cat $test_folder/*.result > $performances/result.txt

# compute the performances
paste $data/test.txt $performances/result.txt | cut -f 1,4,9 > $performances/comparison.txt
${base}/evaluation/conlleval.pl -d '\t' < $performances/comparison.txt > $performances/performances.txt
