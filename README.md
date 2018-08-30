# Historical Volatility

This script calculates and analyses the following historical volatility estimators:
* the traditional `Close-to-Close` estimator (and a variant of it that uses demeaned returns);
* the `Parkinson` estimator (1980);
* the `Garman-Klass` estimator (1980) and a variant proposed by Yang & Zhang (2000);
* the `Rogers-Satchell` estimator (1991);
* the `Hodges-Tompkins` estimator (2002);
* the `Yang-Zhang` estimator (2000);
* the `Meilijson` estimator (2009).

## Requirements

The minimum Matlab version required is `R2014a`. In addition, the following products and toolboxes must be installed in order to properly execute the script:
* Statistics and Machine Learning Toolbox
* System Identification Toolbox

## Usage

1. Edit the `run.m` script following your needs.
1. Execute the `run.m` script.

## Dataset

The script fetches historical time series from `Yahoo! Finance`. It shound't be too difficult to replace it with an alternative data source.

## Screenshots

![Probabilistic Measures](https://i.imgur.com/1Q1SQd2.png)

![Network Measures](https://i.imgur.com/NuSHgBO.png)

![Network Graph](https://i.imgur.com/fpEVHPf.png)
