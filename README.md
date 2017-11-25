# Flight-Delay-Prediction-Data-Challenge
Data Challenge to predict flight cancellation based on several factors for top 3 domestic US airlines

## Executive Summary

### Approach

* Synthetic data genaration was performed from the original dataset in order to balance the highly imbalanced dataset (17 % rare class) using oversampling techniques with the help of SMOTE function

* Month variable was bucketed into three seasons based on the flight cancellation trend across the year in order to reduce model complexity

* Posdictive variables - Arrival and Departure delays were not used in the model to predict cancellations since these variables influenced the target variable in a non causal manner

* Several classification algorithms such as Logistic Regression, Random Forest and XGBoost were implemented to predict the flight cancellation and were also evaluated

### Results

* The Best performing model was selected based on following criteria:
     + Performance - prediction accuracy on test set and area under the ROC curve
     + Stability - cross validated prediction accuracy on training set
     + Interpretability of the model results

* XGBoost algorithm with the tuned hyperparameters provided the best performance with a prediction accuracy of 78.64% and area under curve 0.75

* Month was the most important feature with the highest information gain value of 38.5%. 'Unique Carrier' had an information gain of around 13%


### Recommendation

* Airline carrier 'DL' was found to be the most reliable airline due to the following reasons:
     + Carrier 'DL' has the least risk of cancellation among the three airlines based on the average cancellation probability computed from the model output for each observation
     + Carrier 'DL' has the least average arrival and departure delays from the given set of observations
