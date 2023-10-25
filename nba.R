
library(rvest)
library(stringr)

rm(list = ls())
'%ni%' = Negate('%in%')

##### web scrape #####

# main site
read_html("https://www.espn.com/nba/schedule") -> x

# extract dates
x %>% 
  html_nodes(".Table__Title") %>%
  html_text() %>%
  trimws() -> datez

# extract links (messy)
x %>% 
  html_nodes("a") %>% 
  html_attr("href") -> linkz

# combine tables and add dates
y = list()
for(i in 1:length(html_table(x))){
  x1 = as.data.frame(html_table(x)[[i]])
  x1 = x1[,1:4]
  x1$date = datez[i]
  y[[length(y)+1]] = x1
}
x = as.data.frame(do.call(rbind, y))

# clean up
colnames(x)[1:2] = c("Away", "Home")
x$Home = substr(x$Home, 4, nchar(x$Home))

##### get TV providers #####

# Issue? 'ESPN' reads in as a link rather than text

# easier to work with as a data frame
z = data.frame(
  num = 1:length(linkz),
  links = linkz
)

# cut out fluff at top and bottom of page
z = z[min(z$num[grepl("/nba/team/", z$links)]):max(z$num[grepl("vivid", z$links)]),]

# get rid of links that repeat
y = list()
for(i in 1:nrow(z)){
  y[[length(y)+1]] = ifelse(z$links[i] == z$links[i+1], z$num[i], NA)
}
y = unique(unlist(y))
y = y[!is.na(y)]
z = z[z$num %ni% y,]
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

##### which games are on national TV? #####

x[!is.na(x$TV) & x$TV != "" & x$TV != "NBA TV",]
