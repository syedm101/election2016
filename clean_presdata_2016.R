all_counties_2012 <- read.csv("~/Second Year/DS 4559 - Data Science/Final Project/election2016/Data/2012data/all_counties_2012.csv",
                              stringsAsFactors = FALSE)
all_counties_2012 <- subset(all_counties_2012, fips!="fips")
all_counties_2012$votes <- as.numeric(all_counties_2012$votes)
#case insensitive search for rows containing obama or romney
all_counties_2012_romney <- all_counties_2012[grepl('romney',all_counties_2012$candidate,ignore.case=TRUE), ] 
all_counties_2012_obama <- all_counties_2012[grepl('obama',all_counties_2012$candidate,ignore.case=TRUE), ] 

#all_counties_2012_romney <- aggregate (. ~ fips, data=all_counties_2012_romney, FUN=sum)

all_counties_2012 <- rbind(all_counties_2012_romney,all_counties_2012_obama)
all_counties_2012 <- subset(all_counties_2012, fips !="")
summary(all_counties_2012)
summary(all_counties_2012$fips)

#include only first letter
all_counties_2012[,3] <- substring(all_counties_2012[,3], 1, 1) 

all_counties_2012$candidate <- replace(all_counties_2012$candidate, all_counties_2012$candidate=="o", "obama")
all_counties_2012$candidate <- replace(all_counties_2012$candidate, all_counties_2012$candidate=="O", "obama")
all_counties_2012$candidate <- replace(all_counties_2012$candidate, all_counties_2012$candidate=="B", "obama")
all_counties_2012$candidate <- replace(all_counties_2012$candidate, all_counties_2012$candidate=="b", "obama")
all_counties_2012$candidate <- replace(all_counties_2012$candidate, all_counties_2012$candidate=="m", "romney")
all_counties_2012$candidate <- replace(all_counties_2012$candidate, all_counties_2012$candidate=="M", "romney")
all_counties_2012$candidate <- replace(all_counties_2012$candidate, all_counties_2012$candidate=="r", "romney")
all_counties_2012$candidate <- replace(all_counties_2012$candidate, all_counties_2012$candidate=="R", "romney")
all_counties_2012 <- aggregate (votes ~ fips+candidate+county, data=all_counties_2012, FUN=sum)

summary(all_counties_2012$candidate) 

all_counties_2012 <- data.frame(lapply(all_counties_2012, as.character), stringsAsFactors=FALSE)
all_counties_2012$votes <- as.numeric(all_counties_2012$votes)

long12 <- dcast(all_counties_2012, fips ~ candidate, value.var = "votes")


summary(all_counties_2012)
summary(all_counties_2012$fips)

