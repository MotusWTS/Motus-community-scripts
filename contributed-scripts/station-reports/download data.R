downloadMotus_recvData <- function(site.name, projID = NA, dir = '') {
  message("Logging in to Motus...")
  
  if (identical(Sys.getenv('motus_userAuth'), '')) {
    Sys.setenv(motus_userLogin = '')  # Put your Motus username here
    Sys.setenv(motus_userPassword = '')  # Put your Motus password here
    tryCatch({
      motus:::local_auth()
      Sys.setenv(motus_userAuth = TRUE)
      message("Login successful!")
    }, error = function(e) {
      stop("Login failed! '", e$message,"'", call. = F)
    })
  }
  
  ## Load scripts
  require(motus)
  require(tidyverse)
  
  # Set session time to GMT
  Sys.setenv(tz = "GMT")
  
  # Select a folder where data is stored
  #dir <- '../Data/'
  
  # Load all receiver deployments
  recv.df <- read.csv(paste0(dir, 'receiver-deployments.csv')) %>% 
    mutate(tsStart = as.POSIXct(tsStart, origin = '1970-01-01'),
           tsEnd = as.POSIXct(tsEnd, origin = '1970-01-01'),
           dtStart = as.Date(dtStart),
           dtEnd = as.Date(dtEnd))
  
  select.recv.df <- recv.df %>% 
    filter(grepl(site.name, deploymentName, T), recvProjectID == projID | is.na(projID))
  
  for (recv in unique(select.recv.df$receiverID)) {
    message(" --- START --- ")
    
    dbname <- paste0(dir, recv, '.motus')
      
    message(dbname)
    
    sql <- tagme(projRecv = recv, new = !file.exists(dbname), update = T, forceMeta = T, dir = dir)
    
    
    df <- sql %>% tbl('alltagsGPS') %>% collect() %>% as_tibble()
    
    # Save an RDS file (compact, faster loading)
    saveRDS(df, paste0(dir, recv, ".rds"))
    message(" --- DONE --- ")
  }
}
