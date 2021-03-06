#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Title: waterLevel 
#Coder: Matt shockey (mshockey97@gmail.com)
#Date: 6/3/2020
#Purpose: Re-analysis of water level data downloaded March 2019
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#Table of Contents~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Step 1: Organize workspace
# Step 2: Field Worksheet
# Step 3: Baro Data
# Step 4: Water Depth
# Step 5: QAQC
# Step 6: Print

#Log Notes~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Step 1: Setup workspace-------------------------------------------------------
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#Clear workspace 
remove(list=ls())

#Gather libraries of interest
library(xts)
library(dygraphs)
library(lubridate)
library(tidyverse)

#Read custom R functions
source("R/download_fun.R")
source("R/check_fun.R")
source("R/dygraph_ts_fun.R")
source("R/dygraph_QAQC_fun.R")

#Define data directory
data_dir<-"data//202102//export//"

#list pt and baor file locations
pt_files<-list.files(paste0(data_dir), full.names =  TRUE) %>% 
  as_tibble() %>% 
  filter(!str_detect(value, 'offset')) %>% 
  filter(!str_detect(value, 'well_log.csv')) %>%
  filter(!str_detect(value, '.log')) %>% 
  filter(!str_detect(value, '.bar')) %>% 
  filter(!str_detect(value, '.xlsx')) %>% 
  as_vector()
baro_files<-pt_files[str_detect(pt_files, "baro")]
field_files<-paste0(data_dir, 'well_log.csv')
#offset<-read_csv(paste0(data_dir, 'offset.csv'))

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Step 2: Field Worksheet--------------------------------------------------------
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Download Field Worksheet
field_log<-read_csv(field_files)

#Check to make sure pt files match field logs
check_fun(pt_files,field_log)
#If final 

#create df of site name, sonde_id, and measured offset
field_log<-field_log %>% 
  select(Site_Name, Sonde_ID, Relative_Water_Level_m)

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Step 3: Barometric Pressure Data----------------------------------------------
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Read baro data (from ncdc station)
baro<-read_csv(paste0(data_dir, "ncdc_baro.csv"))

#process ncdc baro data
baro<-baro %>% 
  select(Timestamp = DATE, 
         pressureAtmosphere = HourlyStationPressure) %>% 
  #Convert in_Hg to kpa
  mutate(pressureAbsolute = pressureAtmosphere*3.38639) %>% 
  drop_na()

#Plot to check for any issues
baro %>% select(Timestamp, pressureAbsolute) %>%  dygraph_ts_fun()
  
#create interp functions
baro_fun<-approxfun(baro$Timestamp, baro$pressureAbsolute)

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Step 4: WaterDepth Data-------------------------------------------------------
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Gather PT data
df<-lapply(pt_files, download_fun) %>% bind_rows()

#Joint to df
df<-df %>% left_join(., field_log) 

#Assign baro pressure
df<-df %>% 
  #Add baro key data
  left_join(., baro_key) %>% 
  #Interpolate barometric pressure from loggers
  mutate(pressureBaro = palmer_baro_fun(Timestamp)) %>% 
  #Clean up
  select(Site_Name, Timestamp, pressureAbsolute, pressureBaro)

#Estimate waterHeight
df<-df %>% 
  mutate(pressureGauge = pressureAbsolute-pressureBaro, 
         waterHeight   = pressureGauge/9.81)

#Joint to df
df<-df %>% left_join(., offset) 

#Estimate waterdepth
df<-df %>% mutate(waterDepth = waterHeight + offset)

#Subset to waterDepth (after inspection!)
df<-df %>% select(Timestamp, Site_Name, waterDepth) 

#Add prcessing level
df$processing_level<-"raw"

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Step 5: QAQC------------------------------------------------------------------
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#list site names
field_log %>% select(Site_Name) %>% arrange(Site_Name) %>% pull()

#previously downloaded data
h_record<-read_csv("C:\\Users\\cnjones7\\Box Sync\\My Folders\\Research Projects\\SWI\\PT_Data\\20190709_Downloads\\20190709_waterLevel.csv")

# #5.1 BN-A-----------------------------------------------------------------------
# #Organize data~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
site<-"BN-A"
waterDepth <- df %>% filter(Site_Name==site)
historic<-h_record %>% filter(Site_Name==site)
dygraph_QAQC_fun(waterDepth, historic)
# 
#Manual Edits~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Add offset to match historic
updated<-waterDepth %>%
  mutate(waterDepth = waterDepth - 0.098)

#remove weird periods
updated<-updated %>%
  filter(waterDepth > -1.5)

#Add rolling average
updated<-updated %>%
  mutate(waterDepth = rollmean(waterDepth, k=5, fill=NA))

#interpolate between weird periods
interpfun<-approxfun(updated$Timestamp, updated$waterDepth)
updated<-tibble(
  Timestamp = waterDepth$Timestamp,
  waterDepth = interpfun(waterDepth$Timestamp))

#Inspect output
dygraph_QAQC_fun(waterDepth, historic, updated)

#print~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Add info to 'updated' dataframe
updated$Site_Name = site
updated$processing_level = 'processed'

#Append master dataframe
df<-bind_rows(df, updated)

# #5.2 BN-B-----------------------------------------------------------------------
# #Organize data~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
site<-"BN-B"
waterDepth <- df %>% filter(Site_Name==site)
historic<-h_record %>% filter(Site_Name==site)
dygraph_QAQC_fun(waterDepth, historic)
# 
#Manual Edits~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Add offset to match historic
updated<-waterDepth %>%
  mutate(waterDepth = waterDepth -0.098)

#remove weird periods
updated<-updated %>%
  filter(waterDepth > -1.5)

#Add rolling average
updated<-updated %>%
  mutate(waterDepth = rollmean(waterDepth, k=5, fill=NA))

#interpolate between weird periods
interpfun<-approxfun(updated$Timestamp, updated$waterDepth)
updated<-tibble(
  Timestamp = waterDepth$Timestamp,
  waterDepth = interpfun(waterDepth$Timestamp))

#Inspect output
dygraph_QAQC_fun(waterDepth, historic, updated)

#print~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Add info to 'updated' dataframe
updated$Site_Name = site
updated$processing_level = 'processed'

#Append master dataframe
df<-bind_rows(df, updated)

# #5.3 BN-C-----------------------------------------------------------------------
# #Organize data~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
site<-"BN-C"
waterDepth <- df %>% filter(Site_Name==site)
historic<-h_record %>% filter(Site_Name==site)
dygraph_QAQC_fun(waterDepth, historic)
# 
#Manual Edits~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Add offset to match historic
updated<-waterDepth %>%
  mutate(waterDepth = waterDepth -0.098)

#Add rolling average
updated<-updated %>%
  mutate(waterDepth = rollmean(waterDepth, k=5, fill=NA))

#interpolate between weird periods
interpfun<-approxfun(updated$Timestamp, updated$waterDepth)
updated<-tibble(
  Timestamp = waterDepth$Timestamp,
  waterDepth = interpfun(waterDepth$Timestamp))

#Inspect output
dygraph_QAQC_fun(waterDepth, historic, updated)

#print~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Add info to 'updated' dataframe
updated$Site_Name = site
updated$processing_level = 'processed'

#Append master dataframe
df<-bind_rows(df, updated)
# #5.4 BN-D-----------------------------------------------------------------------
# #Organize data~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
site<-"BN-D"
waterDepth <- df %>% filter(Site_Name==site)
historic<-h_record %>% filter(Site_Name==site)
dygraph_QAQC_fun(waterDepth, historic)
# 
#Manual Edits~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Add offset to match historic
updated<-waterDepth %>%
  mutate(waterDepth = waterDepth -0.098 )

#Add rolling average
updated<-updated %>%
  mutate(waterDepth = rollmean(waterDepth, k=5, fill=NA))

#interpolate between weird periods
interpfun<-approxfun(updated$Timestamp, updated$waterDepth)
updated<-tibble(
  Timestamp = waterDepth$Timestamp,
  waterDepth = interpfun(waterDepth$Timestamp))

#Inspect output
dygraph_QAQC_fun(waterDepth, historic, updated)

#print~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Add info to 'updated' dataframe
updated$Site_Name = site
updated$processing_level = 'processed'

#Append master dataframe
df<-bind_rows(df, updated)

#5.5 AL-A-----------------------------------------------------------------------
# #Organize data~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
site<-"AL-A"
waterDepth <- df %>% filter(Site_Name==site)
historic<-h_record %>% filter(Site_Name==site)
dygraph_QAQC_fun(waterDepth, historic)
# 
#Manual Edits~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Add offset to match historic
updated<-waterDepth %>%
  mutate(waterDepth = waterDepth -0.082 )

#remove weird periods
updated<-updated %>%
  filter(waterDepth > -1)

#Add rolling average
updated<-updated %>%
  mutate(waterDepth = rollmean(waterDepth, k=5, fill=NA))

#interpolate between weird periods
interpfun<-approxfun(updated$Timestamp, updated$waterDepth)
updated<-tibble(
  Timestamp = waterDepth$Timestamp,
  waterDepth = interpfun(waterDepth$Timestamp))

#Inspect output
dygraph_QAQC_fun(waterDepth, historic, updated)

#print~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Add info to 'updated' dataframe
updated$Site_Name = site
updated$processing_level = 'processed'

#Append master dataframe
df<-bind_rows(df, updated)

#5.6 AL-B-----------------------------------------------------------------------
# #Organize data~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
site<-"AL-B"
waterDepth <- df %>% filter(Site_Name==site)
historic<-h_record %>% filter(Site_Name==site)
dygraph_QAQC_fun(waterDepth, historic)
# 
#Manual Edits~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Add offset to match historic
updated<-waterDepth %>%
  mutate(waterDepth = waterDepth -0.082 )

#Add rolling average
updated<-updated %>%
  mutate(waterDepth = rollmean(waterDepth, k=5, fill=NA))

#interpolate between weird periods
interpfun<-approxfun(updated$Timestamp, updated$waterDepth)
updated<-tibble(
  Timestamp = waterDepth$Timestamp,
  waterDepth = interpfun(waterDepth$Timestamp))

#Inspect output
dygraph_QAQC_fun(waterDepth, historic, updated)

#print~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Add info to 'updated' dataframe
updated$Site_Name = site
updated$processing_level = 'processed'

#Append master dataframe
df<-bind_rows(df, updated)

#5.7 AL-C-----------------------------------------------------------------------
# #Organize data~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
site<-"AL-C"
waterDepth <- df %>% filter(Site_Name==site)
historic<-h_record %>% filter(Site_Name==site)
dygraph_QAQC_fun(waterDepth, historic)
# 
#Manual Edits~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Add offset to match historic
updated<-waterDepth %>%
  mutate(waterDepth = waterDepth-0.082 )

#remove weird periods
updated<-updated %>%
  filter(waterDepth > -1.5)

#Add rolling average
updated<-updated %>%
  mutate(waterDepth = rollmean(waterDepth, k=5, fill=NA))

#interpolate between weird periods
interpfun<-approxfun(updated$Timestamp, updated$waterDepth)
updated<-tibble(
  Timestamp = waterDepth$Timestamp,
  waterDepth = interpfun(waterDepth$Timestamp))

#Inspect output
dygraph_QAQC_fun(waterDepth, historic, updated)

#print~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Add info to 'updated' dataframe
updated$Site_Name = site
updated$processing_level = 'processed'

#Append master dataframe
df<-bind_rows(df, updated)

#5.8 AL-D-----------------------------------------------------------------------
# #Organize data~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
site<-"AL-D"
waterDepth <- df %>% filter(Site_Name==site)
historic<-h_record %>% filter(Site_Name==site)
dygraph_QAQC_fun(waterDepth, historic)
# 
#Manual Edits~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Add offset to match historic
updated<-waterDepth %>%
  mutate(waterDepth = waterDepth-0.175)

#remove weird periods
updated<-updated %>%
  filter(waterDepth > -1.5)

#Add rolling average
updated<-updated %>%
  mutate(waterDepth = rollmean(waterDepth, k=5, fill=NA))

#interpolate between weird periods
interpfun<-approxfun(updated$Timestamp, updated$waterDepth)
updated<-tibble(
  Timestamp = waterDepth$Timestamp,
  waterDepth = interpfun(waterDepth$Timestamp))

#Inspect output
dygraph_QAQC_fun(waterDepth, historic, updated)

#print~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Add info to 'updated' dataframe
updated$Site_Name = site
updated$processing_level = 'processed'

#Append master dataframe
df<-bind_rows(df, updated)

#5.9 EP-A-----------------------------------------------------------------------
# #Organize data~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
site<-"EP-A"
waterDepth <- df %>% filter(Site_Name==site)
historic<-h_record %>% filter(Site_Name==site)
dygraph_QAQC_fun(waterDepth, historic)
# 
#Manual Edits~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Add offset to match historic
updated<-waterDepth %>%
  mutate(waterDepth = waterDepth-0.085)

#remove weird periods
# updated<-updated %>%
#   filter(waterDepth > -1.5)

#Add rolling average
updated<-updated %>%
  mutate(waterDepth = rollmean(waterDepth, k=5, fill=NA))

#interpolate between weird periods
interpfun<-approxfun(updated$Timestamp, updated$waterDepth)
updated<-tibble(
  Timestamp = waterDepth$Timestamp,
  waterDepth = interpfun(waterDepth$Timestamp))

#Inspect output
dygraph_QAQC_fun(waterDepth, historic, updated)

#print~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Add info to 'updated' dataframe
updated$Site_Name = site
updated$processing_level = 'processed'

#Append master dataframe
df<-bind_rows(df, updated)

#5.10 EP-B-----------------------------------------------------------------------
# #Organize data~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
site<-"EP-B"
waterDepth <- df %>% filter(Site_Name==site)
historic<-h_record %>% filter(Site_Name==site)
dygraph_QAQC_fun(waterDepth, historic)
# 
#Manual Edits~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Add offset to match historic
updated<-waterDepth %>%
  mutate(waterDepth = waterDepth-0.085)

#remove weird periods
# updated<-updated %>%
#   filter(waterDepth > -1.5)

#Add rolling average
updated<-updated %>%
  mutate(waterDepth = rollmean(waterDepth, k=5, fill=NA))

#interpolate between weird periods
interpfun<-approxfun(updated$Timestamp, updated$waterDepth)
updated<-tibble(
  Timestamp = waterDepth$Timestamp,
  waterDepth = interpfun(waterDepth$Timestamp))

#Inspect output
dygraph_QAQC_fun(waterDepth, historic, updated)

#print~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Add info to 'updated' dataframe
updated$Site_Name = site
updated$processing_level = 'processed'

#Append master dataframe
df<-bind_rows(df, updated)

#5.11 EP-C-----------------------------------------------------------------------
# #Organize data~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
site<-"EP-C"
waterDepth <- df %>% filter(Site_Name==site)
historic<-h_record %>% filter(Site_Name==site)
dygraph_QAQC_fun(waterDepth, historic)
# 
#Manual Edits~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Add offset to match historic
updated<-waterDepth %>%
  mutate(waterDepth = waterDepth-0.085)

#remove weird periods
# updated<-updated %>%
#   filter(waterDepth > -1.5)

#Add rolling average
updated<-updated %>%
  mutate(waterDepth = rollmean(waterDepth, k=5, fill=NA))

#interpolate between weird periods
interpfun<-approxfun(updated$Timestamp, updated$waterDepth)
updated<-tibble(
  Timestamp = waterDepth$Timestamp,
  waterDepth = interpfun(waterDepth$Timestamp))

#Inspect output
dygraph_QAQC_fun(waterDepth, historic, updated)

#print~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Add info to 'updated' dataframe
updated$Site_Name = site
updated$processing_level = 'processed'

#Append master dataframe
df<-bind_rows(df, updated)

#5.12 GR-A ---------------------------------------------------------------------
#Organize data~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
site<-"GR-A"
waterDepth <- df %>% filter(Site_Name==site)
historic<-h_record %>% filter(Site_Name==site)
dygraph_QAQC_fun(waterDepth, historic)
# 
#Manual Edits~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Add offset to match historic
updated<-waterDepth %>%
  mutate(waterDepth = waterDepth-0.093)

#remove weird periods
updated<-updated %>%
  filter(waterDepth > -1.5)

#Add rolling average
updated<-updated %>%
  mutate(waterDepth = rollmean(waterDepth, k=5, fill=NA))

#interpolate between weird periods
interpfun<-approxfun(updated$Timestamp, updated$waterDepth)
updated<-tibble(
  Timestamp = waterDepth$Timestamp,
  waterDepth = interpfun(waterDepth$Timestamp))

#Inspect output
dygraph_QAQC_fun(waterDepth, historic, updated)

#print~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Add info to 'updated' dataframe
updated$Site_Name = site
updated$processing_level = 'processed'

#Append master dataframe
df<-bind_rows(df, updated)

#5.13 GR-B ---------------------------------------------------------------------
#Organize data~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
site<-"GR-B"
waterDepth <- df %>% filter(Site_Name==site)
historic<-h_record %>% filter(Site_Name==site)
dygraph_QAQC_fun(waterDepth, historic)
# 
#Manual Edits~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Add offset to match historic
updated<-waterDepth %>%
  mutate(waterDepth = waterDepth)

#remove weird periods
# updated<-updated %>%
#   filter(waterDepth > -1.5)

#Add rolling average
updated<-updated %>%
  mutate(waterDepth = rollmean(waterDepth, k=8, fill=NA))

#interpolate between weird periods
interpfun<-approxfun(updated$Timestamp, updated$waterDepth)
updated<-tibble(
  Timestamp = waterDepth$Timestamp,
  waterDepth = interpfun(waterDepth$Timestamp))

#Inspect output
dygraph_QAQC_fun(waterDepth, historic, updated)

#print~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Add info to 'updated' dataframe
updated$Site_Name = site
updated$processing_level = 'processed'

#Append master dataframe
df<-bind_rows(df, updated)

#5.14 GR-C ---------------------------------------------------------------------
#Organize data~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
site<-"GR-C"
waterDepth <- df %>% filter(Site_Name==site)
historic<-h_record %>% filter(Site_Name==site)
dygraph_QAQC_fun(waterDepth, historic)
# 
#Manual Edits~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Add offset to match historic
updated<-waterDepth %>%
  mutate(waterDepth = waterDepth)

#remove weird periods
updated<-updated %>%
  filter(waterDepth > -1.5)

#Add rolling average
updated<-updated %>%
  mutate(waterDepth = rollmean(waterDepth, k=8, fill=NA))

#interpolate between weird periods
interpfun<-approxfun(updated$Timestamp, updated$waterDepth)
updated<-tibble(
  Timestamp = waterDepth$Timestamp,
  waterDepth = interpfun(waterDepth$Timestamp))

#Inspect output
dygraph_QAQC_fun(waterDepth, historic, updated)

#print~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Add info to 'updated' dataframe
updated$Site_Name = site
updated$processing_level = 'processed'

#Append master dataframe
df<-bind_rows(df, updated)

#5.14 GR-D ---------------------------------------------------------------------
#Organize data~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
site<-"GR-D"
waterDepth <- df %>% filter(Site_Name==site)
historic<-h_record %>% filter(Site_Name==site)
dygraph_QAQC_fun(waterDepth, historic)
# 
#Manual Edits~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Add offset to match historic
updated<-waterDepth %>%
  mutate(waterDepth = waterDepth-0.085)

#remove weird periods
updated<-updated %>%
  filter(waterDepth > -1.5)

#Add rolling average
updated<-updated %>%
  mutate(waterDepth = rollmean(waterDepth, k=8, fill=NA))

#interpolate between weird periods
interpfun<-approxfun(updated$Timestamp, updated$waterDepth)
updated<-tibble(
  Timestamp = waterDepth$Timestamp,
  waterDepth = interpfun(waterDepth$Timestamp))

#Inspect output
dygraph_QAQC_fun(waterDepth, historic, updated)

#print~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Add info to 'updated' dataframe
updated$Site_Name = site
updated$processing_level = 'processed'

#Append master dataframe
df<-bind_rows(df, updated)

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Step 6: Print-----------------------------------------------------------------
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
df<-df %>%
  select(Timestamp, Site_Name, waterDepth, processing_level) %>%
  filter(processing_level == 'processed') %>%
  select(-processing_level)
write_csv(df, paste0(data_dir,"20190912_waterLevel.csv"))

