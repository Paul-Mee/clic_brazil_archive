### R script to process Brazil.IO case data 
###############################################

### Required libraries
library(httr)
library(jsonlite)
library(dplyr)
library(reshape2)

### Data clean up

rm(list=ls())

##############
### Directory set up
### Update this with your local directories
##############
dir_scripts <- "C:/github/clic_brazil/"

source (paste0(dir_scripts,"CLIC_Brazil_Script_directories.R"))

# get daily update 
today <- Sys.Date()
today <- format(today, format="%d-%B-%Y")

##############
### API call to get data 
#############


## Get all data in csv format 
brazil_io_csv <- scan (gzcon(rawConnection(content( GET("https://data.brasil.io/dataset/covid19/caso.csv.gz")))),what="",sep="\n")  
brazil_io_full <- data.frame(strsplit(brazil_io_csv, ",")) 

row.names(brazil_io_full) <- brazil_io_full[,1]
# transpose data 
brazil_io_full <- t(brazil_io_full[,-1])
# delete row names
rownames(brazil_io_full) <- c()

fname <- paste0(dir_source_data,"brazil_raw_cases_api_", today,".csv")
write.csv(brazil_io_full,file = fname,row.names=FALSE)

##############
### STEP 1 Data formatting from API download format  
#############

# ### Cases data 
# # Code to read in  Brazil.io data and reformat in correct format
brazil_cases_dat <- data.frame(brazil_io_full)
brazil_cases_dat$date <- as.Date(brazil_cases_dat$date, format = "%Y-%m-%d")

## Keep city level data 
brazil_cases_dat <- brazil_cases_dat[ which(brazil_cases_dat$place_type=='city'),]
# Remove cases which cannot be assigned to a particular municipality 
brazil_cases_dat <- brazil_cases_dat[ which(!brazil_cases_dat$city=='Importados/Indefinidos'),]

######
### This next section deals with the situation where the total cases decreases on a particular day 
### this is corrected by subtracting the decrease from the next days total
### this is continued in a loop until the dat increases each day 
#####


### Sort by Date , State and Municipality 
brazil_cases_dat <- brazil_cases_dat[with(brazil_cases_dat, order(state, city, date)), ]

brazil_cases_dat$confirmed <- as.numeric(as.character(brazil_cases_dat$confirmed))
brazil_cases_dat$deaths <- as.numeric(as.character(brazil_cases_dat$deaths))

# Drop rows where confirmed = 0 
brazil_cases_dat <- brazil_cases_dat[ which(!brazil_cases_dat$confirmed==0),]

# incremental increases in cases
brazil_cases_dat <- brazil_cases_dat %>%
  group_by(state,city) %>%
  mutate(case_inc = confirmed - dplyr::lag(confirmed))


# incremental increases in deaths
brazil_cases_dat <- brazil_cases_dat %>%
  group_by(state,city) %>%
  mutate(death_inc = deaths - dplyr::lag(deaths))



### First entry = NA so replace with confirmed value
brazil_cases_dat$case_inc <- ifelse(is.na(brazil_cases_dat$case_inc), brazil_cases_dat$confirmed, brazil_cases_dat$case_inc)
brazil_cases_dat$death_inc <- ifelse(is.na(brazil_cases_dat$death_inc), brazil_cases_dat$deaths, brazil_cases_dat$death_inc)


print(paste( "The total number of cases before correction = " , as.character(sum(brazil_cases_dat$case_inc)) ,sep="")) 
print(paste( "The total number of deaths before correction = " , as.character(sum(brazil_cases_dat$death_inc)) ,sep="")) 

### Generate a dataframe with all dates between the start of data collection and today

date.min <- min(brazil_cases_dat$date)
date.max <- max(brazil_cases_dat$date)
all.dates <- seq(date.min, date.max, by="day")

# Convert all dates to a data frame. 
all.dates.frame <- data.frame(list(date=all.dates))
all.dates.frame$merge_col <- "A"

# Merge all cities and dates 
all_cities <- unique(brazil_cases_dat[c("city", "state", "city_ibge_code")])
all_cities$merge_col <- "A"

all_dates_cities <- merge(all.dates.frame,all_cities,by="merge_col")
all_dates_cities <- all_dates_cities[c(2,3,4,5)]

### Merge Municipality data to dates - missing days should be NULL
brazil_cases_dat_fill <- merge(all_dates_cities,brazil_cases_dat,by=c("date","city","state","city_ibge_code"),all.x=TRUE)
### Keep only required data 
brazil_cases_dat_fill <- brazil_cases_dat_fill[(c(1,2,3,4,14,15))]

### Replace NA with 0 in case increment and death increment - where no increrements were reported on a particular day 
brazil_cases_dat_fill$case_inc <- ifelse(is.na(brazil_cases_dat_fill$case_inc), 0, brazil_cases_dat_fill$case_inc)
brazil_cases_dat_fill$death_inc <- ifelse(is.na(brazil_cases_dat_fill$death_inc), 0, brazil_cases_dat_fill$death_inc)
# order data
brazil_cases_dat_fill <- brazil_cases_dat_fill[with(brazil_cases_dat_fill, order(state, city, date)), ]



### For negative values of cases substract from next days value - repeat until all increments >= 0 
i_count =  0 
repeat{ 
  i_count <- i_count + 1 
  print(paste("Case correction cycle #",as.character(i_count)," - Current lowest case increase", as.character(min(brazil_cases_dat_fill$case_inc)) ))  
  ## Create a column of negative increments 
  brazil_cases_dat_fill$neg_case_inc <- ifelse( (brazil_cases_dat_fill$case_inc < 0 ), brazil_cases_dat_fill$case_inc, 0)
  ## Set to case_inc to 0 if negative and on the last day of reporting 
  brazil_cases_dat_fill$case_inc <- ifelse((brazil_cases_dat_fill$case_inc < 0 & brazil_cases_dat_fill$date ==  date.max ), 0, brazil_cases_dat_fill$case_inc)
  ## Create a column where negative increments are one row lower by group
  brazil_cases_dat_fill <- brazil_cases_dat_fill %>%
    group_by(city_ibge_code) %>%
    arrange(date) %>%
    mutate(neg_case_inc_next =  dplyr::lag(neg_case_inc, default = first(neg_case_inc)))
  ## add case_inc to neg_case_inc_next
  brazil_cases_dat_fill$case_inc_corr <- brazil_cases_dat_fill$case_inc + brazil_cases_dat_fill$neg_case_inc_next
  ## Replace previous negative with zero 
  brazil_cases_dat_fill$case_inc_corr  <- ifelse( (brazil_cases_dat_fill$case_inc < 0 ), 0, brazil_cases_dat_fill$case_inc_corr)
  ## Replace case_inc value with case_inc_corr
  brazil_cases_dat_fill <- brazil_cases_dat_fill[c(1,2,3,4,9,6)]
  names(brazil_cases_dat_fill)[5] <- "case_inc"
  if(min(brazil_cases_dat_fill$case_inc)==0) {
    break
  }
} 

print(paste( "The total number of cases after correction = " , as.character(sum(brazil_cases_dat$case_inc)) ,sep="")) 

### For negative values of deaths  substract from next days value - repeat until all increments >= 0 
i_count =  0 
repeat{ 
  i_count <- i_count + 1 
  print(paste("Deaths correction cycle #",as.character(i_count)," - Current lowest deaths increase", as.character(min(brazil_cases_dat_fill$death_inc)) ))  
  ## Create a column of negative increments 
  brazil_cases_dat_fill$neg_death_inc <- ifelse( (brazil_cases_dat_fill$death_inc < 0 ), brazil_cases_dat_fill$death_inc, 0)
  ## Set to case_inc to 0 if negative and on the last day of reporting 
  brazil_cases_dat_fill$death_inc <- ifelse((brazil_cases_dat_fill$death_inc < 0 & brazil_cases_dat_fill$date ==  date.max ), 0, brazil_cases_dat_fill$death_inc)
  ## Create a column where negative increments are one row lower by group
  brazil_cases_dat_fill <- brazil_cases_dat_fill %>%
    group_by(city_ibge_code) %>%
    arrange(date) %>%
    mutate(neg_death_inc_next =  dplyr::lag(neg_death_inc, default = first(neg_death_inc)))
  ## add death_inc to neg_death_inc_next
  brazil_cases_dat_fill$death_inc_corr <- brazil_cases_dat_fill$death_inc + brazil_cases_dat_fill$neg_death_inc_next
  ## Replace previous negative with zero 
  brazil_cases_dat_fill$death_inc_corr  <- ifelse( (brazil_cases_dat_fill$death_inc < 0 ), 0, brazil_cases_dat_fill$death_inc_corr)
  ## Replace case_inc value with case_inc_corr
  brazil_cases_dat_fill <- brazil_cases_dat_fill[c(1,2,3,4,5,9)]
  names(brazil_cases_dat_fill)[6] <- "death_inc"
  if(min(brazil_cases_dat_fill$death_inc)==0) {
    break
  }
} 

print(paste( "The total number of deaths after correction = " , as.character(sum(brazil_cases_dat$death_inc)) ,sep="")) 

### Recalculate cumulative totals
brazil_cases_dat_fill <- mutate(group_by(brazil_cases_dat_fill,city_ibge_code), case_cum=cumsum(case_inc))
brazil_cases_dat_fill <- mutate(group_by(brazil_cases_dat_fill,city_ibge_code), death_cum=cumsum(death_inc))

## Encoding cityt names
brazil_cases_dat_fill$city <- as.character(brazil_cases_dat_fill$city)
Encoding(brazil_cases_dat_fill$city) <- "UTF-8"

### Keep only cumulative totals
brazil_cases_dat_fill <- brazil_cases_dat_fill[c(1,2,3,4,7,8)]

### get data in the format date(yyyy-mm-dd),Area_Name,State,confirmed,city_ibge_code for cases data.frame
### get data in the format date(yyyy-mm-dd),Area_Name,State,deaths,city_ibge_code for deaths data.frame

names(brazil_cases_dat_fill)[1] <- "date"
names(brazil_cases_dat_fill)[2] <- "Area_Name"
names(brazil_cases_dat_fill)[3] <- "State"
names(brazil_cases_dat_fill)[4] <- "City_ibge_code"
names(brazil_cases_dat_fill)[5] <- "cases"
names(brazil_cases_dat_fill)[6] <- "deaths"

## Getting case data in right format

brazil_cases_dat <- dcast(brazil_cases_dat_fill, brazil_cases_dat_fill$State + brazil_cases_dat_fill$Area_Name + 
                            brazil_cases_dat_fill$City_ibge_code~brazil_cases_dat_fill$date, value.var = "cases")

## substrings of column names to get correct data format from yyyy-mm-dd to Xdd_mm_yyyy
names(brazil_cases_dat)[4:ncol(brazil_cases_dat)] <- paste("X",substring(names(brazil_cases_dat)[4:ncol(brazil_cases_dat)],9,10),"_",
                                                           substring(names(brazil_cases_dat)[4:ncol(brazil_cases_dat)],6,7),"_",
                                                           substring(names(brazil_cases_dat)[4:ncol(brazil_cases_dat)],1,4),sep="")
## Replace NA with 0
brazil_cases_dat[is.na(brazil_cases_dat)] <- 0


## Subset for output
brazil_cases_dat_output <- brazil_cases_dat[c(2,1,4:ncol(brazil_cases_dat),3)]
names(brazil_cases_dat_output)[1] <- "Area_Name"
names(brazil_cases_dat_output)[2] <- "State"
names(brazil_cases_dat_output)[ncol(brazil_cases_dat_output)] <- "City_ibge_code"
# IBGE code as number for back compatibility
brazil_cases_dat_output$City_ibge_code <- as.numeric(as.character(brazil_cases_dat_output$City_ibge_code))

fname <- paste0(dir_formatted_case_data,"brazil_daily_cases_ibge_api_", today,".csv")
fname_RDS <- paste0(dir_formatted_case_data,"brazil_daily_cases_ibge_api_", today,".RDS")

write.csv(brazil_cases_dat_output,file = fname,row.names=FALSE)
### Saving as RDS file
saveRDS(brazil_cases_dat_output, file = fname_RDS) 


## For testing get top 50 rows 
# brazil_cases_dat_output_head <- brazil_cases_dat_output[1:50,]
# write.csv(brazil_cases_dat_output_head,file = fname,row.names=FALSE)
# saveRDS(brazil_cases_dat_output_head, file = fname_RDS)
 
# ################
# ### Deaths data 
# ################
## Getting death data in right format

brazil_deaths_dat <- dcast(brazil_cases_dat_fill, brazil_cases_dat_fill$State + brazil_cases_dat_fill$Area_Name + 
                            brazil_cases_dat_fill$City_ibge_code~brazil_cases_dat_fill$date, value.var = "deaths")

## substrings of column names to get correct data format from yyyy-mm-dd to Xdd_mm_yyyy
names(brazil_deaths_dat)[4:ncol(brazil_deaths_dat)] <- paste("X",substring(names(brazil_deaths_dat)[4:ncol(brazil_deaths_dat)],9,10),"_",
                                                           substring(names(brazil_deaths_dat)[4:ncol(brazil_deaths_dat)],6,7),"_",
                                                           substring(names(brazil_deaths_dat)[4:ncol(brazil_deaths_dat)],1,4),sep="")
## Replace NA with 0
brazil_deaths_dat[is.na(brazil_deaths_dat)] <- 0


## Subset for output
brazil_deaths_dat_output <- brazil_deaths_dat[c(2,1,4:ncol(brazil_cases_dat),3)]
names(brazil_deaths_dat_output)[1] <- "Area_Name"
names(brazil_deaths_dat_output)[2] <- "State"
names(brazil_deaths_dat_output)[ncol(brazil_deaths_dat_output)] <- "City_ibge_code"
# IBGE code as number for back compatibility
brazil_deaths_dat_output$City_ibge_code <- as.numeric(as.character(brazil_deaths_dat_output$City_ibge_code))

fname <- paste0(dir_formatted_death_data,"brazil_daily_deaths_ibge_api_", today,".csv")
fname_RDS <- paste0(dir_formatted_death_data,"brazil_daily_deaths_ibge_api_", today,".RDS")
write.csv(brazil_deaths_dat_output,file = fname,row.names=FALSE)
### Saving as RDS file
saveRDS(brazil_deaths_dat_output, file = fname_RDS) 

## For testing get top 50 rows 
# brazil_deaths_dat_output_head <- brazil_deaths_dat_output[1:50,]
# write.csv(brazil_deaths_dat_output_head,file = fname,row.names=FALSE)
# saveRDS(brazil_deaths_dat_output_head, file = fname_RDS)

