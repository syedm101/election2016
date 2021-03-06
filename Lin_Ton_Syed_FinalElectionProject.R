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
library(rgdal)
library(rgeos)
library(sqldf)

####General Notes####
# Use the section-picker at the bottom of the script window to jump between code sections
# Our analysis only considered the lower 48 states and the District of Columbia (excluded Alaska, Hawaii and overseas territories)
# The tigris data requires the below global option if you are running Windows 10
options(tigris_use_cache = FALSE)

#Set your working directory to the top level of the project folder. All paths in the code below are relative

####2016 General Election Data####
#Read the 2016 general election data + FIPS code database
gen16 <- read.csv("Data/pres16results.csv", header = TRUE, stringsAsFactors = FALSE)
fips.labels <- read.csv("Data/fips_database.csv", header = FALSE, stringsAsFactors = FALSE, colClasses = "character")

#Cleaning general election data
#Removed third parties
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
gen16.states$county <- NULL #Removed county info from the states df
gen16.states$fips <- NULL #Removed generic fips info from the states df

gen16 <- gen16[-is.na(gen16$county)] #Removed items that did not have county info

#Removing the statewide results from the county data
for (i in seq(nrow(gen16))) {
  if (nchar(gen16$fips[i])<=2) gen16$fips[i] <- NA
}

#Removed items that did not have a FIPS code
gen16 <- gen16[-which(is.na(gen16$fips)),]

#Removed additional columns of unnecessary data
gen16$pct_report <- NULL
gen16.2 <- gen16

gen16.2$votes <- NULL
gen16.2$lead <- NULL

#Used the reshape2 package to convert the dataframe from long to wide format
long16 <- dcast(gen16.2, fips + st + total_votes ~ cand, value.var = "pct")
colnames(long16) <- c("fips", "st", "total_votes", "DonaldTrump", "HillaryClinton")

#Created a difference column with Trump votes over Clinton votes
long16$diff <- long16$DonaldTrump - long16$HillaryClinton

#Added an extra leading 0 for FIPS codes that were 4 digits long (enables the merge later)
for (i in seq(nrow(long16))) {
  if (nchar(long16$fips[i])==4) long16$fips[i] <- paste("0",long16$fips[i], sep="")
}

#Created a flag variable with 1 for a Trump win and 0 for a Clinton win
long16$TrumpWin <- ifelse(long16$diff >0, long16$TrumpWin <- 1, long16$TrumpWin <- 0)

#Set the flag variable as a factor to enable discrete scales for ggplot2
long16$TrumpWin <- as.factor(long16$TrumpWin)

####Cleaning FIPS database####
#Concatenating state and county fips codes to form the five digit fips code
fips.labels$fips <- paste(fips.labels$V2,fips.labels$V3, sep = "")

#Removed unnecessary columns
fips.labels$V2 <- NULL
fips.labels$V3 <- NULL
fips.labels$V5 <- NULL
colnames(fips.labels) <- c("State", "County", "FIPS")

####Merge FIPS database with 2016 election results####
long16 <- merge(long16, fips.labels[-1], by.x = "fips", by.y = "FIPS", all.x = TRUE)

#Store Clinton and Trump results seperately
gen16_clinton <- gen16[grepl('clinton', gen16$cand, ignore.case=TRUE),]
gen16_trump <- gen16[grepl('trump', gen16$cand, ignore.case=TRUE),]

####2012 General Election Data####
#Data import
all_counties_2012 <- read.csv("Data/2012data/all_counties_2012.csv",
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

for (i in seq(nrow(long12))){
  if (long12$fips[i] == "46113") long12$fips[i] <- "46102"
}

long12$diff <- long12$obama - long12$romney

long12$ObamaWin <- ifelse(long12$diff >0, long12$ObamaWin <- 1, long12$ObamaWin <- 0)
long12$ObamaWin <- as.factor(long12$ObamaWin)

#Note that the percentages calculated do not take into account third-party votes (marginal)
long12$ObamaPer <- long12$obama/(long12$obama + long12$romney)
long12$RomneyPer <- long12$romney/(long12$obama + long12$romney)
long12$diffper <- long12$ObamaPer - long12$RomneyPer

long12 <- merge(long12, fips.labels, by.x = "fips", by.y = "FIPS", all.x = TRUE)

####Lower 48 State US Geographic Data####
#Obtain the geolocation data for US counties in Spatial Polygon form (used for leaflet)
us.counties <- counties(c("AL", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME",
                          "MD", "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM", "NY", "NC", "ND", "OH", "OK", 
                          "OR", "PA", "RI", "SC", "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY"), cb = TRUE)

#Fortify the spacial polygon to convert to dataframe format (for ggplot2)
us.counties2 <- fortify(us.counties, region = "GEOID")

#Obtained state boundaries so we can overlay a white boundary/outline over the US map
us.states <- states(cb = TRUE)
us.states2 <- fortify(us.states, region = "GEOID")
#Limited the state dataframe to exclude areas outside the 48 states (territories, AK, HI)
us.states3 <- us.states2[which(us.states2$lat >= 24.396308 & us.states2$lat <= 49.384358 & us.states2$long >= -124.848974 & us.states2$long <= -66.885444),]

####2016 Map Generation####
#Virginia
#Pull county information
counties <- counties("VA", cb = TRUE)

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

#Pennsylvania
counties2 <- counties("PA", cb = TRUE)
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
#For the fill information for the graphs, merge the fortified spacial data with 2016 vote to enable fills/gradients
df_merged.us <- merge(us.counties2, long16, by.x = "id", by.y = "fips", all.x = TRUE)

#Gradient Map of Margin of Victory with ggplot2
us.ggmap <- ggplot() +
  geom_polygon(data = df_merged.us, aes(x = long, y = lat, group = group, fill = diff), color = "dark grey", size = 0.25) + 
  geom_path(data = us.states3, aes(x=long, y=lat, group =group), color = "white") +
  scale_fill_gradient(low = "blue", high = "red") + labs(fill = "Trump Margin of Victory")+
  ggtitle("2016 Electoral Map by County") + coord_map("polyconic") + theme_void() 
#Using ggsave to save the generated map to the disk
ggsave(us.ggmap, file="Graphics/USMAP.png",
       width = 22.92, height = 11.46, dpi = 400)

#Straight Win-Loss
us.ggmap2 <- ggplot() +
  geom_polygon(data = df_merged.us, aes(x = long, y = lat, group = group, fill = TrumpWin), color = "dark grey", size = 0.25) +
  geom_path(data = us.states3, aes(x=long, y=lat, group =group), color = "white") +
  scale_fill_manual(values = c("blue","red"), labels=c("Clinton", "Trump"),name="County Winner") + 
  ggtitle("2016 Electoral Map by County") + coord_map("polyconic") + theme_void() 
ggsave(us.ggmap2, file="Graphics/USMAP2.png",
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
  addPolygons(data = us.states, 
              color = "#ffffff",
              fillOpacity = 0, 
              weight = 1, 
              smoothFactor = 0.2, options = pathOptions(clickable = FALSE)) %>%
  addLegend(pal = pal, 
            values = df_merged.us2$diff, 
            position = "bottomright", 
            title = "Donald Trump's Advantage",
            labFormat = labelFormat(suffix = "%", transform = function(x) 100 * x)) %>%
  fitBounds(-124.848974, 24.396308, -66.885444, 49.384358)

####2012 Map Generation####
#Created the 2012 dataframe by merging US map data with the 2012 results based on FIPS code
df_merged.us12 <- merge(us.counties2, long12, by.x = "id", by.y = "fips", all.x = TRUE)

#Gradient of map indicating margin of victory
us.ggmap12 <- ggplot() +
  geom_polygon(data = df_merged.us12, aes(x = long, y = lat, group = group, fill = diffper), color = "dark grey", size = 0.25) +
  geom_path(data = us.states3, aes(x=long, y=lat, group =group), color = "white") +
  scale_fill_gradient(low = "red", high = "blue") + labs(fill = "Obama Margin of Victory")+
  ggtitle("2012 Electoral Map by County") + coord_map("polyconic") + theme_void() 
ggsave(us.ggmap12, file="Graphics/USMAP6.png",
       width = 22.92, height = 11.46, dpi = 400)

#Strict win-loss map
us.ggmap2.12 <- ggplot() +
  geom_polygon(data = df_merged.us12, aes(x = long, y = lat, group = group, fill = ObamaWin), color = "dark grey", size = 0.25) +
  geom_path(data = us.states3, aes(x=long, y=lat, group =group), color = "white") +
  scale_fill_manual(values = c("red","blue"), labels=c("Romney", "Obama"),name="County Winner") + 
  ggtitle("2012 Electoral Map by County") + coord_map("polyconic") + theme_void() 
ggsave(us.ggmap2.12, file="Graphics/USMAP3.png",
       width = 22.92, height = 11.46, dpi = 400)

####2012-2016 Differences####
#Counties Obama Won and Clinton Lost
#Create a new dataframe merging 2012 and 2016 data to facilitate comparisons
diff.1216 <- merge(long12[1:5], long16[c(1,2,3,4,5,7,8)], by = "fips")

#Calculated Clinton and Trump votes by multiplying their percentages by the total votes cast
diff.1216$trump <- diff.1216$total_votes*diff.1216$DonaldTrump
diff.1216$clinton <- diff.1216$total_votes*diff.1216$HillaryClinton

#Removed unnecessary columns (Obama-Romney difference, 2016 total votes and percentages)
diff.1216[c(4,7:9)] <- NULL

#Rearranged columns
diff.1216 <- diff.1216[c(1,5, 7,2,3,4,6,8,9)]

#Created a flag variable indicating if flips happened either way
diff.1216$flip <- ifelse(diff.1216$ObamaWin == 1 & diff.1216$TrumpWin==1, 2, 
                         ifelse(diff.1216$ObamaWin == 0 & diff.1216$TrumpWin==0, 3, 
                                ifelse(diff.1216$TrumpWin==1, 1, 0)))
#Factored this flip variable to enable graphing in ggplot
diff.1216$flip <- as.factor(diff.1216$flip)

#Created another flag variable to facilitate comparisons between Trump and Obama
diff.1216$obama_trump <- ifelse(diff.1216$obama > diff.1216$trump, 1, 0)
diff.1216$obama_trump <- as.factor(diff.1216$obama_trump)

#How many counties did each candidate flip?
length(which(diff.1216$flip == 2)) #Donald Trump flipped 223 counties that Barack Obama won in 2012
length(which(diff.1216$flip == 3)) #Hillary Clinton flipped 17 counties that Mitt Romney won in 2012

#Flips by county
#Using a SQL query to aggregate the number of county flips by candidate for each state
flipped.counties.trump <- sqldf("select st, count(st) from 'diff.1216' where flip == 2 group by st")
colnames(flipped.counties.trump) <- c("State", "Counties Flipped")
flipped.counties.trump <- flipped.counties.trump[order(flipped.counties.trump$`Counties Flipped`, decreasing = TRUE),]
flipped.counties.trump <- rbind(flipped.counties.trump, c("Total", sum(flipped.counties.trump$'Counties Flipped')))

flipped.counties.clinton <- sqldf("select st, count(st) from 'diff.1216' where flip == 3 group by st")
colnames(flipped.counties.clinton) <- c("State", "Counties Flipped")
flipped.counties.clinton <- flipped.counties.clinton[order(flipped.counties.clinton$`Counties Flipped`, decreasing = TRUE),]
flipped.counties.clinton <- rbind(flipped.counties.clinton, c("Total", sum(flipped.counties.clinton$'Counties Flipped')))

####Graphing 2012-2016 Differences####
#Merging US map data with 2012-2016 combined data to facilitate comparisons
df_merged.us2.12 <- merge(us.counties2, diff.1216[c(1,2,3,10,11)], by.x = "id", by.y = "fips", all.x = TRUE)

#Colored map with flips in yellow and green
us.ggmap.1216 <- ggplot() +
  geom_polygon(data = df_merged.us2.12, aes(x = long, y = lat, group = group, fill = flip), color = "dark grey", size = 0.25) +
  geom_path(data = us.states3, aes(x=long, y=lat, group =group), color = "white") +
  scale_fill_manual(values = c("blue","red", "yellow", "green"), 
                    labels=c("Clinton","Trump", "Trump Flip", "Clinton Flip"),name="County Winner") + 
  ggtitle("2012 Electoral Map by County, Flips") + coord_map("polyconic") + theme_void() 
ggsave(us.ggmap.1216, file="Graphics/USMAP4.png",
       width = 22.92, height = 11.46, dpi = 400)

#Gray for states that didn't flip and red/blue to clearly highlight the flips
us.ggmap.1216.2 <- ggplot() +
  geom_polygon(data = df_merged.us2.12, aes(x = long, y = lat, group = group, fill = flip), color = "dark grey", size = 0.25) +
  geom_path(data = us.states3, aes(x=long, y=lat, group =group), color = "white") +
  scale_fill_manual(values = c("gray","gray", "red", "blue"), 
                    labels=c("Clinton","Trump", "Trump Flip", "Clinton Flip"),name="County Winner") + 
  ggtitle("2012 Electoral Map by County, Flips") + coord_map("polyconic") + theme_void() 
ggsave(us.ggmap.1216.2, file="Graphics/USMAP5.png",
       width = 22.92, height = 11.46, dpi = 400)

#Interactive Maps -- made for the Northeast and Midwest (same procedure as above for leaflet maps)
#Maine and New York, flipped
co.diff <- diff.1216
co.diff$co.diff <- co.diff$obama - co.diff$clinton
co.diff$co.diff2 <- co.diff$obama - co.diff$trump

counties.ME.NY <- counties(state = c("ME","NY"), cb = TRUE)

df_merged.ME.NY <- geo_join(counties.ME.NY, co.diff, "GEOID", "fips")

pal.ME.NY <- colorBin("Blues", df_merged.ME.NY$co.diff, 8, pretty = FALSE)

popup.ME.NY <- paste0("<b>", paste(df_merged.ME.NY$County, df_merged.ME.NY$st, sep = ", "), "</b> <br>",
                   #"<b>FIPS Code: </b>", df_merged$GEOID, "<br>", 
                   "<b>Obama Differential: </b>", format(round(df_merged.ME.NY$co.diff,0), big.mark = ","),
                   "<br>", "<b>Obama: </b>",trimws(format(round(df_merged.ME.NY$obama, 0), big.mark = ",")),
                   "<br>", "<b>Clinton: </b>", trimws(format(round(df_merged.ME.NY$clinton, 0), big.mark = ",")),
                   "<br>", "<b>Trump: </b>", trimws(format(round(df_merged.ME.NY$trump, 0), big.mark = ",")))

leaflet() %>%
  addProviderTiles("CartoDB.Positron") %>%
  addPolygons(data = df_merged.ME.NY, 
              fillColor = ~pal.ME.NY(co.diff), 
              color = "#b2aeae",
              fillOpacity = 0.8, 
              weight = 1, 
              smoothFactor = 0.2,
              popup = popup.ME.NY) %>%
  addLegend(pal = pal.ME.NY, 
            values = df_merged.ME.NY$co.diff, 
            position = "bottomright", 
            title = "Obama-Clinton Vote Differential (+ favors Obama)")

#In NY and ME, how would Obama fare against Trump?
pal.ME.NY2 <- colorBin("Reds", df_merged.ME.NY$co.diff2, 8, pretty = FALSE)

popup.ME.NY2 <- paste0("<b>", paste(df_merged.ME.NY$County, df_merged.ME.NY$st, sep = ", "), "</b> <br>",
                      #"<b>FIPS Code: </b>", df_merged$GEOID, "<br>", 
                      "<b>Obama Differential: </b>", format(round(df_merged.ME.NY$co.diff2,0), big.mark = ","),
                      "<br>", "<b>Obama: </b>",trimws(format(round(df_merged.ME.NY$obama, 0), big.mark = ",")),
                      "<br>", "<b>Trump: </b>", trimws(format(round(df_merged.ME.NY$trump, 0), big.mark = ",")),
                      "<br>", "<b>Clinton: </b>", trimws(format(round(df_merged.ME.NY$clinton, 0), big.mark = ",")))

leaflet() %>%
  addProviderTiles("CartoDB.Positron") %>%
  addPolygons(data = df_merged.ME.NY, 
              fillColor = ~pal.ME.NY2(co.diff2), 
              color = "#b2aeae",
              fillOpacity = 0.8, 
              weight = 1, 
              smoothFactor = 0.2,
              popup = popup.ME.NY2) %>%
  addLegend(pal = pal.ME.NY2, 
            values = df_merged.ME.NY$co.diff2, 
            position = "bottomright", 
            title = "Obama-Trump Vote Differential (+ favors Obama)")

#Midwest
counties.midwest <- counties(state = c("MN","MI", "WI", "IA", "IL"), cb = TRUE)
df_merged.midwest <- geo_join(counties.midwest, co.diff, "GEOID", "fips")

pal.midwest <- colorBin("Blues", df_merged.midwest$co.diff, 8, pretty = FALSE)

popup.midwest <- paste0("<b>", paste(df_merged.midwest$County, df_merged.midwest$st, sep = ", "), "</b> <br>",
                     #"<b>FIPS Code: </b>", df_merged$GEOID, "<br>", 
                     "<b>Obama Differential: </b>", format(round(df_merged.midwest$co.diff,0), big.mark = ","),
                     "<br>", "<b>Obama: </b>",trimws(format(round(df_merged.midwest$obama, 0), big.mark = ",")),
                     "<br>", "<b>Clinton: </b>", trimws(format(round(df_merged.midwest$clinton, 0), big.mark = ",")),
                     "<br>", "<b>Trump: </b>", trimws(format(round(df_merged.midwest$trump, 0), big.mark = ",")))

leaflet() %>%
  addProviderTiles("CartoDB.Positron") %>%
  addPolygons(data = df_merged.midwest, 
              fillColor = ~pal.midwest(co.diff), 
              color = "#b2aeae",
              fillOpacity = 0.8, 
              weight = 1, 
              smoothFactor = 0.2,
              popup = popup.midwest) %>%
  addLegend(pal = pal.midwest, 
            values = df_merged.midwest$co.diff, 
            position = "bottomright", 
            title = "Obama-Clinton Vote Differential (+ favors Obama)")

#How would Obama have done against Trump in the midwest?
pal.midwest2 <- colorBin("Reds", df_merged.midwest$co.diff2, 8, pretty = FALSE)

popup.midwest2 <- paste0("<b>", paste(df_merged.midwest$County, df_merged.midwest$st, sep = ", "), "</b> <br>",
                       #"<b>FIPS Code: </b>", df_merged$GEOID, "<br>", 
                       "<b>Obama Differential: </b>", format(round(df_merged.midwest$co.diff2,0), big.mark = ","),
                       "<br>", "<b>Obama: </b>",trimws(format(round(df_merged.midwest$obama, 0), big.mark = ",")),
                       "<br>", "<b>Trump: </b>", trimws(format(round(df_merged.midwest$trump, 0), big.mark = ",")),
                       "<br>", "<b>Clinton: </b>", trimws(format(round(df_merged.midwest$clinton, 0), big.mark = ",")))

leaflet() %>%
  addProviderTiles("CartoDB.Positron") %>%
  addPolygons(data = df_merged.midwest, 
              fillColor = ~pal.midwest2(co.diff2), 
              color = "#b2aeae",
              fillOpacity = 0.8, 
              weight = 1, 
              smoothFactor = 0.2,
              popup = popup.midwest2) %>%
  addLegend(pal = pal.ME.NY2, 
            values = df_merged.midwest$co.diff2, 
            position = "bottomright", 
            title = "Obama-Trump Vote Differential (+ favors Obama)")

####2012-2016 Turnout Comparisons####
#Create a vote.diff dataframe with just vote numbers for Clinton, Trump, Obama, and Romney
vote.diff <- diff.1216[,c(1,2,3,4,5,8,9)]

#Calculate turnout differences in 2016
vote.diff$sum2012 <- vote.diff$obama + vote.diff$romney
vote.diff$sum2016 <- vote.diff$clinton + vote.diff$trump
vote.diff$change1216 <- vote.diff$sum2016 - vote.diff$sum2012

#Turnout differences in just the party
vote.diff$demchange <- vote.diff$clinton - vote.diff$obama
vote.diff$repchange <- vote.diff$trump - vote.diff$romney

#Merge the turnout differences with US map data
df_merged.turnout <- merge(us.counties2, vote.diff, by.x = "id", by.y = "fips", all.x = TRUE)

#2012-2016 Total Turnout graph
us.ggmap.turnout1216 <- ggplot() +
  geom_polygon(data = df_merged.turnout, aes(x = long, y = lat, group = group, fill = change1216), color = "dark grey", size = 0.25) +
  geom_path(data = us.states3, aes(x=long, y=lat, group =group), color = "white") +
  scale_fill_distiller(palette = "Paired", guide = "colourbar", name = "Changes in Votes from 2012 to 2016") + 
  ggtitle("2012-2016 Turnout Differences") + coord_map("polyconic") + theme_void() 
ggsave(us.ggmap.turnout1216, file="Graphics/USMAP8.png",
       width = 22.92, height = 11.46, dpi = 400)

#Republican Turnout Changes
us.ggmap.turnoutrep <- ggplot() +
  geom_polygon(data = df_merged.turnout, aes(x = long, y = lat, group = group, fill = repchange), color = "dark grey", size = 0.25) +
  geom_path(data = us.states3, aes(x=long, y=lat, group =group), color = "white") +
  scale_fill_distiller(palette = "Paired", guide = "colourbar", name = "Changes in Votes from 2012 to 2016",
                       limits = c(min(df_merged.turnout$repchange, df_merged.turnout$demchange), 
                                  max(df_merged.turnout$repchange, df_merged.turnout$demchange))) + 
  ggtitle("2012-2016 Turnout Differences, Republican Party") + coord_map("polyconic") + theme_void() 

#Democrat Turnout Changes
us.ggmap.turnoutdem <- ggplot() +
  geom_polygon(data = df_merged.turnout, aes(x = long, y = lat, group = group, fill = demchange), color = "dark grey", size = 0.25) +
  geom_path(data = us.states3, aes(x=long, y=lat, group =group), color = "white") +
  scale_fill_distiller(palette = "Paired", guide = "colourbar", name = "Changes in Votes from 2012 to 2016",
                       limits = c(min(df_merged.turnout$repchange, df_merged.turnout$demchange), 
                                  max(df_merged.turnout$repchange, df_merged.turnout$demchange))) + 
  ggtitle("2012-2016 Turnout Differences, Democratic Party") + coord_map("polyconic") + theme_void() 

####Obama-Trump Matchup####
#What would happen if Obama ran against Trump given their prior performance?
us.ggmap.obamatrump <- ggplot() +
  geom_polygon(data = df_merged.us2.12, aes(x = long, y = lat, group = group, fill = obama_trump), color = "dark grey", size = 0.25) +
  geom_path(data = us.states3, aes(x=long, y=lat, group =group), color = "white") +
  scale_fill_manual(values = c("red","blue"), 
                    labels=c("Trump","Obama"),name="County Winner") + 
  ggtitle("Obama-Trump Hypothetical Matchup") + coord_map("polyconic") + theme_void() 
ggsave(us.ggmap.obamatrump, file="Graphics/USMAP7.png",
       width = 22.92, height = 11.46, dpi = 400)
