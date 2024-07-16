library(rvest)
z <- list()
for(i in c("men", "women")){
  read_html(paste0("https://sportsbook.draftkings.com/leagues/tennis/wimbledon-",i,"?category=futures-")) -> x
  x <- data.frame(
    player = x %>%
      html_nodes('.sportsbook-outcome-cell__label') %>%
      html_text(trim = TRUE),
    odds = x %>%
      html_nodes('.sportsbook-odds') %>%
      html_text(trim = TRUE)
  )
  x$odds <- gsub("+", "", x$odds)
  x$odds <- as.numeric(gsub("−", "-", x$odds))
  x$prob <- ifelse(x$odds < 0, -1*x$odds / (-1*x$odds + 100), 100 / (x$odds + 100))
  x$prob <- x$prob / sum(x$prob)
  x$group <- i
  z[[length(z)+1]] <- x
}
z <- as.data.frame(do.call(rbind, z))
remove_middle_name <- function(name) {
  parts <- as.data.frame(do.call(rbind, strsplit(name, " ")))
  if (ncol(parts) > 2) {
    result <- paste(parts[1], parts[ncol(parts)])
  } else {
    result <- name
  }
  return(result)
}
z1 <- list()
for(i in c("men", "women")){
  read_html(paste0("https://sportsbook.draftkings.com/leagues/tennis/wimbledon-",i,"?category=match-lines&subcategory=moneyline")) -> x
  x <- data.frame(
    player = x %>%
      html_nodes('.sportsbook-outcome-cell__label') %>%
      html_text(trim = TRUE),
    odds = x %>%
      html_nodes('.sportsbook-odds') %>%
      html_text(trim = TRUE)
  )
  x$odds <- gsub("+", "", x$odds)
  x$odds <- as.numeric(gsub("−", "-", x$odds))
  x$prob <- ifelse(x$odds < 0, -1*x$odds / (-1*x$odds + 100), 100 / (x$odds + 100))
  y <- list()
  for(k in seq(1, nrow(x), 2)){
    y[[length(y)+1]] <- data.frame(
      player1 = x$player[k],
      player2 = x$player[k+1],
      prob1 = x$prob[k],
      prob2 = x$prob[k+1]
    )
  }
  y <- as.data.frame(do.call(rbind, y))
  y[,3:4] <-  y[,3:4] / apply(y[,3:4], 1, sum)
  
  # attempt 1
  y$champ1 <- z$prob[match(y$player1, z$player)]
  y$champ2 <- z$prob[match(y$player2, z$player)]
  
  # attempt 2
  y$player1[is.na(y$champ1)] <- sapply(y$player1[is.na(y$champ1)], remove_middle_name)
  y$player2[is.na(y$champ2)] <- sapply(y$player2[is.na(y$champ2)], remove_middle_name)
  y$champ1 <- z$prob[match(y$player1, z$player)]
  y$champ2 <- z$prob[match(y$player2, z$player)]
  
  # attempt 3
  y$player1[is.na(y$champ1)] <- gsub("-", " ", y$player1[is.na(y$champ1)])
  y$player2[is.na(y$champ2)] <- gsub("-", " ", y$player2[is.na(y$champ2)])
  y$champ1 <- z$prob[match(y$player1, z$player)]
  y$champ2 <- z$prob[match(y$player2, z$player)]
  
  y$balance <- 1 - abs(y$prob1 - y$prob2)
  y$champ <- apply(y[,5:6], 1, mean)
  y$group <- i
  z1[[length(z1)+1]] <- y
}
z1 <- as.data.frame(do.call(rbind, z1))
z1$champ <- (z1$champ - min(z1$champ)) / (max(z1$champ) - min(z1$champ))
z1$rating <- 1/4*z1$balance + 3/4*z1$champ
z1 <- z1[order(-z1$rating),]
z1$rating <- ifelse(z1$rating >= 0.9, "S", 
                    ifelse(z1$rating >= 0.8 & z1$rating < 0.9, "A", 
                           ifelse(z1$rating >= 0.7 & z1$rating < 0.8, "B", 
                                  ifelse(z1$rating >= 0.6 & z1$rating < 0.7, "C", 
                                         ifelse(z1$rating >= 0.5 & z1$rating < 0.6, "D", "F")))))
z1[z1$rating != "F",c(1:2,9:10)]