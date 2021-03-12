#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

library(shiny)
library(tidyverse)
library(motus)
library(DT)
library(ggmap)
library(leaflet)
library(lubridate)
library(fuzzyjoin)
library(oce)
library(plotly)
library(googleAuthR)

# Use the line below to set Google Maps authentication (only needed to be done once)
#options(googleAuthR.client_id = "[ENTER CLIENT ID HERE]", googleAuthR.client_secret = "[ENTER CLIENT SECRET KEY HERE]")


Sys.setenv(tz = "GMT")


default.proj <- 2
default.recv <- 'Lawrencetown'

# Select a folder where data is stored
dir <- 'E:/Data/'

# projected metadata
proj.df <- read.csv(paste0(dir, 'motus-projects.csv'))

# Load all receiver deployments
recv.df <- read.csv(paste0(dir, 'receiver-deployments.csv')) %>% 
  mutate(tsStart = as.POSIXct(tsStart, origin = '1970-01-01'),
         tsEnd = as.POSIXct(tsEnd, origin = '1970-01-01'),
         dtStart = as.Date(dtStart),
         dtEnd = as.Date(dtEnd))

projList <- unique(recv.df$recvProjectID)

names(projList) <- proj.df[proj.df$projectID %in% unique(recv.df$recvProjectID),]$projectName

projList <- c("Select one", "All projects", projList)

stationList <- c()

sql.table.to.df <- function(recv, tblName, dir = '') {
  message(paste0(dir, recv, ".motus"))
  sql <- DBI::dbConnect(RSQLite::SQLite(), paste0(dir, recv, ".motus"))
  sql %>% tbl(tblName) %>% collect() %>% as_tibble() %>% mutate(serno = recv)
}

basic.colours <- c("red", "green", "blue", "purple", "yellow", "turquoise", "orange")

all_years <- c("All", "2020", "2019", "2018", "2017", "2016", "2015", "2014", "2013")
all_freqs <- c("166.380 MHz", "150.1 MHz", "151.5 MHz", "434 MHz")
all_timeRes <- c("Day", "Month", "Year", "All time")
#all_tag_models <- c("Day", "Month", "Year", "All time")

# Define UI for application that draws a histogram
ui <- fluidPage(
  tags$head(tags$style(
    HTML('
         #sidebar {
            /*background-color: #d0e0e3;*/
            /*background-color: #d9ead3;*/
            background-color: #fce5cd;
        }

        body, label, input, button, select { 
          font-family: "Arial";
        }')
  )),
  
  # Application title
  titlePanel("Motus Station Status"),
  
  # Sidebar with a slider input for number of bins 
  sidebarLayout(
    sidebarPanel(id='sidebar',
      selectInput("project", "Select a project", projList, selected = default.proj),
      selectInput("station", "Select a station", stationList),
      selectInput("year", "Year", all_years),
      selectInput("freq", "Frequency", all_freqs),
      selectInput("timeRes", "Show active receivers by", all_timeRes),
      radioButtons("tagBy", "Search tag ", c("deployments", "detections")),
      sliderInput("recv_date", "", min = as.Date("2013-03-19"), max = Sys.Date(), value = c(as.Date('2013-03-19'), as.Date('2020-11-04'))),
      textOutput("fileCount")
    ),
    # Show a plot of the generated distribution
    mainPanel(
      conditionalPanel(condition = "nFiles() > 0",
      tabsetPanel(
          tabPanel('Devices', 
                   DT::dataTableOutput('recv_devices'),
                   plotlyOutput('deviceDeployments')
          ),
          tabPanel('Map', plotOutput('recvLocation')),
          tabPanel('Antennas', 
                   tableOutput('antCurrent_tbl'),
                   plotOutput('antHistory_plot'),
                   plotOutput('antHistory_map')
          ),
          tabPanel('Activity', plotlyOutput('antActivity_plot'))
        )
      )
    )
  )
)

# Define server logic required to draw a histogram
server <- function(input, output, session) {
  proj <- reactive({input$project})
  recv <- reactive({input$station})
  
  nFiles <- reactive({length(which(file.exists(paste(dir,receiver(),'.motus', sep = ''))))})
  
  output$fileCount <- renderText({
    
    paste0(nFiles(), " of ", length(receiver()), " files exist!")
  #  paste0(nFiles())
    
  })
  
  observe({
    
    # Remove all choices if nothing selected
    if (is.null(proj())) {
      recv.sites <- character(0)
    } else {
      # Create a new object of choices
      recv.sites <- c("Select one", as.character(unique(recv.df[recv.df$recvProjectID == proj(),]$siteName)))
    }
    # Update recv input with selections
    updateSelectInput(session, "station",
                      label = "Select a station",
                      choices = recv.sites, 
                      selected = default.recv)
  })
    output$recv_devices <- DT::renderDataTable({
      
      recv.df %>% 
        filter(recvProjectID == proj(), siteName == recv()) %>% 
        select(recvDeployID, receiverID, tsStart, tsEnd) %>%
        mutate_at(c("tsStart", 'tsEnd'), as.POSIXct, origin = '1970-01-01')
      
    })
    
    receiver <- reactive({unique(recv.df[recv.df$recvProjectID == proj() & recv.df$siteName == recv(), ]$receiverID)})
    
    deps.df <- reactive({
      
      message(paste0('Loading receiver deployments for: ', recv()))
      
      df <- bind_rows(lapply(receiver(), function(x){sql.table.to.df(x, 'recvDeps', dir)})) %>%
        mutate(selected = grepl(recv(), name),
               tsStart = as.POSIXct(tsStart, origin = '1970-01-01'),
               tsEnd = ifelse(is.na(tsEnd), Sys.time(), tsEnd),
               tsEnd = as.POSIXct(tsEnd, origin = '1970-01-01'))
      df$name <- factor(df$name, levels = c(unique(filter(df, grepl(recv(), name))$name), unique(filter(df, !grepl(recv(), name))$name)))
      
      message(paste0(nrow(df), ' receiver deployments found.'))
      
      df
    })
    
    
    station.ll <- reactive({
      
      deps.df() %>% 
        filter(selected) %>%
        rename(lat = latitude, lon = longitude) %>%
        summarise(lat = median(lat, na.rm = T), lon = median(lon, na.rm = T)) %>%
        as.list()
      
    })
    
    station.declination  <- reactive({ magneticField(station.ll()$lon, station.ll()$lat, median(deps.df()$tsStart))$declination })
    
    ant.df <- reactive({
      message("ant.df")
      
      message(paste0('Loading antenna deployments for: ', recv()))
      
      df <- bind_rows(lapply(receiver(), function(x){sql.table.to.df(x, 'antDeps', dir)})) %>%
        mutate(bearingMagnetic = round(bearing - station.declination())) %>%
        select(-serno) %>%
        left_join(deps.df(), by = 'deployID') %>%
        mutate(selected = grepl(recv(), name),
               depLen = difftime(tsEnd, tsStart, units = 'secs'),
               name = factor(ifelse(selected, recv(), as.character(name))),
               name = factor(name, levels = c(recv(), levels(name)[which(levels(name) != recv())])))
        
        message(paste0(nrow(df), ' antenna deployments found.'))
      
      df
      
    })
    ant.selected.df <- reactive({
      message("ant.selected.df")
      ant.df() %>%
        filter(selected) %>%
        mutate(port = factor(port),
               tsMean = tsStart + (difftime(tsEnd, tsStart, units = 'secs')/2),
               heightMeters = ifelse(is.na(heightMeters), 0, heightMeters),
               plot.lon.lg = longitude + (sin(pi * (-bearing + 90) / 180)*-0.0125),
               plot.lat.lg = latitude + (cos(pi * (-bearing + 90) / 180)*0.0125),
               plot.lon.sm = longitude + (sin(pi * (-bearing + 90) / 180)*-0.0275),
               plot.lat.sm = latitude + (cos(pi * (-bearing + 90) / 180)*0.0275)) 
      
    })
    
    
    activity.df <- reactive({
      
      message(paste0('Loading antenna activity for: ', recv()))
      
      df <- bind_rows(lapply(receiver(), function(x){sql.table.to.df(x, 'pulseCounts', dir)})) %>%
        mutate(ts = as.POSIXct(as.Date('1970-01-01')) + hours(hourBin),
               date = as.Date(ts),
               ant = factor(ant)) %>%
        filter(as.Date("2010-01-01") < date) %>%
        fuzzy_left_join(
          select(filter(deps.df(), grepl(recv(), name)), -serno), 
          by = c('ts' = 'tsStart', 'ts' = 'tsEnd'), 
          match_fun = list(`>=`, `<=`)
        ) %>%
        filter(!is.na(deployID))
      
      message(paste0(sum(df$count, na.rm = T), ' antenna pulses found.'))
      
      df
      
    })
    
    gps.df <- reactive({
      
      message(paste0('Loading GPS activity for: ', recv()))
      
      df <- bind_rows(lapply(receiver(), function(x){sql.table.to.df(x, 'gps', dir)})) %>%
        mutate(ts = as.POSIXct(ts, origin = '1970-01-01'),
               date = as.Date(ts)) %>%
        filter(as.Date("2010-01-01") < date) %>%
        fuzzy_left_join(
          select(filter(deps.df(), grepl(recv(), name)), -serno), 
          by = c('ts' = 'tsStart', 'ts' = 'tsEnd'), 
          match_fun = list(`>=`, `<=`)
        ) %>%
        filter(!is.na(deployID))
      
      message(paste0(nrow(df), ' GPS hits found.'))
      
      df
      
    })
    
    
    map.small <- reactive({
      get_map(location = c(lon = station.ll()$lon, lat = station.ll()$lat), zoom = 10, maptype = "satellite")
    })
    
    
    #######################################################
    #######################################################
    #######################################################
    #######################################################
    ###############                         ###############
    ###############                         ###############
    ###############                         ###############
    ###############                         ###############
    #######################################################
    #######################################################
    #######################################################
    #######################################################
    
      output$recvLocation <- renderPlot({
        
        
        message(paste0("Tower coords: ", station.ll()$lat, ", ", station.ll()$lon))
        # Get lat/lon bounding box around these sites
        latLonBounds <- list((station.ll()$lon + c(-1, 1)),
                             (station.ll()$lat + c(-1, 1))
        )
        
        message("nearby.recv.df")
        nearby.recv.df <- recv.df %>%
          filter(latitude > latLonBounds[[2]][1] & latitude < latLonBounds[[2]][2],
                 longitude > latLonBounds[[1]][1] & longitude < latLonBounds[[1]][2],
                 is.na(tsEnd))
        
        message(paste0("Lon: ", range(ant.selected.df()$plot.lon.lg), " - Lat: ", range(ant.selected.df()$plot.lat.lg)))
        ggmap(map.small(), base_layer = ggplot(data = nearby.recv.df, aes(x = longitude, y = latitude)))+
          geom_point(fill = 'red',
                     shape = 21,
                     stroke = 2, 
                     size = 2, 
                     alpha = 1)+
          geom_point(aes(x = station.ll()$lon, y = station.ll()$lat), 
                     shape = 8,
                     color = 'black',
                     stroke = 2,
                     size = 4, 
                     alpha = 1)+
          geom_point(aes(x = station.ll()$lon, y = station.ll()$lat), 
                     fill = 'yellow', 
                     shape = 21,
                     color = 'black',
                     stroke = 2, 
                     size = 3, 
                     alpha = 1)+
          geom_text(data = filter(ant.selected.df(), status == 'active'), aes(x = plot.lon.lg, y = plot.lat.lg, angle = - bearing + 90, color = port), 
                    label="\U2192", size = 10)+
          #    coord_fixed(xlim = latLonBounds[[1]], ylim = latLonBounds[[2]])+
          theme(panel.background = element_rect(fill = '#CCDDFF'),
                panel.grid.major = element_blank(),
                panel.grid.minor = element_blank(),
                axis.text = element_blank(),
                axis.ticks = element_blank(),
                legend.title = element_blank(),
                axis.title = element_blank()) +
          scale_fill_manual(values = c('red' = 'red', 'yellow' = 'yellow'), guide = 'legend', labels = c('Other stations', recv()))
      })
      output$deviceDeployments <- renderPlotly({
        
        n.deps <- length(unique(ant.df()$name))
        
        cust.cols <- c(hcl(seq(from = 0, to = 360 - (360 / n.deps), length.out = n.deps), 100, 75, alpha = c(1, rep(0.1, n.deps - 1))))
        
        serno.selected.deps <- ant.df() %>%
          group_by(serno) %>%
          summarise(selected.start = as.integer(min(tsStart[which(selected)], na.rm = T)))
        
        p <- ant.df() %>%
          left_join(serno.selected.deps, by = 'serno') %>%
          ggplot()+
          geom_tile(aes(x = tsStart + (depLen/2), width = depLen, y = fct_reorder(serno, -selected.start), fill = name), color = 'black')+
          theme(panel.background = element_rect(fill = NA))+
          scale_fill_manual(values = cust.cols, labels = levels(ant.df()$name))+
          labs(x = 'Time', y = 'Serial Number', fill = '', title = 'Location for each deployment of devices')
        
        ggplotly(p)
        
      })
      
      output$antCurrent_tbl <- renderTable({
        
        ant.current.df <- ant.selected.df() %>% 
          filter(deployID == max(ant.selected.df()$deployID)) %>%
          select(port, `Magnetic bearing` = bearingMagnetic, `Height (m)` = heightMeters, `Antenna type` = antennaType)
        
        ant.current.df2 <- data.frame(t(ant.current.df[-1])) 
        
        colnames(ant.current.df2) <- paste("Port", ant.current.df$port)
        
        rownames(ant.current.df2) <- c("Bearing (magnetic)", "Height (meters)", "Antenna type")
        
        ant.current.df2
        
      }, rownames = T)
      
      
      
      output$antHistory_plot <- renderPlot({
        
        ant.selected.df() %>%
          ggplot()+
          geom_rect(aes(xmin = tsStart, xmax = tsEnd, 
                        ymin = min(heightMeters, na.rm = T) - 0.5, 
                        ymax = max(heightMeters, na.rm = T) + 0.5, fill = factor(deployID)), alpha = 0.1)+
          # Must insert Unicode rather than "→" character to render correctly
          geom_text(aes(x = tsMean, y = heightMeters, angle = - bearing + 90, color = port), 
                    label="\U2192", size = 10)+
          scale_color_manual(values = basic.colours) +
          scale_fill_discrete(guide = 'none') +
          labs(x = '', y = 'Antenna Height (m)', color = 'Port', fill = 'Deployment\nID', title = 'Antenna directions and heights over time')+
          theme(panel.background = element_rect(fill = NA))
        
      })
      
      
      output$antHistory_map <- renderPlot({
        ggmap(map.small(), base_layer = ggplot(data = ant.selected.df()))+
          geom_text(aes(x = plot.lon.sm, y = plot.lat.sm, angle = - bearing + 90, color = port), 
                    label="\U2192", size = 10)+
          # facet_wrap(~format(tsStart, '%b %Y') + deployID, labeller = label_value)
          facet_wrap(.~interaction(format(tsStart, '%b %Y'), deployID))+
          coord_cartesian()
      })
      
      
      
      output$antActivity_plot <- renderPlotly({
        
        gps.ant.df <- gps.df() %>%
          mutate(ant = factor('GPS', levels = c('GPS', levels(activity.df()$ant))), count = 1) %>%
          select(ts, ant, count) %>%
          rbind(select(activity.df(), ts, ant, count)) 
        
        res <- 0
        
      
        temp.df <- gps.ant.df %>%
          filter(res == 0 | ts > max(ts) - months(res))
        
        if (nrow(temp.df) > 0) {
          
          p <- temp.df %>%
            ggplot(aes(ts, ant, fill = count))+
            geom_tile(aes(width = (difftime(max(ts), min(ts), units = 'days')*100000/365), height = 1))+
            scale_alpha_continuous(limits = c(1, 100), range = c(0.5,1))+
            scale_fill_gradientn(colours = c("black", "green", "yellow", "red"), breaks = c(1,100,10000,1000000), trans = 'log')+
            theme(panel.background = element_rect(fill = "#FAFAFA"),
                  panel.grid = element_blank(),
                  panel.grid.major.y = element_line(color = 'black'))+
            labs(x = 'Date', y = 'Antenna', fill = 'Hourly\nPulse Count', title = paste0('Antenna activity over ', ifelse(res == 0, 'entire history', paste0(res, ' months'))))
          if (nrow(gps.df()) == 0) {
            # geom_label is extremely slow if we just include it using the same dataframe as the rest of the plot
            # here I make a 1-row dataframe so that geom_label doesn't make a new label for each row in df.gps.ant
            gps.ant.gps.df <- gps.ant.df %>%
              filter(res == 0 | ts > max(ts) - months(res)) %>%
              summarise(ts.min = min(ts, na.rm = T), ts.max = max(ts, na.rm = T))
            
            p <- p  + 
              geom_label(data = gps.ant.gps.df, aes(x = (ts.min + (difftime(ts.max, ts.min, units = 'secs')/2)), y = 'GPS', label  = 'NO GPS DATA EXIST'), fill = 'white')
          } 
          
          ggplotly(p)
        } else {
          warning("No GPS hits exist!")
        }
      })
}

# Run the application 
shinyApp(ui = ui, server = server)

