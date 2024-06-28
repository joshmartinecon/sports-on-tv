
library(rvest)
library(stringr)

rm(list = ls())
'%ni%' = Negate('%in%')

##### WNBA: web scrape #####

# main site
read_html("https://www.espn.com/wnba/schedule") -> x

# extract dates
x %>% 
  html_nodes(".Table__Title") %>%
  html_text() %>%
  trimws() -> datez
datez2 = as.data.frame(do.call(rbind, strsplit(datez, " ")))
for(i in 1:ncol(datez2)){
  datez2[,i] = gsub(",", "", datez2[,i])
}
datez2 = as.Date(paste(datez2$V4, datez2$V2, datez2$V3), format = "%Y %B %d")

# extract links (messy)
x %>% 
  html_nodes("a") %>% 
  html_attr("href") -> linkz

# combine tables and add dates
y = list()
for(i in (1:length(html_table(x)))){
  x1 = as.data.frame(html_table(x)[[i]])
  x1 = x1[,1:4]
  x1$date = datez[i]
  y[[length(y)+1]] = x1
}

# drop data frames from the past
z1 = list()
for(i in 1:length(y)){
  z = as.data.frame(do.call(cbind, y[[i]]))
  z = as.data.frame(do.call(rbind, strsplit(z$date, ", ")))
  calendar = data.frame(
    month = c("January", "February", "March", "April", "May",
              "June", "July", "August", "September", "October",
              "November", "December"),
    number = 1:12
  )
  z$month = as.data.frame(do.call(rbind, strsplit(z$V2, " ")))$V1
  z$day = as.data.frame(do.call(rbind, strsplit(z$V2, " ")))$V2
  z$month_number = calendar$number[match(z$month, calendar$month)]
  z$date = as.Date(paste0(z$V3, "-", z$month_number, "-", z$day))
  y[[i]]$date = z$date
  
  if(unique(y[[i]]$date >= Sys.Date())){
    z1[[length(z1)+1]] = y[[i]]
  }
}
y = z1
x = as.data.frame(do.call(rbind, y))

# clean up
colnames(x)[1:2] = c("Away", "Home")
x$Home = substr(x$Home, 4, nchar(x$Home))

##### WNBA: get TV providers #####

# Issue? 'ESPN' reads in as a link rather than text

# easier to work with as a data frame
z = data.frame(
  num = 1:length(linkz),
  links = linkz
)

# cut out fluff at top and bottom of page
z = z[min(z$num[grepl("/wnba/team/", z$links)]):max(z$num[grepl("vivid", z$links)]),]
z$num = 1:nrow(z)
z = z[min(z$num[grepl(tolower(gsub(" ", "-", x$Away[1])), z$links)]):nrow(z),]

# get rid of links that repeat
y = list()
for(i in 1:nrow(z)){
  y[[length(y)+1]] = ifelse(z$links[i] == z$links[i+1], z$num[i], NA)
}
y = unique(unlist(y))
y = y[!is.na(y)]
z = z[z$num %ni% y,]
z <- z[!grepl("espnbet", z$links),]
z$num = 1:nrow(z)

# prepare to loop
endz = z$num[grepl("vivid", z$links)]
startz = c(1, endz + 1)
startz = startz[-length(startz)]

# loop to identify which games have an ESPN link
y1 = list()
for(i in 1:length(endz)){
  y = z[startz[i]:endz[i],]
  if(nrow(y) == 4){
    y = data.frame(
      Away = y$links[1],
      Home = y$links[2],
      TIME = y$links[3],
      TV = NA
    )
  } else{
    y = data.frame(
      Away = y$links[1],
      Home = y$links[2],
      TIME = y$links[3],
      TV = y$links[4]
    )
  }
  y1[[length(y1)+1]] = y
}
y1 = as.data.frame(do.call(rbind, y1))
y1$TV = ifelse(!is.na(y1$TV), "ESPN", NA)

# match in 
x[row.names(y1)[!is.na(y1$TV)],4] = "ESPN/ABC"

##### WNBA: scrape and match in betting odds #####

# download html
read_html("https://www.vegasinsider.com/wnba/odds/futures/") -> y

# extract text
y %>%
  html_text() -> z

# team names
teamz <- c("Atlanta Dream", "Chicago Sky", "Connecticut Sun", "Dallas Wings", "Indiana Fever", 
           "Las Vegas Aces", "Los Angeles Sparks", "Minnesota Lynx", "New York Liberty", 
           "Phoenix Mercury", "Seattle Storm", "Washington Mystics")

y <- list()
for(i in teamz){
  for(k in c("+", "-")){
    y[[length(y)+1]] <- unique(unlist(str_extract_all(z, paste0(teamz, " ", "\\", k, "\\d+(\\.\\d+)?"))))
  }
}
y <- data.frame(
  scrape = unique(unlist(y))
)
y$team <- trimws(str_extract(y$scrape, "^[A-Za-z ]+[^\\d+-]"))
y$odds <- as.numeric(str_extract(y$scrape, "[+-]?\\d+"))
y$prob <- round(ifelse(y$odds > 0, 100 / (100 + y$odds), -1*y$odds / (100 - y$odds)), 2)

# match over to schedule
z <- data.frame(
  full_name = teamz,
  abbr_name = c("Atlanta", "Chicago", "Connecticut", "Dallas", "Indiana", "Las Vegas",
                "Los Angeles", "Minnesota", "New York", "Phoenix", "Seattle", "Washington")
)
z$odds <- y$prob[match(z$full_name, y$team)]
x$away_odds = z$odds[match(x$Away, z$abbr_name)]
x$home_odds = z$odds[match(x$Home, z$abbr_name)]
x$combined_odds = rowMeans(x[,6:7])

x$grade = ifelse(x$combined_odds >= quantile(x$combined_odds, 0.9), "S",
                 ifelse(x$combined_odds >= quantile(x$combined_odds, 0.8), "A",
                        ifelse(x$combined_odds >= quantile(x$combined_odds, 0.7), "B",
                               ifelse(x$combined_odds >= quantile(x$combined_odds, 0.6), "C", 
                                      ifelse(x$combined_odds >= quantile(x$combined_odds, 0.5), "D", "F")))))
x = x[,-6:-8]

##### WNBA: which (good) games are on national TV? #####

# good names on TV?

x[!is.na(x$TV) & x$TV != "" & x$TV != "NBA TV" & x$grade != "F",]
