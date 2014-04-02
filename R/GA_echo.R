# install.packages("caret")
# install.packages("ggplot2")
# install.packages("reshape2")
# install.packages("RColorBrewer")
# install.packages("GA")
# install.packages("latticeExtra")
# install.packages("pROC")
# install.packages("doMC")
# install.packages("caTools")
#install.packages("doParallel")
#install.packages("kernlab")

library(caret)
library(ggplot2)
library(reshape2)
library(RColorBrewer)
library(GA)
library(latticeExtra)
library(pROC)
library(doMC)
library(MASS)
library(caTools)
library(doParallel)
#library(kernlab)

## CLEAR WORKSPACE
rm(list=ls())

## load data
#setwd("/home/mornin/Dropbox/ECHO/R/reresults");
fulldata <- read.csv("data-2.csv")
# fulldata1<- fulldata
# fulldata1<- transform(fulldata
#                       , GENDER_NUM= factor(GENDER_NUM))

fulldata1<- transform(fulldata
              , GENDER_NUM=factor(GENDER_NUM, c(0,1))
            , SERVICE_NUM=factor(SERVICE_NUM, c(0,1,2)) #remove csru
            , VENT_FLG=factor(VENT_FLG, c(0,1))
            , VASO_FLG=factor(VASO_FLG, c(0,1))
            , ANES_12HR_FLG=factor(ANES_12HR_FLG, c(0,1))
            , CHF_FLG=factor(CHF_FLG, c(0,1))
            , AFIB_FLG=factor(AFIB_FLG, c(0,1))
            , RENAL_FLG=factor(RENAL_FLG, c(0,1))
            , LIVER_FLG=factor(LIVER_FLG, c(0,1))
            , COPD_FLG=factor(COPD_FLG, c(0,1))
            , CAD_FLG=factor(CAD_FLG, c(0,1))
            , STROKE_FLG=factor(STROKE_FLG, c(0,1))
            , MAL_FLG=factor(MAL_FLG, c(0,1))
            , WBC_ABNORMAL_FLG=factor(WBC_ABNORMAL_FLG, c(0,1))
            , HGB_ABNORMAL_FLG=factor(HGB_ABNORMAL_FLG, c(0,1))
            , PLATELET_ABNORMAL_FLG=factor(PLATELET_ABNORMAL_FLG, c(0,1))
            , SODIUM_ABNORMAL_FLG=factor(SODIUM_ABNORMAL_FLG, c(0,1))
            , POTASSIUM_ABNORMAL_FLG=factor(POTASSIUM_ABNORMAL_FLG, c(0,1))
            , TCO2_ABNORMAL_FLG=factor(TCO2_ABNORMAL_FLG, c(0,1))
            , CHLORIDE_ABNORMAL_FLG=factor(CHLORIDE_ABNORMAL_FLG, c(0,1))
            , BUN_ABNORMAL_FLG=factor(BUN_ABNORMAL_FLG, c(0,1))
            , CREATININE_ABNORMAL_FLG=factor(CREATININE_ABNORMAL_FLG, c(0,1))
            , LACTATE_ABNORMAL_FLG=factor(LACTATE_ABNORMAL_FLG, c(0,1))
            , PH_ABNORMAL_FLG=factor(PH_ABNORMAL_FLG, c(0,1))
            , PO2_ABNORMAL_FLG=factor(PO2_ABNORMAL_FLG, c(0,1))
            , PCO2_ABNORMAL_FLG=factor(PCO2_ABNORMAL_FLG, c(0,1))                   
                              )
fulldata1=fulldata1[complete.cases(fulldata1),]

## define objective function
## 'ind' is a vector of 0/1 data denoting which features are being evaluated.
ROCcv <- function(ind, x, y, cntrl)
{
  library(caret)
  library(MASS)
  ind <- which(ind == 1)
  if(length(ind) == 0) return(0)
  # max allowed feature number = 20
  if(length(ind) > 50) return(0)
  out <- train(x[,ind], y, method = "glm",
               metric = "ROC", trControl = cntrl)
  caret:::getTrainPerf(out)[, "TrainROC"]
}

# ROCcv1 <- function(ind, data, cntrl)
#   {
#   #library(caret)
#   #library(MASS)
#   ind <- which(ind == 1)
#   if(length(ind) == 0) return(0)
#   # max allowed feature number = 20
#   if(length(ind) > 20) return(0)
#   out <- train(CLASS~., data, method = "qda",
#                metric = "ROC", trControl = cntrl)
#   caret:::getTrainPerf(out)[, "TrainROC"]
#   }
# define initialization fucntion  
initialPop <- function(object, ...) 
{
    population <- sample(0:1, 
                         replace = TRUE, 
                         size = object@nBits * object@popSize, 
                         prob = c(0.9, 0.1))
    population <- matrix(population, 
                         nrow = object@popSize, 
                         ncol = object@nBits)
    return(population)
}  

## For testing
# ## set-up cross-validation
cvIndex <- caret::createMultiFolds(fulldata1$CLASS, times = 1)
ctrl <- caret::trainControl(method = "repeatedcv",
                            repeats = 1,
                            classProbs = TRUE,
                            summaryFunction = twoClassSummary,
                            allowParallel = TRUE,
                            index = cvIndex)
# temp=as.double(rep(1,79))
# #ROCcv1(temp,fulldata1,ctrl)
# x = fulldata1[,-ncol(fulldata1)]
# y = fulldata1$CLASS
# ROCcv(temp,x,y,ctrl)
# 
# train(x,y, method = "glm", metric = "ROC", trControl = ctrl)
#  modelAll <- train(CLASS ~ ., data = fulldata1, method = "qda", metric = "ROC", trControl = ctrl)
# caret:::getTrainPerf(modelAll)[, "TrainROC"]


# ## call Genetic Algrithm to do feature selection (generation No. = maxiter, it might take 4 mins per generation)

set.seed( as.integer((as.double(Sys.time())*1000+Sys.getpid()) %% 2^31) )
ga_results <- ga(type = "binary",
                 fitness = ROCcv,
                 min = 0, max = 1,
                 maxiter = 1000,
                 population = initialPop,
                 nBits = ncol(fulldata1) - 1,
                 names = names(fulldata1)[-ncol(fulldata1)],
                 x = fulldata1[,-ncol(fulldata1)],
                 y = fulldata1$CLASS,
                 cntrl = ctrl,
                 keepBest = TRUE,
                 parallel = TRUE)
# ## view results
 summary(ga_results)

Sys.time()

# ## obtain feature vector

solution <- ga_results@solution
features <- which(solution[nrow(solution),]!=0)
write.csv(features, file = "features2_1000.csv")
# ## build model using all features
# modelAll <- train(CLASS ~ ., data = fulldata, method = "qda", metric = "ROC", trControl = ctrl)
# ## make predictions using modelAll
# #prediction <- predict(modelAll, fulldata, type = "prob")
# # build model using selected features
modelReduced <- train(fulldata1[,features],fulldata1$CLASS, method = "glm", metric = "ROC", trControl = ctrl)  		   
# ## make predictions using modelReduced
#prediction <- predict(modelReduced, fulldata1[,features], type = "prob")
# ## view first a few predictions, the score of each samples can be found here 
# head(prediction)
# ## generate ROC curve
# curve <- roc(fulldata$CLASS, prediction[,1], levels = rev(levels(fulldata$CLASS)))
# ## plot ROC curve and compute AUROC
# rocColors <- c("black", "grey", brewer.pal(8,"Dark2"))
# plot(curve, col = rocColors[1], lwd = 2)
# 


# cvIndex <- caret::createMultiFolds(fulldata$CLASS, times = 2)
# ctrl <- caret::trainControl(method = "repeatedcv",
#                      repeats = 2,
#                      classProbs = TRUE,
#                      summaryFunction = twoClassSummary,
#                      allowParallel = FALSE,
#                      index = cvIndex)
# ## call Genetic Algrithm to do feature selection (generation No. = maxiter, it might take 4 mins per generation)
# set.seed(123)
# ga_results <- ga(type = "binary",
#                  fitness = ROCcv,
#                  min = 0, max = 1,
#                  maxiter = 100,
#                  population = initialPop,
#                  nBits = ncol(fulldata) - 1,
#                  names = names(fulldata)[-ncol(fulldata)],
#                  x = fulldata[,-ncol(fulldata)],
#                  y = fulldata$CLASS,
#                  cntrl = ctrl,
#                  keepBest = TRUE,
#                  parallel = TRUE)
# ## view results
# summary(ga_results)

