# Concept Sequence Tagging for a Movie Domain
1st project of Language Understanding Systems, Fall Semester 2017, University of Trento.

The project consist in building a model for concept sequence tagging for a Movie Domain.
All the details can be found in the [task](task.pdf) file.
All results are discussed in the [report](report.pdf) file.

## Repository Structure
The repository is organized in 2 main folders: `report` and `code`.
The `report` folder contains the LaTeX report source files, the `code` folder contains the Bash files script used to create, train and test the model, plus some utilities used to parse the results and compute statistics.

### Model
The `code/model` folder contains the 2 models, the basic one `model/v1.sh` and the improved one `model/v2.sh`.
Each model accepts some parameters from the command line, like the feature to use for the training, the n-gram order and the smoothing method for the underlying language model.
Just run the script without paramters to get an help message with the right paramters.

Here we provide an example of invocation:
```bash
# run the first model, with the best parameters
./code/model/v1.sh word 5 witten_bell

# run the second model, with the best paramters
./code/model/v2.sh word word 4 kneser_ney
```

The script will automatically create the `code/computations` folder.
Inside this folder you will find a folder for each execution one of the model with different parameters.
To check the results of a specific computation, you can check the file `performances/performances.txt`, for instance:
```bash
# results of the model 1 with parameters: word 5 witten_bell
cat ./code/computations/v1-word-5-witten_bell/performances/performances.txt

# results of the model 1 with parameters: word word 4 kneser_ney
cat ./code/computations/v2-word-word-5-witten_bell/performances/performances.txt
```

Another interesting file generated is the `performances/comparison.txt`, which contains the test data (feature and concept) and the concept predicted by the model (last column).

The script have been tested on Bash and require the GNU sed tool.
Please contact me if there is any problem in the execution of the scripts.

## Data Analysis
The `code/analysis` folder contains the scripts used to analyze the provided data and the performances of the model and generate the tables included in the report.

## Licence
The model source code is licences under the MIT license. A copy of the license is available in the [LICENSE](LICENSE) file.
The LaTeX sources and the report are licenced under the [Creative Commons Attribution-ShareAlike 4.0 International](https://creativecommons.org/licenses/by-sa/4.0/) License.
