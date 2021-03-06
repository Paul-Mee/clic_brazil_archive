###
### Script to call other R scripts to download and process Brazil.IO data 
### and prepare data for loading to the app 
### a log file is written to enable tracking of the files
### Paul Mee 20-May-2020
### Updated 19th Aug 2020 with Rt estimates 
### Updated 11th November 2020 (v3) with new version of past the peak 
### Check file directories in CLIC_Brazil_Script_directories
###

require(dplyr)
require(sf)

# ### Set up log file sink()
today <- Sys.Date()
today <- format(today, format="%d-%B-%Y")

log_fil_dir <- "C:/github/clic_brazil_tmp/log_files/"
dir_scripts <- "C:/github/clic_brazil_tmp/"



now_time <- Sys.time() 
print(now_time)
print( "Start time")

### Step 1 load the data 

source (paste0(dir_scripts,"CLIC_Brazil_Dataload.R"),echo=TRUE)

today <- Sys.Date()
today <- format(today, format="%d-%B-%Y")
log_file <- paste0(log_fil_dir,"br_data_batch", today,".log")
sink(file=log_file,append=FALSE)
print("Step 1 - Case data download -  current time")
now_time <- Sys.time() 
print(now_time)
closeAllConnections()
#sink()
## clear memory 
#gc()
# 

### Step 2 Initial data cleaning  

source (paste0(dir_scripts,"CLIC_Brazil_Data_cleaning.R"),echo=TRUE)

today <- Sys.Date()
today <- format(today, format="%d-%B-%Y")
log_file <- paste0(log_fil_dir,"br_data_batch", today,".log")
sink(file=log_file,append=TRUE)
print("Step 2 - Data cleaning -  current time")
now_time <- Sys.time() 
print(now_time)
closeAllConnections()
#sink()
#  
## clear memory 
#gc()

### Step 3 Data Standardisation 

source (paste0(dir_scripts,"CLIC_Brazil_standardisation_implementation.R"),echo=TRUE)

today <- Sys.Date()
today <- format(today, format="%d-%B-%Y")
log_file <- paste0(log_fil_dir,"br_data_batch", today,".log")
sink(file=log_file,append=TRUE)
print("Step 3 - Data Standardisation -  current time")
now_time <- Sys.time() 
print(now_time)
closeAllConnections()
#sink()


### Step 4 Rt Estimation  

source (paste0(dir_scripts,"CLIC_Brazil_calculate_Rt_Estimates.R"),echo=TRUE)

today <- Sys.Date()
today <- format(today, format="%d-%B-%Y")
log_file <- paste0(log_fil_dir,"br_data_batch", today,".log")
sink(file=log_file,append=TRUE)
print("Step 4 - Rt Estimation -  current time")
now_time <- Sys.time() 
print(now_time)
closeAllConnections()
#sink()
## clear memory 
#gc()


### Step 5 Peak prediction forecasting 

source (paste0(dir_scripts,"CLIC_Brazil_peak_prediction.R"),echo=TRUE)

today <- Sys.Date()
today <- format(today, format="%d-%B-%Y")
log_file <- paste0(log_fil_dir,"br_data_batch", today,".log")
sink(file=log_file,append=TRUE)
print("Step 5 - Forecasting -  current time")
now_time <- Sys.time() 
print(now_time)
closeAllConnections()
#sink()



rm(list=ls())