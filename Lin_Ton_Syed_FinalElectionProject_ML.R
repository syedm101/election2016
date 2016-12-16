#DS 4559 Final Project
#Exploring the 2016 Election, Machine Learning Code
#Nathan Lin, Andrew Ton, Mansoor Syed

census <- read.csv("Data/2016dataprimary/county_facts.csv", header = TRUE, stringsAsFactors = TRUE)
#check for unclean data
data <- subset(census,select=c("fips", "area_name", "state_abbreviation", "POP060210","PST040210","AGE775214","SEX255214","RHI225214", "RHI325214", "RHI425214", "RHI525214", "RHI725214", "RHI825214", "EDU635213", "EDU685213", "INC110213", "PVY020213"))
data <- subset(data, fips !=0) #remove USA
data <- subset(data, state_abbreviation !="") #remove states
colnames(data) <- c("fips", "area_name", "state_abbreviation", "pop_sqr_mile2010","pop_total_2010","pop_65+","p_female","p_black", "p_indian", "p_asian", "p_PI", "p_hisp", "p_white", "p_HS", "p_bachelors", "median_Income", "p_below_poverty_line")
pairs(data[,4:8])
data$fips <- as.factor(data$fips)
#set factors correctly

symnum(cor(data[,4:17], use="complete.obs"))
#originally, we had both median income & percent below poverty line. since these had a 60% correlation we chose to keep just median income
data <- data[,1:16]

#import cleaned election data
clean_2012 <- read.csv("Data/clean_2012.csv")
clean_2012 <- clean_2012[,c(2,6)]
clean_2012$fips <- as.factor(clean_2012$fips)

clean_2016 <- read.csv("Data/clean_2016.csv")
clean_2016 <- clean_2016[,c(2,8)]
#Fix Ogala Lakota County FIPS code
clean_2016 [5359,]$fips <- 46113
clean_2016 [5360,]$fips <- 46113
clean_2016$fips <- as.factor(clean_2016$fips)

data_2012 <- merge(data, clean_2012,by="fips")

data_2016 <- merge(data, clean_2016,by="fips")
data_2016 <- data_2016[seq(1, 6223, 2),]

#write the files for later use
write.csv(data_2016, file = "Data/2016+census+results.csv")
write.csv(data_2012, file = "Data/2012+census+results.csv")

#Randomly order the data
set.seed(5)
data_2012 <- data_2012[order(runif(3112)), ]
data_2012$ObamaWin <- as.factor(data_2012$ObamaWin)

data_2016 <- data_2016[order(runif(3112)), ]

#Split the data ~80% training and 20% testing
train_2012 <- data_2012[1:2489,]
test_2012<- data_2012[2489:3112,]

train_2016 <- data_2016[1:2489,]
test_2016<- data_2016[2489:3112,]

#One way to look at attribute importance

library(caret)
library(corrplot)
library(DMwR)
library(ggplot2)
library(reshape2)
library(plyr)
library(sqldf)
library(mlbench)
library(randomForest)
library(gmodels)
library(party)
library(C50)
library(RWeka)

model <- train(ObamaWin ~., data=train_2012[,4:17], method="lvq", preProcess="scale")#, trControl=control)
#Estimating variable importance
importance <- varImp(model, scale=FALSE)
print(importance)
plot(importance, ylab = 'Attributes', main = 'Attribute Importance')

#2016
## FIX NA PROBLEM!!!!!!!!!!!!
model <- train(lead ~., data=train_2016[,4:17], method="lvq", preProcess="scale")#, trControl=control)
#Estimating variable importance
importance <- varImp(model, scale=FALSE)
print(importance)
plot(importance, ylab = 'Attributes', main = 'Attribute Importance')


####################################################### REANALYZE!!!!!
# our testing data has WAY more trump counties? fix later?
tree_model = ctree(ObamaWin ~ ., train_2012[,4:17]) 
plot(tree_model)
ctree_pred <- predict(tree_model,test_2012[,4:17])
CrossTable(test_2012$ObamaWin, ctree_pred,
           prop.chisq = FALSE, prop.c = FALSE, prop.r = FALSE,
           dnn = c('Actual Type', 'Predicted Type'))


ctree_pred2 <- predict(tree_model,test_2016[,4:17])
CrossTable(test_2016$lead, ctree_pred,
           prop.chisq = FALSE, prop.c = FALSE, prop.r = FALSE,
           dnn = c('Actual Type', 'Predicted Type'))

#Using jRip
jrip_model <- JRip(ObamaWin ~ ., train_2012[,4:17])
jrip_model

jrip_pred <- predict(jrip_model,test_2012[,4:17])
jrip_pred2 <- predict(jrip_model,test_2016[,4:17])

CrossTable(test_2012$ObamaWin, jrip_pred,
           prop.chisq = FALSE, prop.c = FALSE, prop.r = FALSE,
           dnn = c('Actual Type', 'Predicted Type'))

#Using 2012 model for 2016 election
CrossTable(test_2016$lead, jrip_pred2,
           prop.chisq = FALSE, prop.c = FALSE, prop.r = FALSE,
           dnn = c('Actual Type', 'Predicted Type'))

jrip_model2 <- JRip(lead ~ ., train_2016[,4:17])
jrip_model2

jrip_pred3 <- predict(jrip_model2,test_2016[,4:17])
CrossTable(test_2016$lead, jrip_pred3,
           prop.chisq = FALSE, prop.c = FALSE, prop.r = FALSE,
           dnn = c('Actual Type', 'Predicted Type'))

data12_knn <- data_2012[,4:17]
data16_knn <- data_2016[,4:17]


## We must ALWAYS normalize data before using the kNN algorithm.  Why?
## Here, we write a function to normalize any vector of variables, x.
normalize <- function(x) {
  return((x-min(x))/(max(x)-min(x)))
}

## Now, we divide the data into testin and training data (just the attributes)
prc_train <- as.data.frame(lapply(data12_knn[1:2489,1:13], normalize))
prc_test <- as.data.frame(lapply(data12_knn[2490:3112,1:13], normalize))

## We make separate vectors for the classes for training and testing that correspond to the 
## matrices above:


prc_train_labels <- data12_knn[1:2489,14]
prc_test_labels <- data12_knn[2490:3112,14]

## "class" is the package that allows us to perform kNN analysis
library(class)

## Here we perform kNN analysis.  k= 15
prc_test_pred <- knn(train=prc_train,test=prc_test,cl=prc_train_labels,k=15)

## Evaluate

library(gmodels)
CrossTable(x=prc_test_labels, y=prc_test_pred,prop.chisq = FALSE)
#2012 KNN Accuracy 86.8%



####2016 Election

prc_test <- as.data.frame(lapply(data16_knn[2490:3112,1:13], normalize))
prc_test_labels <- data16_knn[2490:3112,14]

## "class" is the package that allows us to perform kNN analysis
library(class)

## Here we perform kNN analysis.  k= 15
#Using 2012 data to predict 2016
prc_test_pred <- knn(train=prc_train,test=prc_test,cl=prc_train_labels,k=15)
CrossTable(x=prc_test_labels, y=prc_test_pred,prop.chisq = FALSE)
#91.65%

#set 
prc_train <- as.data.frame(lapply(data16_knn[1:2489,1:13], normalize))
prc_train_labels <- data16_knn[1:2489,14]
prc_test_pred <- knn(train=prc_train,test=prc_test,cl=prc_train_labels,k=15)

## Evaluate

library(gmodels)
CrossTable(x=prc_test_labels, y=prc_test_pred,prop.chisq = FALSE)
#2016 accuracy 93.57


#Predicting all of 2016 results using 2012
jrip_model_whole <- JRip(ObamaWin ~ ., data_2012[,4:17])
jrip_model_whole

jrip_pred_whole <- predict(jrip_model_whole,data_2016[,4:17])
CrossTable(data_2016$lead, jrip_pred_whole,
           prop.chisq = FALSE, prop.c = FALSE, prop.r = FALSE,
           dnn = c('Actual Type', 'Predicted Type'))
