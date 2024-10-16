
library(RSelenium)
library(rvest)

# Connect to the Selenium Remote Driver
### Note: You will need Firefox installed
### Selinium does not play nicely with chrome
rD <- rsDriver(browser="firefox", port=4444L, verbose=F)
remDr <- rD[["client"]]

# Go to the webpage
remDr$navigate("https://theanalyst.com/na/2023/08/opta-football-predictions/")

# Let the page load and read the HTML
Sys.sleep(5)
page_source <- remDr$getPageSource()[[1]]
remDr$switchToFrame(1)

# T ry getting the page source again and look for the table
page_source <- remDr$getPageSource()[[1]]
html <- read_html(page_source)
tables <- html %>% html_nodes("table")
html %>%
  html_table() -> z

# Close the page
remDr$close()

# Clean the data
y <- list()
for(i in 1:length(z)){
  x <- as.data.frame(z[i])
  if(ncol(x) < 3){
    next
  }
  if("FT" %in% x[,3]){
    next
  }
  if(nrow(x) == 2 & ncol(x) == 4){
    y[[length(y)+1]] <- data.frame(
      home = x[1,1],
      away = x[2,1],
      home_pr = x[1,2],
      away_pr = x[2,2],
      win = as.numeric(gsub("%", "", x[1,3])),
      lose = as.numeric(gsub("%", "", x[2,3])),
      draw = as.numeric(gsub("%", "", gsub("DRAW", "", x[1,4])))
    )
  }else{
    next
  }
  
}
y <- as.data.frame(do.call(rbind, y))

# Extract match dates
html %>%
  html_nodes("._match-card-right-label_1u4oy_83") %>%
  html_text() -> match_dates

# Clean dates & kickoff times
x <- list()
for(i in seq(1, length(match_dates), 2)){
  if("LIVE" == match_dates[i+1] | "" == match_dates[i+1]){
    next
  }
  x[[length(x)+1]] <- data.frame(
    league = match_dates[i],
    date = as.data.frame(do.call(rbind, strsplit(match_dates[i+1], " @ ")))$V1,
    kickoff = as.data.frame(do.call(rbind, strsplit(match_dates[i+1], " @ ")))$V2
  )
}
x <- as.data.frame(do.call(rbind, x))
z <- as.data.frame(do.call(rbind, strsplit(x$kickoff, ":")))
z1 <- as.data.frame(do.call(rbind, strsplit(z[,2], " ")))
x$kickoff <- ifelse(z1$V2 == "PM", paste0(as.numeric(z$V1)+12, ":", z1$V1), 
                 paste0(as.numeric(z$V1), ":", z1$V1))
z <- data.frame(
  abbr = c("Jan", "Feb", "Mar", "Apr", "May", "Jun", 
           "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"),
  month = 1:12
)
x$date <- as.Date(paste0("2024-", z$month[match(as.data.frame(do.call(rbind, strsplit(x$date, " ")))$V1,
                                       z$abbr)],
                         "-", as.data.frame(do.call(rbind, strsplit(x$date, " ")))$V2))
x$kickoff <- ifelse(as.data.frame(do.call(rbind, strsplit(x$kickoff, ":")))$V1 == 24, 
                 paste0("12:", as.data.frame(do.call(rbind, strsplit(x$kickoff, ":")))$V2),
                 x$kickoff)
x$time <- as.POSIXct(paste(x$date, x$kickoff), 
                    format = "%Y-%m-%d %H:%M")

# Drop any game that has already happened
x <- x[x$time >= Sys.time(),]
'%ni%' <- Negate('%in%')
x$keep <- 1:nrow(x)

# Drop (for now) WSL matches because they don't have team ratings
x <- x[x$league %ni% c("WSL"),]
x <- cbind(x[1:nrow(y),1:3], y)

# Drop uneven match ups & low quality teams while always keeping European matches
x$overall <- round((x$home_pr + x$away_pr)/2)
x$diff <- 100 - abs(x$win - x$lose)
x$score <- round(x$overall*3/4 + x$diff*1/4)
x_subset <- as.data.frame(lapply(x[, c(6, 7)], as.numeric))
x <- x[rowSums(x_subset >= 85) == ncol(x_subset >= 85),]
x <- x[x$diff >= 50,]

# Simplify output
z <- data.frame(
  league = x$league,
  time = as.POSIXct(paste(x$date, x$kickoff), 
                    format = "%Y-%m-%d %H:%M"),
  home = x$home,
  away = x$away,
  rating = x$score
)

# Print output
z
