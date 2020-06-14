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

Datasets can be fetched from `Yahoo! Finance` using the function `fetch_data`, or parsed from `Excel` sheets using the function `parse_dataset`. The example script provides a good overview of both approaches.

Every dataset passed as input argument to `analyze_volatility`, `compare_estimators` and `estimate_volatility` functions must be structured as a table of historical time series having the following columns:
 - Date (numeric observation dates)
 - Open (opening prices)
 - High (highest prices)
 - Low (lowest prices)
 - Close (closing prices)
 - Return (log returns)

## Screenshots

![Volatility Cones](https://i.imgur.com/YCLS43M.png)

![Estimators Comparison](https://i.imgur.com/XRDiosz.png)

![Estimators Correlation](https://i.imgur.com/HtoBxXP.png)
