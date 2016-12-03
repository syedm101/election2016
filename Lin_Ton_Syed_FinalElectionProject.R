#DS 4559 Final Project
#Exploring the 2016 Election
#Nathan Lin, Andrew Ton, Mansoor Syed

#Libraries needed
library(reshape2)
library(tigris)
library(ggplot2)
library(leaflet)
library(maps)
library(scales)
library(sqldf)

####2016 General Election Data####
setwd("~/Second Year/DS 4559 - Data Science/Final Project/election2016/Data")

#Read the 2016 general election data + FIPS code database
gen16 <- read.csv("pres16results.csv", header = TRUE, stringsAsFactors = FALSE)
fips.labels <- read.csv("fips_database.csv", header = FALSE, stringsAsFactors = FALSE, colClasses = "character")

#Cleaning general election data
gen16 <- gen16[which(gen16$cand == "Donald Trump" | gen16$cand == "Hillary Clinton"),]
gen16 <- gen16[-c(1,2),]

sapply(gen16,class)

#This county wasn't labeled in the data, so we manually assigned it the county name
for (i in seq(nrow(gen16))){
  if (gen16$fips[i] == "46102") gen16$county[i] <- "Oglala Lakota County"
}

#Creating a separate table with just the state-wide results
gen16.states <- gen16[is.na(gen16$county),]
gen16.states <- gen16.states[-c(103,104),] #removing state FIPS for Alaska
gen16.states$county <- NULL
gen16.states$fips <- NULL

gen16 <- gen16[-is.na(gen16$county)]

#Removing the statewide results from the county data
for (i in seq(nrow(gen16))) {
  if (nchar(gen16$fips[i])<=2) gen16$fips[i] <- NA
}

gen16 <- gen16[-which(is.na(gen16$fips)),]
gen16$pct_report <- NULL
gen16.2 <- gen16

gen16.2$votes <- NULL
gen16.2$lead <- NULL

#Used the reshape2 package to convert the dataframe from long to wide format
long16 <- dcast(gen16.2, fips + st + total_votes ~ cand, value.var = "pct")
colnames(long16) <- c("fips", "st", "total_votes", "DonaldTrump", "HillaryClinton")
long16$diff <- long16$DonaldTrump - long16$HillaryClinton

#Added an extra leading 0 for FIPS codes that were 4 digits long (enables the merge later)
for (i in seq(nrow(long16))) {
  if (nchar(long16$fips[i])==4) long16$fips[i] <- paste("0",long16$fips[i], sep="")
}

long16$TrumpWin <- ifelse(long16$diff >0, long16$TrumpWin <- 1, long16$TrumpWin <- 0)
long16$TrumpWin <- as.factor(long16$TrumpWin)

####Cleaning FIPS database####
fips.labels$fips <- paste(fips.labels$V2,fips.labels$V3, sep = "")
fips.labels$V2 <- NULL
fips.labels$V3 <- NULL
fips.labels$V5 <- NULL
colnames(fips.labels) <- c("State", "County", "FIPS")

####Merge FIPS database with 2016 election results####
long16 <- merge(long16, fips.labels[-1], by.x = "fips", by.y = "FIPS", all.x = TRUE)

####2012 General Election Data####
#Data import
all_counties_2012 <- read.csv("~/Second Year/DS 4559 - Data Science/Final Project/election2016/Data/2012data/all_counties_2012.csv",
                              stringsAsFactors = FALSE)

all_counties_2012 <- subset(all_counties_2012, fips!="fips")
#case insensitive search for rows containing obama or romney
all_counties_2012_romney <- all_counties_2012[grepl('romney',all_counties_2012$candidate,ignore.case=TRUE), ] 
all_counties_2012_obama <- all_counties_2012[grepl('obama',all_counties_2012$candidate,ignore.case=TRUE), ] 
#aggregate the double-counted fips codes
all_counties_2012_obama <- aggregate (. ~ fips, data=all_counties_2012_obama, FUN=sum)
all_counties_2012_romney <- aggregate (. ~ fips, data=all_counties_2012_romney, FUN=sum)

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
summary(all_counties_2012$candidate)

all_counties_2012 <- data.frame(lapply(all_counties_2012, as.character), stringsAsFactors=TRUE)
summary(all_counties_2012)

#Remove counties--will add back later with the fips.labels dataframe
all_counties_2012$county <- NULL

#Remove items with a blank FIPS code
all_counties_2012 <- all_counties_2012[-which(all_counties_2012$fips == ""),]
all_counties_2012.2 <- sqldf("select distinct fips, candidate from all_counties_2012")

#Convert data from wide to long
long12 <- dcast(all_counties_2012, fips ~ candidate, value.var = "votes")

####Map Generation####
#Virginia
#Pull county information
counties <- counties("VA")

#Merge map file with election results based on FIPS code
df_merged <- geo_join(counties, long16, "GEOID", "fips")

#Determine color gradient for the map
pal <- colorNumeric(
  palette = c("blue", "red"),
  domain = df_merged$percent
)

#Determine the content of the pop-up on mouse click
popup <- paste0("<b>", paste(df_merged$County, df_merged$st, sep = ", "), "</b> <br>",
                #"<b>FIPS Code: </b>", df_merged$GEOID, "<br>", 
                "<b>Trump Differential: </b>", percent(round(df_merged$diff,2)),
                "<br>", "<b>Trump: </b>", percent(round(df_merged$DonaldTrump,2)), " (",trimws(format(round(df_merged$DonaldTrump*df_merged$total_votes, 0), big.mark = ",")), ")",
                "<br>", "<b>Clinton: </b>", percent(round(df_merged$HillaryClinton,2)), " (",trimws(format(round(df_merged$HillaryClinton*df_merged$total_votes, 0), big.mark = ",")), ")")

#Generate the interactive map with legend
leaflet() %>%
  addProviderTiles("CartoDB.Positron") %>%
  addPolygons(data = df_merged, 
              fillColor = ~pal(diff), 
              color = "#b2aeae",
              fillOpacity = 0.8, 
              weight = 1, 
              smoothFactor = 0.2,
              popup = popup) %>%
  addLegend(pal = pal, 
            values = df_merged$diff, 
            position = "bottomright", 
            title = "Donald Trump's Advantage",
            labFormat = labelFormat(suffix = "%", transform = function(x) 100 * x))

va.fortify <- fortify(counties, region = "GEOID")
va.fortify <- merge(va.fortify, long16, by.x = "id", by.y = "fips", all.x = TRUE)

ggplot() +
  geom_polygon(data = va.fortify, 
               aes(x = long, y = lat, group = group, fill = diff), 
               color = "black", size = 0.25) + 
  coord_map() + scale_fill_gradient(low = "blue", high = "red") + theme_map()

#Pennsylvania
counties2 <- counties("PA")
df_merged2 <- geo_join(counties2, long16, "GEOID", "fips")

pal <- colorNumeric(
  palette = c("blue", "red"),
  domain = df_merged2$percent
)

popup.pa <- paste0("<b>", paste(df_merged2$County, df_merged2$st, sep = ", "), "</b> <br>",
                   #"<b>FIPS Code: </b>", df_merged$GEOID, "<br>", 
                   "<b>Trump Differential: </b>", percent(round(df_merged2$diff,2)),
                   "<br>", "<b>Trump: </b>", percent(round(df_merged2$DonaldTrump,2)), " (",trimws(format(round(df_merged2$DonaldTrump*df_merged2$total_votes, 0), big.mark = ",")), ")",
                   "<br>", "<b>Clinton: </b>", percent(round(df_merged2$HillaryClinton,2)), " (",trimws(format(round(df_merged2$HillaryClinton*df_merged2$total_votes, 0), big.mark = ",")), ")")

leaflet() %>%
  addProviderTiles("CartoDB.Positron") %>%
  addPolygons(data = df_merged2, 
              fillColor = ~pal(diff), 
              color = "#b2aeae",
              fillOpacity = 0.8, 
              weight = 1, 
              smoothFactor = 0.2,
              popup = popup.pa) %>%
  addLegend(pal = pal, 
            values = df_merged2$diff, 
            position = "bottomright", 
            title = "Donald Trump's Advantage",
            labFormat = labelFormat(suffix = "%", transform = function(x) 100 * x))

#United States
#ggplot2
#Gradient
us.counties <- counties(c("AL", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME",
                          "MD", "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM", "NY", "NC", "ND", "OH", "OK", 
                          "OR", "PA", "RI", "SC", "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY"))

us.counties2 <- fortify(us.counties, region = "GEOID")
df_merged.us <- merge(us.counties2, long16, by.x = "id", by.y = "fips", all.x = TRUE)

us.ggmap <- ggplot() +
  geom_polygon(data = df_merged.us, aes(x = long, y = lat, group = group, fill = diff), color = "dark grey", size = 0.25) + 
  scale_fill_gradient(low = "blue", high = "red") + labs(fill = "Trump Margin of Victory")+
  ggtitle("2016 Electoral Map by County") + coord_map("polyconic") + theme_void() 
ggsave(us.ggmap, file="C:/Users/Nathan/OneDrive/OneDrive Documents/Second Year/DS 4559 - Data Science/Final Project/election2016/USMAP.png",
       width = 22.92, height = 11.46, dpi = 400)

#Straight Win-Loss
us.ggmap2 <- ggplot() +
  geom_polygon(data = df_merged.us, aes(x = long, y = lat, group = group, fill = TrumpWin), color = "dark grey", size = 0.25) +
  scale_fill_manual(values = c("blue","red"), labels=c("Clinton", "Trump"),name="County Winner") + 
  ggtitle("2016 Electoral Map by County") + coord_map("polyconic") + theme_void() 
ggsave(us.ggmap2, file="C:/Users/Nathan/OneDrive/OneDrive Documents/Second Year/DS 4559 - Data Science/Final Project/election2016/USMAP2.png",
       width = 22.92, height = 11.46, dpi = 400)

#leaflet
df_merged.us2 <- geo_join(us.counties, long16, "GEOID", "fips")

pal <- colorNumeric(
  palette = c("blue", "red"),
  domain = df_merged.us2$percent
)

popup.us <- paste0("<b>", paste(df_merged.us2$County, df_merged.us2$st, sep = ", "), "</b> <br>",
                   #"<b>FIPS Code: </b>", df_merged$GEOID, "<br>", 
                   "<b>Trump Differential: </b>", percent(round(df_merged.us2$diff,2)),
                   "<br>", "<b>Trump: </b>", percent(round(df_merged.us2$DonaldTrump,2)), " (",trimws(format(round(df_merged.us2$DonaldTrump*df_merged.us2$total_votes, 0), big.mark = ",")), ")",
                   "<br>", "<b>Clinton: </b>", percent(round(df_merged.us2$HillaryClinton,2)), " (",trimws(format(round(df_merged.us2$HillaryClinton*df_merged.us2$total_votes, 0), big.mark = ",")), ")")

leaflet() %>%
  addProviderTiles("CartoDB.Positron") %>%
  addPolygons(data = df_merged.us2, 
              fillColor = ~pal(diff), 
              color = "#b2aeae",
              fillOpacity = 0.8, 
              weight = 1, 
              smoothFactor = 0.2,
              popup = popup.us) %>%
  addLegend(pal = pal, 
            values = df_merged.us2$diff, 
            position = "bottomright", 
            title = "Donald Trump's Advantage",
            labFormat = labelFormat(suffix = "%", transform = function(x) 100 * x))