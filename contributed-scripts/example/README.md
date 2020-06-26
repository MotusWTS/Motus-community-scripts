Example contributed script - create encounter histories from Motus
detection data
================
Amie MacDonald (<amacdonald@birdscanada.org>)
2020-06-23

## Overview

Arrange Motus detection data into encounter histories that can be used
in mark-recapture modelling with this code. Transform the detection data
into a dataframe where columns represent time intervals and each row is
an individual. The entries in each cell represent whether an individual
was detected by a Motus station during that time interval in a
single-state or multi-state framework.

## Setup

Load packages:

``` r
library(tidyverse)
library(lubridate)

# set timezone
Sys.setenv(TZ = "UTC")
```

### Load sample dataset

Use the sample dataset from project 176, restricted to just Semipalmated
Sandpipers. This dataset is saved as an RDS file in same folder as this
script.

``` r
df.alltags <- readRDS("sample_data.rds")
```

|    hitID |  runID | batchID | ts                  | tsCorrected | sig | sigsd | noise | freq | freqsd |  slop | burstSlop | done | motusTagID | ambigID | port | runLen | bootnum | tagProjID | mfgID | tagType | codeSet | mfg   | tagModel | tagLifespan | nomFreq |  tagBI | pulseLen | tagDeployID | speciesID | markerNumber | markerType | tagDeployStart | tagDeployEnd | tagDepLat | tagDepLon | tagDepAlt | tagDepComments                                                                                                                                                                                              | fullID                                | deviceID | recvDeployID | recvDeployLat | recvDeployLon | recvDeployAlt | recv      | recvDeployName | recvSiteName | isRecvMobile | recvProjID | recvUtcOffset | antType | antBearing | antHeight | speciesEN              | speciesFR           | speciesSci       | speciesGroup | tagProjName | recvProjName | gpsLat | gpsLon | gpsAlt |
| -------: | -----: | ------: | :------------------ | ----------: | --: | ----: | ----: | ---: | -----: | ----: | --------: | ---: | ---------: | ------: | :--- | -----: | ------: | --------: | :---- | :------ | :------ | :---- | :------- | ----------: | ------: | -----: | -------: | ----------: | --------: | :----------- | :--------- | -------------: | -----------: | --------: | --------: | --------: | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------ | -------: | -----------: | ------------: | ------------: | ------------: | :-------- | :------------- | :----------- | -----------: | ---------: | ------------: | :------ | ---------: | --------: | :--------------------- | :------------------ | :--------------- | :----------- | :---------- | :----------- | :----- | :----- | :----- |
| 10873049 | 540466 |     628 | 2015-08-17 17:01:38 |  1439830898 | 119 |     0 |  \-96 |    4 |      0 | 1e-04 |    0.0000 |    0 |      16037 |      NA | \-48 |     11 |      68 |       176 | 179   | ID      | Lotek4  | Lotek | NTQB-3-2 |          NA |  166.38 | 6.0962 |      2.5 |        1825 |      4690 | 246107870    | metal band |     1439807400 |   1451644200 |   51.4839 |   \-80.45 |        NA | {“ageID”:“HY”,“bill”:18.2,“blood”:“Y”,“country”:“Canada”,“culmen”:18.2,“fatScore”:2,“locationID”:“NorthPoint\_net1”,“province”:“Ontario”,“sexID”:“U”,“tarsus”:22.3,“weight”:21.5,“wing”:94,“comments”:null} | SampleData\#179:<6.1@166.38>(M.16037) |      528 |         3813 |            NA |            NA |            NA | Lotek-280 | NP mobile      | NA           |            1 |        176 |            NA | NA      |         NA |        NA | Semipalmated Sandpiper | Bécasseau semipalmé | Calidris pusilla | BIRDS        | SampleData  | SampleData   | NA     | NA     | NA     |
| 10873050 | 540466 |     628 | 2015-08-17 17:01:44 |  1439830905 | 128 |     0 |  \-96 |    4 |      0 | 2e-04 |  \-0.0012 |    0 |      16037 |      NA | \-48 |     11 |      68 |       176 | 179   | ID      | Lotek4  | Lotek | NTQB-3-2 |          NA |  166.38 | 6.0962 |      2.5 |        1825 |      4690 | 246107870    | metal band |     1439807400 |   1451644200 |   51.4839 |   \-80.45 |        NA | {“ageID”:“HY”,“bill”:18.2,“blood”:“Y”,“country”:“Canada”,“culmen”:18.2,“fatScore”:2,“locationID”:“NorthPoint\_net1”,“province”:“Ontario”,“sexID”:“U”,“tarsus”:22.3,“weight”:21.5,“wing”:94,“comments”:null} | SampleData\#179:<6.1@166.38>(M.16037) |      528 |         3813 |            NA |            NA |            NA | Lotek-280 | NP mobile      | NA           |            1 |        176 |            NA | NA      |         NA |        NA | Semipalmated Sandpiper | Bécasseau semipalmé | Calidris pusilla | BIRDS        | SampleData  | SampleData   | NA     | NA     | NA     |
| 10873053 | 540468 |     628 | 2015-08-17 17:01:41 |  1439830901 |  69 |     0 |  \-96 |    4 |      0 | 1e-04 |    0.0000 |    0 |      16038 |      NA | \-48 |      8 |      68 |       176 | 180   | ID      | Lotek4  | Lotek | NTQB-3-2 |          NA |  166.38 | 6.0961 |      2.5 |        1826 |      4690 | 246107869    | metal band |     1439807400 |   1451644200 |   51.4839 |   \-80.45 |        NA | {“ageID”:“HY”,“bill”:19,“blood”:“Y”,“country”:“Canada”,“culmen”:19,“fatScore”:3,“locationID”:“NorthPoint\_net1”,“province”:“Ontario”,“sexID”:“U”,“tarsus”:22.2,“weight”:24.4,“wing”:97,“comments”:null}     | SampleData\#180:<6.1@166.38>(M.16038) |      528 |         3813 |            NA |            NA |            NA | Lotek-280 | NP mobile      | NA           |            1 |        176 |            NA | NA      |         NA |        NA | Semipalmated Sandpiper | Bécasseau semipalmé | Calidris pusilla | BIRDS        | SampleData  | SampleData   | NA     | NA     | NA     |
| 10873054 | 540468 |     628 | 2015-08-17 17:01:47 |  1439830907 |  63 |     0 |  \-96 |    4 |      0 | 1e-04 |    0.0028 |    0 |      16038 |      NA | \-48 |      8 |      68 |       176 | 180   | ID      | Lotek4  | Lotek | NTQB-3-2 |          NA |  166.38 | 6.0961 |      2.5 |        1826 |      4690 | 246107869    | metal band |     1439807400 |   1451644200 |   51.4839 |   \-80.45 |        NA | {“ageID”:“HY”,“bill”:19,“blood”:“Y”,“country”:“Canada”,“culmen”:19,“fatScore”:3,“locationID”:“NorthPoint\_net1”,“province”:“Ontario”,“sexID”:“U”,“tarsus”:22.2,“weight”:24.4,“wing”:97,“comments”:null}     | SampleData\#180:<6.1@166.38>(M.16038) |      528 |         3813 |            NA |            NA |            NA | Lotek-280 | NP mobile      | NA           |            1 |        176 |            NA | NA      |         NA |        NA | Semipalmated Sandpiper | Bécasseau semipalmé | Calidris pusilla | BIRDS        | SampleData  | SampleData   | NA     | NA     | NA     |
| 10873055 | 540466 |     628 | 2015-08-17 17:01:50 |  1439830911 | 130 |     0 |  \-96 |    4 |      0 | 1e-04 |  \-0.0013 |    0 |      16037 |      NA | \-48 |     11 |      68 |       176 | 179   | ID      | Lotek4  | Lotek | NTQB-3-2 |          NA |  166.38 | 6.0962 |      2.5 |        1825 |      4690 | 246107870    | metal band |     1439807400 |   1451644200 |   51.4839 |   \-80.45 |        NA | {“ageID”:“HY”,“bill”:18.2,“blood”:“Y”,“country”:“Canada”,“culmen”:18.2,“fatScore”:2,“locationID”:“NorthPoint\_net1”,“province”:“Ontario”,“sexID”:“U”,“tarsus”:22.3,“weight”:21.5,“wing”:94,“comments”:null} | SampleData\#179:<6.1@166.38>(M.16037) |      528 |         3813 |            NA |            NA |            NA | Lotek-280 | NP mobile      | NA           |            1 |        176 |            NA | NA      |         NA |        NA | Semipalmated Sandpiper | Bécasseau semipalmé | Calidris pusilla | BIRDS        | SampleData  | SampleData   | NA     | NA     | NA     |

## Transform detection data into encounter histories

### Single-state framework

This example uses daily time intervals and restricts the study period to
August and September 2015. Each Semipalmated Sandpiper receives a `1`
for days it was detected by a Motus station and a `0` for days where it
was not detected. In case there are days where no birds were detected, a
fake tag is created that was detected everyday. Then the dataframe is
pivoteda and the fake tag is removed.

``` r
det.data <- df.alltags %>% 
  select(motusTagID, ts) %>% # keep only the tag ID and the timestamp of the detection
  mutate(ts = date(ts)) %>% # keep only the date of the timestamp, not the time of day
  mutate(detect = 1) %>% # create a new column called detect and fill with 1 for each detection
  filter(ts < "2015-10-01") %>% # remove all data in October and after
  distinct() # remove duplicates (birds detected multiple times in the same day)

min(det.data$ts) # find the earliest detection
```

    ## [1] "2015-08-03"

``` r
ts <- seq(ymd("2015-08-03"), ymd("2015-09-30"), by = "days") # create a sequence of all dates from the first 
                                                             # detection to the end of September

fake.df <- data.frame(ts) %>% # create a fake tag that was detected (with a false code) on all days
  mutate(motusTagID = 99999) %>% 
  mutate(detect = 99999)

det.data.for.eh <- bind_rows(det.data, fake.df) %>% # add the fake tag to the real detection data
  arrange(ts)
```

| motusTagID | ts         | detect |
| ---------: | :--------- | -----: |
|      16011 | 2015-08-03 |      1 |
|      99999 | 2015-08-03 |  99999 |
|      16011 | 2015-08-04 |      1 |
|      99999 | 2015-08-04 |  99999 |
|      16011 | 2015-08-05 |      1 |

``` r
enc.hist <- det.data.for.eh %>% # create the encounter history
  tidyr::pivot_wider(id_cols = motusTagID, names_from = ts, values_from = detect, # transform the data
                     values_fill = list(detect = 0)) %>%                          # fill all empty cells with 0
  filter(!motusTagID == 99999) %>% # remove fake tag
  arrange(motusTagID)
```

| motusTagID | 2015-08-03 | 2015-08-04 | 2015-08-05 | 2015-08-06 | 2015-08-07 | 2015-08-08 | 2015-08-09 | 2015-08-10 | 2015-08-11 | 2015-08-12 | 2015-08-13 | 2015-08-14 | 2015-08-15 | 2015-08-16 | 2015-08-17 | 2015-08-18 | 2015-08-19 | 2015-08-20 | 2015-08-21 | 2015-08-22 | 2015-08-23 | 2015-08-24 | 2015-08-25 | 2015-08-26 | 2015-08-27 | 2015-08-28 | 2015-08-29 | 2015-08-30 | 2015-08-31 | 2015-09-01 | 2015-09-02 | 2015-09-03 | 2015-09-04 | 2015-09-05 | 2015-09-06 | 2015-09-07 | 2015-09-08 | 2015-09-09 | 2015-09-10 | 2015-09-11 | 2015-09-12 | 2015-09-13 | 2015-09-14 | 2015-09-15 | 2015-09-16 | 2015-09-17 | 2015-09-18 | 2015-09-19 | 2015-09-20 | 2015-09-21 | 2015-09-22 | 2015-09-23 | 2015-09-24 | 2015-09-25 | 2015-09-26 | 2015-09-27 | 2015-09-28 | 2015-09-29 | 2015-09-30 |
| ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: |
|      16011 |          1 |          1 |          1 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          1 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          1 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |
|      16035 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          1 |          0 |          0 |          1 |          1 |          1 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          1 |          1 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |
|      16036 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          1 |          1 |          1 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |
|      16037 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          1 |          0 |          0 |          0 |          0 |          0 |          1 |          0 |          1 |          0 |          1 |          1 |          0 |          1 |          1 |          1 |          1 |          1 |          1 |          1 |          1 |          1 |          1 |          0 |          0 |          0 |          0 |          1 |          1 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |
|      16038 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          1 |          0 |          0 |          1 |          1 |          1 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |

### Multi-state framework

Create encounter histories where each location receives a different
number in the encounter history (detection at site 1 is `1`, detection
at site 2 is `2`, and no detection remains `0`). The process is the same
as above, except the Motus station name is kept and assigned a number.
In this example only the two stations in James Bay are kept.

``` r
det.data <- df.alltags %>% 
  select(motusTagID, ts, recvDeployName) %>% # keep tag ID, timestamp, and receiver name
  mutate(ts = date(ts)) %>% # keep date but not time
  filter(recvDeployName %in% c("Netitishi", "North Bluff")) %>% # keep only receivers in James Bay
  distinct() # remove duplicates

min(det.data$ts) # find first detection
```

    ## [1] "2015-08-03"

``` r
max(det.data$ts) # find last detection
```

    ## [1] "2015-09-08"

``` r
ts <- seq(ymd("2015-08-03"), ymd("2015-09-08"), by = "days") # create a sequence of all days between first and last
                                                             # detection

fake.df <- data.frame(ts) %>% # create the fake tag detected every day
  mutate(motusTagID = 99999) %>% 
  mutate(recvDeployName = "fake")

det.data.for.ms.eh <- bind_rows(det.data, fake.df) %>% # add fake tag to detection data
  arrange(ts) %>% 
  mutate(recvDeployName = str_replace(recvDeployName, "North Bluff", "1")) %>% # replace receiver names with numbers
  mutate(recvDeployName = str_replace(recvDeployName, "Netitishi", "2")) %>% 
  mutate(recvDeployName = str_replace(recvDeployName, "fake", "99999"))

det.data.for.ms.eh$recvDeployName <- as.numeric(det.data.for.ms.eh$recvDeployName) # format as numbers 
```

| motusTagID | ts         | recvDeployName |
| ---------: | :--------- | -------------: |
|      16011 | 2015-08-03 |              1 |
|      99999 | 2015-08-03 |          99999 |
|      16011 | 2015-08-04 |              1 |
|      99999 | 2015-08-04 |          99999 |
|      16011 | 2015-08-05 |              1 |

``` r
ms.enc.hist <- det.data.for.ms.eh %>% # create encounter histories
  tidyr::pivot_wider(id_cols = motusTagID, names_from = ts, values_from = recvDeployName,
                     values_fill = list(recvDeployName = 0)) %>% # fill 0 for days a bird wasn't detected
  filter(!motusTagID == 99999) %>% 
  arrange(motusTagID)
```

| motusTagID | 2015-08-03 | 2015-08-04 | 2015-08-05 | 2015-08-06 | 2015-08-07 | 2015-08-08 | 2015-08-09 | 2015-08-10 | 2015-08-11 | 2015-08-12 | 2015-08-13 | 2015-08-14 | 2015-08-15 | 2015-08-16 | 2015-08-17 | 2015-08-18 | 2015-08-19 | 2015-08-20 | 2015-08-21 | 2015-08-22 | 2015-08-23 | 2015-08-24 | 2015-08-25 | 2015-08-26 | 2015-08-27 | 2015-08-28 | 2015-08-29 | 2015-08-30 | 2015-08-31 | 2015-09-01 | 2015-09-02 | 2015-09-03 | 2015-09-04 | 2015-09-05 | 2015-09-06 | 2015-09-07 | 2015-09-08 |
| ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: |
|      16011 |          1 |          1 |          1 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |
|      16035 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          2 |          0 |          0 |          2 |          2 |          2 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          2 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |
|      16036 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          2 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |
|      16037 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          1 |          0 |          1 |          0 |          1 |          1 |          0 |          2 |          2 |          2 |          2 |          2 |          2 |          2 |          2 |          2 |          2 |
|      16038 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          1 |          1 |          1 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |          0 |
