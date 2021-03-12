##################################################################
#### 
#### MOTUS STATION REPORT
#### Lucas Berrigan
#### 2 November 2020
#### 
##################################################################
####
#### This script creates a function which produces a station summary for one location.
####  - It will find all receiver serial numbers for a single 'station'.
####  - It automatically download data from all receivers during that stations history.
####  - An option for printable reports removes track hyperlinks (keep false if not printing)
####  - To change title and authorship, edit the first two lines of the 'stationReport_v#.#.rmd' document.
####  - Please report bugs to: lberrigan[AT]birdscanada[DOT]org
#### 
##################################################################
#### 


makeReport(
            receiver.name = 'Louisbourg', # The name you want to have displayed on the report
            receiver.deploy.name = 'Louisbourg', # A character string that is common among all deployment names
            projectID = 2, # If NA, will look for matching receiver.deploy.names in all deployments
            printable = F, # Removes hyperlinks, etc.
            data.dir = 'E:/Data/',
            save.dir = 'E:/Data/Reports/'
           )

makeReport <- function(receiver.name = '', 
                       receiver.deploy.name = '', 
                       projectID = NA, # If NA, will look for matching receiver.deploy.names in all deployments
                       printable = F, # Removes hyperlinks, etc.
                       data.dir = 'E:/Data/',
                       save.dir = 'E:/Data/Reports/'
                       ) {
  require(lubridate)
  require(tidyverse)
  receiver.name <- receiver.name
  receiver.deploy.name <- ifelse(is.na(receiver.deploy.name), receiver.name, receiver.deploy.name)
  language <- 'EN' # English = EN, Francais = FR, Espaniol = ES
 
  
  pdf.fileName <- gsub(' ', '-', paste0(receiver.name, ' Motus Station Report.pdf'), fixed = T)
  
  pdf.exists <- file.exists(paste0(save.dir, pdf.fileName))
  
  if (!pdf.exists | 
      (pdf.exists
    &
    Sys.time() - file.info(paste0(save.dir, pdf.fileName))$mtime > days(1))) {
    
    message(paste0('Starting report for ', receiver.name))
    
    
  # for pdf reports  
     rmarkdown::render(input = "stationReport_v1.0.rmd", 
             output_format = "pdf_document",
             output_file = pdf.fileName,
             output_dir = save.dir)
  } else {
    message(paste0('A report for ', receiver.name, ' has already been made in the past 24 hours'))
  }
}


