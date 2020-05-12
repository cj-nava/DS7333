

# read data
txt = readLines("http://www.rdatasciencecases.org/Data/offline.final.trace.txt")

str(txt)
txt[1:6]

# remove comments
txt[-c(1,2,3)] -> txtclean
txtclean[1:5]


# split on ;

txtvector <- txtclean[[1]] %>% strsplit(., ";") %>% unlist() %>% strsplit(., "=") %>% unlist() %>% strsplit(., ",")  %>% unlist()
# alternate
strsplit(txtclean, "[;=,]")[[1]]





processLine = function(x)
{
  tokens = strsplit(x, "[;=,]")[[1]]
  if (length(tokens) == 10){
    return(NULL)
  }
  tmp = matrix(tokens[ - (1:10) ], , 4, byrow = TRUE)
  cbind(matrix(tokens[c(2, 4, 6:8, 10)], nrow(tmp), 6, byrow = TRUE), 
  tmp)
}


# ignore comments
lines = txt[ substr(txt, 1, 1) != "#" ]

# how many NON-comment lines in txt
sum(substr(txt, 1, 1) )


str(lines)
lines[1:6]

# tokenize each line using processLine() function
tmp = lapply(lines, processLine)
# bind to data frame
offline.df = as.data.frame(do.call("rbind", tmp),stringsAsFactors = FALSE)
# add headers
names(offline.df) = c("time", "scanMac", "posX", "posY", "posZ", "orientation", "mac", "signal", "channel", "type")


# verify
head(offline.df,20)



### DATA CLEANING

# note that all attibutes are strings
str(offline.df)

# convert signal to numeric
as.numeric(offline.df$signal) -> offline.df$signal

# convert posX to numeric
as.numeric(offline.df$posX) -> offline.df$posX

# convert posY to numeric
as.numeric(offline.df$posY) -> offline.df$posY

# convert posZ to numeric
as.numeric(offline.df$posZ) -> offline.df$posZ

# convert time to numeric
as.numeric(offline.df$orientation) -> offline.df$orientation

# convert time to numeric
as.numeric(offline.df$time) -> offline.df$time

#convert time to POSIX time
offline.df$time <- (offline.df$time/1000)
class(offline.df$time)= c("POSIXt", "POSIXct")

# verify
str(offline.df)
lapply(offline.df, class)


# convert mac, scanMac, and signal to factor
sapply(offline.df[,c('mac','scanMac','type','channel')], as.factor)

as.factor(offline.df$mac) -> offline.df$mac
as.factor(offline.df$scanMac) -> offline.df$scanMac
as.factor(offline.df$type) -> offline.df$type
as.factor(offline.df$channel) -> offline.df$channel


# verify
str(offline.df)
lapply(offline.df, class)

#verify all posZ values are 0
offline[offline['posZ']!='0.0',]


#remove posZ and scanMac
offline.df %>% dplyr::select(-c(posZ, scanMac) )  -> offline.df

#remove all *adhoc* signals of type 1
offline.df[offline.df$type != 1,] -> offline.df

# verify no type 1 left in data
summary(offline.df$type)

# remove type now
offline.df %>% dplyr::select(-type )  -> offline.df

# do all AP MACs appear same number of times
table(offline.df$mac) 


barplot(
        (offline.df %>% count(mac))$n, 
        horiz = T,
        main = "Unique MAC Count",
        legend.text = (offline.df %>% count(mac))$mac,
        col = rainbow(length(unique(offline.df$mac)))
        )




# many more angles than the expected 8 angles of 45%
levels(as.factor(offline.df$orientation))


# function to round angles to 45 degrees
roundOrientation = function(angles) {
  refs = seq(0, by = 45, length  = 9)
  q = sapply(angles, function(o) which.min(abs(o - refs)))
  c(refs[1:8], 0)[q]
}

# output to new parameter "angle" to compare and validate
offline.df$angle <- roundOrientation(offline.df$orientation)

levels(as.factor(offline.df$angle))
table(as.factor(offline.df$angle))


with(
  offline.df, boxplot(
    orientation ~ angle, 
    xlab = "angle approxmiation", 
    ylab = "orientation")
)


