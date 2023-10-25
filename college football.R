
library(rvest)
library(stringr)

rm(list = ls())
'%ni%' = Negate('%in%')

##### web scrape #####

# scrape the "Football Power Index"
read_html("https://www.espn.com/college-football/fpi") %>%
  html_table() %>%
  as.data.frame() -> x

# clean up
colnames(x) = x[1,]
x = x[-1,]

# scrape the schedule
read_html("https://www.espn.com/college-football/schedule") -> z

# links on page
z %>% 
  html_nodes("a") %>% 
  html_attr("href") -> linkz

# extract dates
z %>% 
  html_nodes(".Table__Title") %>%
  html_text() %>%
  trimws() -> datez

# tables
z %>%
  html_table() -> y

# combine tables and add dates
z = list()
for(i in 1:length(y)){
  y1 = as.data.frame(y[[i]])
  y1 = y1[,1:4]
  y1$date = datez[i]
  z[[length(z)+1]] = y1
}
y = as.data.frame(do.call(rbind, z))

# clean up
colnames(y)[1:2] = c("Away", "Home")
rmz = rev(c(1:25, "@", "  "))
for(k in 1:2){
  for(i in 1:length(rmz)){
    for(z in 1:nrow(y)){
      y[z,k] = gsub(rmz[i], "", y[z,k])
      y[z,k] = str_trim(y[z,k])
    }
  }
}

##### match in team quality rankings to schedule #####

# clean up
x$match = gsub("\\s*\\w*$", "", x$Team)
x$match1 = gsub("\\s*\\w*$", "", x$match)

# match on names
y$away_fpi = x$FPI[match(y$Away, x$match)]
y$away_fpi = ifelse(is.na(y$away_fpi), 
                    x$FPI[match(y$Away, x$match1)], 
                    y$away_fpi)
y$home_fpi = x$FPI[match(y$Home, x$match)]
y$home_fpi = ifelse(is.na(y$home_fpi), 
                    x$FPI[match(y$Home, x$match1)], 
                    y$home_fpi)

# sum of away + home quality
y$fpi = as.numeric(y$away_fpi) + as.numeric(y$home_fpi)

##### get TV providers #####

# Issue? 'ESPN' reads in as a link rather than text

# easier to work with as a data frame
z = data.frame(
  num = 1:length(linkz),
  links = linkz
)

# cut out fluff at top and bottom of page
z = z[min(z$num[grepl("/college-football/team/", z$links)]):max(z$num[grepl("accuweather", z$links)]),]

# get rid of links that repeat
x = list()
for(i in 1:nrow(z)){
  x[[length(x)+1]] = ifelse(z$links[i] == z$links[i+1], z$num[i], NA)
}
x = unique(unlist(x))
x = x[!is.na(x)]
z = z[z$num %ni% x,]
z$num = 1:nrow(z)

# prepare to loop
endz = z$num[grepl("accuweather", z$links)]
startz = c(1, endz + 1)
startz = startz[-length(startz)]

# loop to identify which games have an ESPN link
x1 = list()
for(i in 1:length(endz)){
  x = z[startz[i]:endz[i],]
  if(nrow(x) == 5){
    x = data.frame(
      Away = x$links[1],
      Home = x$links[2],
      TIME = x$links[3],
      TV = NA
    )
  } else{
    x = data.frame(
      Away = x$links[1],
      Home = x$links[2],
      TIME = x$links[3],
      TV = x$links[4]
    )
  }
  x1[[length(x1)+1]] = x
}
x1 = as.data.frame(do.call(rbind, x1))
x1$TV = ifelse(grepl("plus", x1$TV), "ESPN+",
               ifelse(grepl("sec", x1$TV), "SECN",
                      ifelse(!is.na(x1$TV), "ESPN/ABC", NA)))
# match in 
y$TV = ifelse(is.na(y$TV) | y$TV == "", 
              x1$TV[match(row.names(y), row.names(x1))],
              y$TV)


##### Good Games #####

# kick out teams who have any negative scores or are going to be blowouts
y = subset(y, y$away_fpi > 0 & y$home_fpi > 0 & 
             abs(as.numeric(y$home_fpi) - as.numeric(y$away_fpi)) <= 14)
y

##### Best Games #####

z = aggregate(y$fpi, list(paste0(y$TIME, "_", y$date)), max)
z1 = as.data.frame(do.call(rbind, strsplit(z$Group.1, "_")))
z = data.frame(
  date = z1$V2,
  time = z1$V1,
  fpi = z$x
)

z = as.data.frame(cbind(z, y[match(z$fpi, y$fpi), 1:2]))
z[order(-z$fpi),]
