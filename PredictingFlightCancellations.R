#' ---
#' title: 'Flight Delay Prediction Data Challenge'
#' author: "Vinodh Mohan"
#' date: "October 6, 2017"
#' output: pdf_document
#' ---

#' ## Model Building

#' ### Reading the dataset

setwd("~/Data Challenge/DigitasLBi")

FlightData = read.csv(file = "Data_PredictingFlightDelays.csv",header = FALSE,
                      col.names = c('Canceled','Month','DepartureTime','UniqueCarrier',
                                    'ScheduledFlightTime','ArrivalDelay','DepartureDelay','Distance'))


#' ### Checking for missing values

missing_value = vector(length = length(FlightData))
names(missing_value) = colnames(FlightData)

for(i in 1:length(FlightData)){
  
  missing_value[i] = sum(is.na(FlightData[,i]))
  
}
print(missing_value)


library(plyr)


#' ### Encoding and bucketing 'Month' variable
#' 
#' * Month is a categorical variable and encoding it will create 12 factors which will act as 12 predictors and eventually lead to model complexity. Therefore, it is necessary to bucket the month values to reduce model complexity
#' 
#' * Let's take a look at the number of canceled flighs in each month

library(dplyr)

Canceled_by_month = FlightData %>% filter(Canceled==1) %>% select(Canceled,Month) %>% group_by(Month) %>% summarise(Flights_Canceled = sum(Canceled))
Canceled_by_month$Month = factor(Canceled_by_month$Month)

library(ggplot2)

ggplot(data = Canceled_by_month,aes(x = Month,y = Flights_Canceled)) + geom_bar(stat = "identity")  + ggtitle("Canceled Flights by Month")


#' * We can observe three different seasons / segments with respect to the number of flight cancellations -> Jan to Apr, May to Aug and Sep to Dec
#' 
#' * Therefore, Month variable can be bucketed into 3 categories and encoded such that it will act as 3 predictors while building the model


FlightData$Month = ifelse(FlightData$Month<=4,'Season1',ifelse(FlightData$Month<=8,'Season2','Season3'))

FlightData$Month =  factor(FlightData$Month,levels = c('Season1','Season2','Season3'),labels = c(1,2,3))


#' ### Encoding other categorical variables

FlightData$Canceled = factor(FlightData$Canceled) #Target Variable

FlightData$UniqueCarrier = factor(FlightData$UniqueCarrier,levels = c('AA','DL','UA'),labels = c(1,2,3)) #Carrier

 
#' ### Highly imbalanced dataset
#' 
#' * The dataset has 6000 rows containing only 1000 observations where flights got canceled
#' 
#' * This represents an imbalanced dataset with only 16.67% of observations as the rare class (Canceled = 1)


ggplot(data = as.data.frame(table(FlightData$Canceled)),aes(Var1,Freq)) + geom_bar(stat = "identity")  + ggtitle("Canceled") + xlab('Class') + ylab('Count')


#' ### Synthetic data generation using SMOTE function
#' 
#' * There are several methods to balance a highly imbalanced dataset such as oversampling and undersampling using bootstrapping techniques
#' 
#' * SMOTE is a popular method that generates artificial data (not just mere  replications) based on the feature space similarities from the rare class samples
#' 
#' * It combines the technique of bootstrapping and k-nearest neighbours to oversample the rare class and it can also undersample the frequent class (Canceled = 0) by randomly removing few rows


library(DMwR)
set.seed(123)
dataset = SMOTE(Canceled ~ .,FlightData,perc.over = 150,perc.under = 300)
summary(dataset$Canceled)

#' * Now we have a balanced dataset of 5000 rows containg 2000 obsevrations of class '1' and 3000 observatons of '0'


#' ### Posdictive variables - Arrival Delay and Departure Delay
#' 
#' * Both the variables, Arrival Delay and Departure Delay are posdictive variables since they correlate with the target variable 'Canceled' in a noncausal manner
#' 
#' * These variables have a constant value of '0' for all the rows with Canceled = 1. i.e. simply there was no information captured about arrival and departure delays when a flight was canceled
#' 
#' * If these variables are used, the model will incorrectly associate the value of '0' directly with target variable instance (Canceled = 1)
#' 
#' * Therefore, we cannot use the Arrival Delay and Departure Delay variables in the model

#' #### Sample rows when Canceled = 1

data1 = FlightData[c(1:5),c(1,6,7)]
row.names(data1) = NULL
data1

#' #### Sample rows when Canceled = 0

data2 = FlightData[c(1001:1005),c(1,6,7)]
row.names(data2) = NULL
data2



#' ### Splitting the dataset into training and test set

library(caTools)
set.seed(123)
split = sample.split(dataset$Canceled, SplitRatio = 0.75)
training_set = subset(dataset, split == TRUE)
test_set = subset(dataset, split == FALSE)

vector = c(length(training_set$Canceled),length(test_set$Canceled))
names(vector) = c('training_set','test_set')
vector


#' ### Feature Scaling the numerical variables

for(i in c(3,5,8)){
  training_set[,i] = as.numeric(training_set[,i])
  test_set[,i] = as.numeric(test_set[,i])
}

training_set[,c(3,5,8)] = scale(training_set[,c(3,5,8)])
test_set[,c(3,5,8)] = scale(test_set[,c(3,5,8)])


 
#' ### Logistic Regression Model
#' 
# Fitting the model
classifier_logistic = glm(formula = Canceled ~ Month+DepartureTime+UniqueCarrier+ScheduledFlightTime+Distance,family = binomial,data = training_set)

# Predicting the test set results
prob_pred = predict(classifier_logistic,type = 'response',newdata = test_set[,c(2,3,4,5,8)])
y_pred = ifelse(prob_pred > 0.5,1,0)

# computing the confusion matrix
cm = table(test_set[,1],y_pred)
print(cm)

# computing the Accuracy
accuracy = sum(diag(cm))/length(test_set[,1])
print(round(accuracy*100,2))

# computing the AUC value
library(pROC)
auc = auc(roc(test_set[,1],y_pred))
print(round(auc,2))

# Cross-validation - to evaluate the model
library(caret)
folds = createFolds(training_set$Canceled, k = 10)

cv = lapply(folds, function(x) {
  training_fold = training_set[-x, ]
  test_fold = training_set[x, ]
  classifier_logistic = glm(formula = Canceled ~ Month+DepartureTime+UniqueCarrier+ScheduledFlightTime+Distance,family = binomial,data = training_fold)
  prob_pred = predict(classifier_logistic, newdata = test_fold[,c(2,3,4,5,8)])
  y_pred = ifelse(prob_pred > 0.5,1,0) 
  cm = table(test_fold[,1], y_pred)
  accuracy = (cm[1,1] + cm[2,2]) / (cm[1,1] + cm[2,2] + cm[1,2] + cm[2,1])
  return(accuracy)
})

cv_accuracy = mean(as.numeric(cv))
print(round(cv_accuracy*100,2))

accuracy_matrix = c(round(accuracy*100,2))
names(accuracy_matrix)[1] = c('LogisticRegression')

auc_matrix = c(round(auc,2))
names(auc_matrix)[1] = c('LogisticRegression')

cv_accuracy_matrix = c(round(cv_accuracy*100,2))
names(cv_accuracy_matrix)[1] = c('LogisticRegression')


#' ### Random Forest Model

library(randomForest)

# Fitting the model
classifier_rf = randomForest(x = training_set[,c(2,3,4,5,8)],y = training_set[,1],ntree = 100)

# Predicting the test set results
y_pred = predict(classifier_rf, newdata = test_set[,c(2,3,4,5,8)])

# computing the confusion matrix
cm = table(test_set[,1],y_pred = as.numeric(as.character(y_pred)))
print(cm)

# computing the Accuracy
accuracy = sum(diag(cm))/length(test_set[,1])
print(round(accuracy*100,2))

# computing the AUC value
auc = auc(roc(test_set[,1],as.numeric(as.character(y_pred))))
print(round(auc,2))

# Cross-validation - to evaluate the model
folds = createFolds(training_set$Canceled, k = 10)

cv = lapply(folds, function(x) {
  training_fold = training_set[-x, ]
  test_fold = training_set[x, ]
  classifier_rf = randomForest(x = training_fold[,c(2,3,4,5,8)],y = training_fold[,1],ntree = 100)
  y_pred = predict(classifier_rf, newdata = test_fold[,c(2,3,4,5,8)])
  cm = table(test_fold[,1], y_pred)
  accuracy = (cm[1,1] + cm[2,2]) / (cm[1,1] + cm[2,2] + cm[1,2] + cm[2,1])
  return(accuracy)
})

cv_accuracy = mean(as.numeric(cv))
print(round(cv_accuracy*100,2))

accuracy_matrix = c(accuracy_matrix,round(accuracy*100,2))
names(accuracy_matrix)[2] = c('RandomForest')

auc_matrix = c(auc_matrix,round(auc,2))
names(auc_matrix)[2] = c('RandomForest')

cv_accuracy_matrix = c(cv_accuracy_matrix,round(cv_accuracy*100,2))
names(cv_accuracy_matrix)[2] = c('RandomForest')


#' ### XGBoost Model

# XGBoost requires data in a numerical and matrix format
# Also, synthetic sample generation must be redone on numerical data

FlightData$Month = as.numeric(FlightData$Month)
FlightData$UniqueCarrier = as.numeric(FlightData$UniqueCarrier)

dataset = SMOTE(Canceled ~ .,FlightData,perc.over = 150,perc.under = 300) # synthetic sample

dataset$Canceled = as.numeric(as.character(dataset$Canceled))

training_set = subset(dataset, split == TRUE)
test_set = subset(dataset, split == FALSE)

library(xgboost)

# Fitting the model
classifier_xgb = xgboost(data = as.matrix(training_set[,c(2,3,4,5,8)]), label = training_set$Canceled, nrounds = 10, objective = 'binary:logistic', verbose = 0)

# Predicting the test set results
y_pred = predict(classifier_xgb, newdata = as.matrix(test_set[,c(2,3,4,5,8)]))
y_pred = (y_pred >= 0.5)

# computing the confusion matrix
cm = table(test_set[,1],y_pred = as.numeric(y_pred))
print(cm)

# computing the Accuracy
accuracy = sum(diag(cm))/length(test_set[,1])
print(round(accuracy*100,2))

# computing the AUC value
auc = auc(roc(test_set[,1],as.numeric(y_pred)))
print(round(auc,2))

# Cross-validation - to evaluate the model
folds = createFolds(training_set$Canceled, k = 10)

cv = lapply(folds, function(x) {
  training_fold = training_set[-x, ]
  test_fold = training_set[x, ]
  classifier_xgb = xgboost(data = as.matrix(training_fold[,c(2,3,4,5,8)]), label = training_fold$Canceled, nrounds = 10, objective = 'binary:logistic', verbose = 0 )
  y_pred = predict(classifier_xgb, newdata = as.matrix(test_fold[,c(2,3,4,5,8)]))
  y_pred = (y_pred >= 0.5)
  cm = table(test_fold[,1], y_pred)
  accuracy = (cm[1,1] + cm[2,2]) / (cm[1,1] + cm[2,2] + cm[1,2] + cm[2,1])
  return(accuracy)
})

cv_accuracy = mean(as.numeric(cv))
print(round(cv_accuracy*100,2))

accuracy_matrix = c(accuracy_matrix,round(accuracy*100,2))
names(accuracy_matrix)[3] = c('XGBoost')

auc_matrix = c(auc_matrix,round(auc,2))
names(auc_matrix)[2] = c('XGBoost')

cv_accuracy_matrix = c(cv_accuracy_matrix,round(cv_accuracy*100,2))
names(cv_accuracy_matrix)[2] = c('XGBoost')

 
#' ## Model Selection (Final Model)
#' 
#' ### Comparing the model results

model_comparison = cbind(accuracy_matrix,auc_matrix)
model_comparison = cbind(model_comparison,cv_accuracy_matrix)
model_comparison = as.data.frame(model_comparison)
colnames(model_comparison) = c(' Accuracy ','  AUC  ','CV Accuracy')

library(knitr)
kable(model_comparison,align = 'c',caption = "* Accuracy - Test set accuracy ; AUC - Area under curve ; CV Accuracy - Cross validation accuracy")


#' 1. **Test Set Accuracy**: There are significant differences in the accuracies of each model listed above and XGBoost has the highest accuracy among the three models
#' 
#' 2. **Model Stability**: Cross validation was performed to validate the stability of the model outside the sample to a new data set. All the models have cross validation accuracies that are little above the test set accuracies indicating the models are stable. It also indicates lesser risk of having problems such as over-fitting
#' 
#' 3. **Area under ROC Curve**: For a classification model, it is also important to asses whether your model predicts the positive and negative classes best. Area under ROC curve provides that estimate by measuring the sensitivity (True postive rate) and specificity (False positive rate). Higher the AUC, the better the model. XGBoost has the highest Area under curve among the three models
#' 
#' 4. **Interpretability**: Apart from the above metrics, it is important to choose a model that has good interpretability. Both logistic regression and XGBoost provides interpreatbily whereas Random Forest does not
#' 
#' **Based on the above four model evalautions, XGBoost has the best performance among all and it also has good interpretability. Therefore, let's choose XGBoost as our final model**

 
#' ### Performance tuning the XGBoost model

library(caret)

tune_set = training_set
tune_set$Canceled = factor(tune_set$Canceled)

cv_ctrl = trainControl(method = 'repeatedcv',number = 10,repeats = 1)
tune_grid = expand.grid(nrounds = c(10,20,40),eta = c(0.1,0.2,0.3),max_depth = c(3,7,10),gamma = 0,min_child_weight=1,colsample_bytree= c(0.5,0.75,1.0),subsample = c(0.5,0.7,0.9))

xgb_tune = train(form = Canceled ~ Month+DepartureTime+UniqueCarrier+ScheduledFlightTime+Distance,data = tune_set[,c(1,2,3,4,5,8)], method = 'xgbTree',trControl = cv_ctrl,tuneGrid = tune_grid)

print(xgb_tune$bestTune)

 
#' ### Building the final model with tuned parameters

library(xgboost)
set.seed(3)

# Fitting the model
classifier_xgb = xgboost(data = as.matrix(training_set[,c(2,3,4,5,8)]), label = training_set$Canceled, nrounds = 40, objective = 'binary:logistic', verbose = 0, max_depth = 7, eta = 0.2, gamma = 0, colsample_bytree = 0.5, min_child_weight = 1, subsample = 0.9)

# Predicting the test set results
y_pred = predict(classifier_xgb, newdata = as.matrix(test_set[,c(2,3,4,5,8)]))
y_pred = (y_pred >= 0.5)

# computing the confusion matrix
cm = table(test_set[,1],y_pred = as.numeric(y_pred))
print(cm)

# computing the Accuracy
accuracy = sum(diag(cm))/length(test_set[,1])
print(round(accuracy*100,2))

# computing the AUC value
auc = auc(roc(test_set[,1],as.numeric(y_pred)))
print(round(auc,2))

#' **The final model (XGBoost) provides an accuracy of 78.64% with area under curve 0.75**


#' ### Interpreting the model results

# Feature Importance
importance = xgb.importance(feature_names = colnames(training_set[,c(2,3,4,5,8)]),model = classifier_xgb)

# Table
kable(importance,align = 'l',caption = "Feature Importance")

# Plot
xgb.plot.importance(importance_matrix = importance,measure = NULL)


#' * Month is the most important variable with the highest information gain (38.5%). This implies that flight cancellations are indeed seasonal and that has the major effect among all the features for the provided dataset
#' 
#' * All other features namely Distance, Flight time, Departure time and Carrier have similar importance in determining flight cancellations and their information gain values range between 13 - 19 %
#' 
#' * In the table, the measure 'Cover' simply provides the relative number of observations that are split by a feature into either of the two label classes (1 or 0)
 

#' ## Function To Predict Future Outcome
#' 
#' * The following function 'isFlightCanceled' will take feature inputs for a flight, use the above model output and provides a decision whether that flight will get canceled including the probability
#' 
#' ### Function

isFlightCanceled = function(month,distance,departureTime,flightTime,uniqueCarrier){
  
  month = ifelse(month<=4, 1, ifelse(month<=8, 2, 3)) #convert raw month into buckets 1,2,3
  uniqueCarrier = ifelse(uniqueCarrier=='AA', 1, ifelse(uniqueCarrier=='DL', 2, 3)) #encode Carrier name into values 1,2,3

  Data = c(Month = month,DepartureTime = departureTime,UniqueCarrier = uniqueCarrier,ScheduledFlightTime = flightTime,Distance = distance)
  
  outcome_prob = predict(classifier_xgb, newdata = as.matrix(t(Data)))
  outcome_value = (outcome_prob >= 0.5)
  outcome = c(outcome_value,outcome_prob)
  
  return(outcome)

}

#' * In real, the values will be read from an application or user using readline() function
#' * For the purpose of this document, sample values are fed directly
#' 
#' ### Sample Input

month = 3
distance = 679
departureTime = 814
flightTime = 134
uniqueCarrier = 'UA'


#' ### Test Function

Outcome = isFlightCanceled(month,distance,departureTime,flightTime,uniqueCarrier)

if(Outcome[1]==1){
  print(paste("The flight will get cancelled with a probability of",round(Outcome[2],2)))
} else {
  print("The flight will not get cancelled")
}


#' ## Recommendation - Most Reliable Airline
#' 
#' ### Visualizing the cancellations

Data = read.csv(file = "Data_PredictingFlightDelays.csv",header = FALSE,
                      col.names = c('Canceled','Month','DepartureTime','UniqueCarrier',
                                    'ScheduledFlightTime','ArrivalDelay','DepartureDelay','Distance'))
Data$UniqueCarrier = as.character(Data$UniqueCarrier)

#detach("package:ggplot2", unload=TRUE)


#' * Let's take a look at the number of cancellations in each airline carrier for the given dataset

#library(dplyr)
cancellations = Data %>% group_by(UniqueCarrier) %>% summarise(Cancelled_Flights = sum(Canceled), Total_Flights = length(Canceled))
cancellations$Percent_Cancelled = round((cancellations$Cancelled_Flights/cancellations$Total_Flights)*100,2)

kable(cancellations,align = 'c',caption = "Flight Cancellations")

#library(ggplot2)
ggplot(data = cancellations,aes(x = UniqueCarrier,y = Percent_Cancelled)) + geom_bar(stat = "identity")  + ggtitle("Canceled Flights") + xlab('Carrier') + ylab('% Canceled')


#' * Airline carrier 'DL' has the least number of % cancellations followed by carrier 'UA' and carrier 'AA'


#' ### Computing average cancellation probability
#' 
#' * We can compute the probability for whether a particular flight will get canceled using the model that we have built
#' 
#' * Then, we can compute the average of such probabilities for flights in each airline carrier
#' 
#' * This measure will provide us a fair idea about which airline has the least risk of cancellation

FlightData$Month = as.numeric(FlightData$Month)
FlightData$DepartureTime = as.numeric(FlightData$DepartureTime)
FlightData$ScheduledFlightTime = as.numeric(FlightData$ScheduledFlightTime)
FlightData$Distance = as.numeric(FlightData$Distance)

# Taking an unbiased sample that has equal representation of each airline carrier i.e. equal number of flight observations
AA_Flight_Data = sample_n(FlightData[FlightData$UniqueCarrier==1,c(2,3,4,5,8)],1500)
DL_Flight_Data = sample_n(FlightData[FlightData$UniqueCarrier==2,c(2,3,4,5,8)],1500)
UA_Flight_Data = sample_n(FlightData[FlightData$UniqueCarrier==3,c(2,3,4,5,8)],1500)

# Predicting the probabilities for different airline carriers
pred_Prob_AA = predict(classifier_xgb, newdata = as.matrix(AA_Flight_Data))
pred_Prob_DL = predict(classifier_xgb, newdata = as.matrix(DL_Flight_Data))
pred_Prob_UA = predict(classifier_xgb, newdata = as.matrix(UA_Flight_Data))
                       
# Computing the average probability
avg_cancellation_prob = c(AA = round(mean(pred_Prob_AA),2),DL = round(mean(pred_Prob_DL),2),UA = round(mean(pred_Prob_UA),2))

kable(t(avg_cancellation_prob),align = 'c',caption = "Average Cancellation Probabilities by Carrier")


#' **Airline carrier 'DL' has the least risk of cancellation since it has the least value of cancellation probability among all three carriers**   


#' ### Computing average arrival delay and departure delay

#detach("package:ggplot2", unload=TRUE)

# Remove the cases of early arrivals and early departures of flight schedule i.e. the negative values 
Data$ArrivalDelay = ifelse(Data$ArrivalDelay<=0,NA,Data$ArrivalDelay)
Data$DepartureDelay = ifelse(Data$DepartureDelay<=0,NA,Data$ArrivalDelay)

#library(dplyr)
average_delay = Data %>% group_by(UniqueCarrier) %>% summarise(avg_arrival_delay = round(mean(ArrivalDelay,na.rm = TRUE),2),avg_departure_delay = round(mean(DepartureDelay,na.rm = TRUE),2))

kable(average_delay,align = 'c',caption = "Flight Arrival/Departure Delays")

 
#' * Airline carrier 'DL' has the least arrival delay as well as departure delay among all three carriers


#' **Airline carrier 'DL' is the most reliable airline as it has the least risk of cancellation as well as least arrival and departure delays**
