

# read data
txt = readLines("http://www.rdatasciencecases.org/Data/offline.final.trace.txt")

str(txt)
txt[1:6]

# remove comments
txt[-c(1,2,3)] -> txtclean
txtclean[1:5]


# split on ; and - and '

txtvector <- txtclean[[1]] %>% strsplit(., ";") %>% unlist() %>% strsplit(., "=") %>% unlist() %>% strsplit(., ",")  %>% unlist()
# alternate
txtvector <-  strsplit(txtclean, "[;=,]")[[1]]





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
table(substr(txt, 1, 1))


str(lines)
lines[1:6]

# tokenize each line using processLine() function
tempdf = lapply(lines, processLine)
# bind to data frame
offline.df = as.data.frame(do.call("rbind", tempdf),stringsAsFactors = FALSE)
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

# covnert type to numeric
as.numeric(offline.df$type) -> offline.df$type

#convert time to POSIX time
offline.df$time <- (offline.df$time/1000)
class(offline.df$time)= c("POSIXt", "POSIXct")

# verify
str(offline.df)
lapply(offline.df, class)


# convert mac, scanMac, and signal to factor
sapply(offline.df[,c('mac','scanMac', 'channel')], as.factor)

as.factor(offline.df$mac) -> offline.df$mac
as.factor(offline.df$scanMac) -> offline.df$scanMac
#as.factor(offline.df$type) -> offline.df$type
as.factor(offline.df$channel) -> offline.df$channel



# verify
str(offline.df)
lapply(offline.df, class)

#remove all *adhoc* signals of type 1
#this removes the suspect MAC from other sources or floors
offline.df[offline.df$type != 1,] -> offline.df
# remove type now
offline.df %>% dplyr::select(-type )  -> offline.df

#verify all posZ values are 0
# thus can remove
offline.df[offline.df['posZ']!='0.0',]

#examine posZ, scanMac, channel, and mac
offline.df %>% dplyr::select(c(posZ, scanMac, channel, mac) ) %>% summary()


#remove posZ and scanMac
offline.df %>% dplyr::select(-c(posZ, scanMac) )  -> offline.df


# verify 
summary(offline.df)







# many more angles than the expected 8 angles of 45%
levels(as.factor(offline.df$orientation))

# Plot the orientation of the measurement device
plot (ecdf(offline.df$orientation))


# function to round angles to 45 degrees
roundOrientation = function(angles) {
  refs = seq(0, by = 45, length  = 9)
  q = sapply(angles, function(o) which.min(abs(o - refs)))
  c(refs[1:8], 0)[q]
}

# output to new parameter "angle" to compare and validate
offline.df$angle <- roundOrientation(offline.df$orientation)

# validate results
levels(as.factor(offline.df$angle))
table(as.factor(offline.df$angle))

# plot results
#NOTICE MAJOR OURLIER AT ANGLE 0
with(
  offline.df, boxplot(
    orientation ~ angle, 
    xlab = "angle approxmiation", 
    ylab = "orientation")
)



# number of unique MAC addresses
length(unique(offline.df$mac))

# do all AP MACs appear same number of times
pie(table(offline.df$mac)) 


barplot(
  (offline.df %>% count(mac))$n, 
  horiz = T,
  main = "Unique MAC Count",
  legend.text = (offline.df %>% count(mac))$mac,
  col = rainbow(length(unique(offline.df$mac)))
)


# Remove MAC addresses that have low counts
subMacs <- names(sort(table(offline.df$mac), decreasing = TRUE))[1:7]
offline.df <- offline.df[ offline.df$mac %in% subMacs, ]

# Eliminate channel from the data since it corresponds with MAC address exactly
offline.df %>% dplyr::select(-channel )  -> offline.df

#as.character(offline.df$mac) -> offline.df$mac
table(offline.df$mac)



# Create a dataframe with location and remove null values
locDF <- with(offline.df,
             by(offline.df, list(posX, posY), function(x) x)
             )
locDF <- locDF[ !sapply(locDF, is.null)]

# Create a dataframe with location counts at each position
# NOTE: appoximately 5500 recordings at each position
locCounts <- sapply(locDF, function(df) 
  c(df[1, c("posX", "posY")], count=nrow(df)))
locCounts[ ,1:10]




### ???? WHY
# Create matrix with AP (by MAC address) with locations on our grid system
AP <- matrix( c(7.5, 6.3, 2.5, -0.8, 12.8, -2.8, 1, 14, 33.5, 9.3, 33.5, 2.8), 
             ncol <- 2, byrow = TRUE, 
             dimnames <- list(subMacs[-2], c("x", "y") ))






### SIGNAL STRENGTH ###


# Create new combined position variable
offline.df$posXY <- paste(offline.df$posX, offline.df$posY, sep="-")
byLocAngleAP <- with(offline.df,
                    by (offline.df, list (posXY, angle, mac),
                        function(x) x))

# Create a summary of signal strength data
signalSummary <- 
  lapply(byLocAngleAP, 
         function(oneLoc) 
         {
           ans = oneLoc[1, ]
           ans$medSignal = median(oneLoc$signal)
           ans$avgSignal = mean(oneLoc$signal)
           ans$num = length(oneLoc$signal)
           ans$sdSignal = sd(oneLoc$signal)
           ans$iqrSignal = IQR(oneLoc$signal)
           ans
         }
        )

# Add signalSummary to the offlineSummary data
offlineSummary <- do.call("rbind", signalSummary)

# Remove the unwanted MAC address
offlineSummary <- subset(offlineSummary, mac != subMacs[2])  # removes dd:cd












### KNN ###

# Function to read the text file and process
readData = 
  function(filename = "http://www.rdatasciencecases.org/Data/offline.final.trace.txt", 
           subMacs = c("00:0f:a3:39:e1:c0", "00:0f:a3:39:dd:cd", "00:14:bf:b1:97:8a",
                       "00:14:bf:3b:c7:c6", "00:14:bf:b1:97:90", "00:14:bf:b1:97:8d",
                       "00:14:bf:b1:97:81"))
  {
    txt = readLines(filename)
    lines = txt[ substr(txt, 1, 1) != "#" ]
    tmp = lapply(lines, processLine)
    offline = as.data.frame(do.call("rbind", tmp), 
                            stringsAsFactors= FALSE) 
    
    names(offline) = c("time", "scanMac", 
                       "posX", "posY", "posZ", "orientation", 
                       "mac", "signal", "channel", "type")
    
    # keep only signals from access points
    offline = offline[ offline$type == "3", ]
    
    # drop scanMac, posZ, channel, and type
    dropVars = c("scanMac", "posZ", "channel", "type")
    offline = offline[ , !( names(offline) %in% dropVars ) ]
    
    # drop more unwanted access points
    offline = offline[ offline$mac %in% subMacs, ]
    
    # convert numeric values
    numVars = c("time", "posX", "posY", "orientation", "signal")
    offline[ numVars ] = lapply(offline[ numVars ], as.numeric)
    
    # convert time to POSIX
    offline$rawTime = offline$time
    offline$time = offline$time/1000
    class(offline$time) = c("POSIXt", "POSIXct")
    
    # round orientations to nearest 45 degree reference angle
    offline$angle = roundOrientation(offline$orientation)
    
    return(offline)
  }



# apply to ONLINE data
macs <- unique(offlineSummary$mac)
online <- readData("http://www.rdatasciencecases.org/Data/online.final.trace.txt", subMacs = macs)

online$posXY <- paste(online$posX, online$posY, sep = "-")

keepVars <- c("posXY", "posX","posY", "orientation", "angle")
byLoc <- with(online, 
             by(online, list(posXY), 
                function(x) {
                  ans = x[1, keepVars]
                  avgSS = tapply(x$signal, x$mac, mean)
                  y = matrix(avgSS, nrow = 1, ncol = 6,
                             dimnames = list(ans$posXY, names(avgSS)))
                  cbind(ans, y)
                }))

onlineSummary <- do.call("rbind", byLoc)  

names(onlineSummary)





### ORIENTATION ###

m = 3; angleNewObs = 230
refs = seq(0, by = 45, length  = 8)
nearestAngle = roundOrientation(angleNewObs)

if (m %% 2 == 1) {
  angles = seq(-45 * (m - 1) /2, 45 * (m - 1) /2, length = m)
} else {
  m = m + 1
  angles = seq(-45 * (m - 1) /2, 45 * (m - 1) /2, length = m)
  if (sign(angleNewObs - nearestAngle) > -1) 
    angles = angles[ -1 ]
  else 
    angles = angles[ -m ]
}
angles = angles + nearestAngle
angles[angles < 0] = angles[ angles < 0 ] + 360
angles[angles > 360] = angles[ angles > 360 ] - 360

offlineSubset = 
  offlineSummary[ offlineSummary$angle %in% angles, ]

reshapeSS = function(data, varSignal = "signal", 
                     keepVars = c("posXY", "posX","posY")) {
  byLocation =
    with(data, by(data, list(posXY), 
                  function(x) {
                    ans = x[1, keepVars]
                    avgSS = tapply(x[ , varSignal ], x$mac, mean)
                    y = matrix(avgSS, nrow = 1, ncol = 6,
                               dimnames = list(ans$posXY,
                                               names(avgSS)))
                    cbind(ans, y)
                  }))
  
  newDataSS = do.call("rbind", byLocation)
  return(newDataSS)
}

trainSS = reshapeSS(offlineSubset, varSignal = "avgSignal")

selectTrain = function(angleNewObs, signals = NULL, m = 1){
  # m is the number of angles to keep between 1 and 5
  refs = seq(0, by = 45, length  = 8)
  nearestAngle = roundOrientation(angleNewObs)
  
  if (m %% 2 == 1) 
    angles = seq(-45 * (m - 1) /2, 45 * (m - 1) /2, length = m)
  else {
    m = m + 1
    angles = seq(-45 * (m - 1) /2, 45 * (m - 1) /2, length = m)
    if (sign(angleNewObs - nearestAngle) > -1) 
      angles = angles[ -1 ]
    else 
      angles = angles[ -m ]
  }
  angles = angles + nearestAngle
  angles[angles < 0] = angles[ angles < 0 ] + 360
  angles[angles > 360] = angles[ angles > 360 ] - 360
  angles = sort(angles) 
  
  offlineSubset = signals[ signals$angle %in% angles, ]
  reshapeSS(offlineSubset, varSignal = "avgSignal")
}

train130 = selectTrain(130, offlineSummary, m = 3)

head(train130)








### PREDICT WITHOUT CD MAC ADDRESS ###

# KNN function
findNN = function(newSignal, trainSubset) {
  diffs = apply(trainSubset[ , 4:9], 1, 
                function(x) x - newSignal)
  dists = apply(diffs, 2, function(x) sqrt(sum(x^2)) )
  closest = order(dists)
  return(trainSubset[closest, 1:3 ])
}

predXY = function(newSignals, newAngles, trainData, 
                  numAngles = 1, k = 3){
  
  closeXY = list(length = nrow(newSignals))
  
  for (i in 1:nrow(newSignals)) {
    trainSS = selectTrain(newAngles[i], trainData, m = numAngles)
    closeXY[[i]] = 
      findNN(newSignal = as.numeric(newSignals[i, ]), trainSS)
  }
  
  estXY = lapply(closeXY, 
                 function(x) sapply(x[ , 2:3], 
                                    function(x) mean(x[1:k])))
  estXY = do.call("rbind", estXY)
  return(estXY)
}

estXYk1 = predXY(newSignals = onlineSummary[ , 6:11], 
                 newAngles = onlineSummary[ , 4], 
                 offlineSummary, numAngles = 3, k = 1)

estXYk3 = predXY(newSignals = onlineSummary[ , 6:11], 
                 newAngles = onlineSummary[ , 4], 
                 offlineSummary, numAngles = 3, k = 3)

estXYk5 = predXY(newSignals = onlineSummary[ , 6:11], 
                 newAngles = onlineSummary[ , 4], 
                 offlineSummary, numAngles = 3, k = 5)

estXYk7 = predXY(newSignals = onlineSummary[ , 6:11], 
                 newAngles = onlineSummary[ , 4], 
                 offlineSummary, numAngles = 3, k = 7)




### Error calculations
calcError = 
  function(estXY, actualXY) 
    sum( rowSums( (estXY - actualXY)^2) )

actualXY = onlineSummary[ , c("posX", "posY")]
sapply(list(estXYk7, estXYk5, estXYk3, estXYk1), calcError, actualXY)








### PREICTION WITHOUT C0 MAC ADDRESS

# Read offline data using the function call
offline = readData()

# Create new combined position variable
offline$posXY = paste(offline$posX, offline$posY, sep="-")
byLocAngleAP = with(offline,
                    by (offline, list (posXY, angle, mac),
                        function(x) x))

# Create a summary of signal strength data
signalSummary = 
  lapply(byLocAngleAP, 
         function(oneLoc) 
         {
           ans = oneLoc[1, ]
           ans$medSignal = median(oneLoc$signal)
           ans$avgSignal = mean(oneLoc$signal)
           ans$num = length(oneLoc$signal)
           ans$sdSignal = sd(oneLoc$signal)
           ans$iqrSignal = IQR(oneLoc$signal)
           ans
         })

# Add signalSummary to the offlineSummary data
offlineSummary = do.call("rbind", signalSummary)

# Remove the unwanted MAC address
offlineSummary = subset(offlineSummary, mac != subMacs[1])  # removes e1:c0





macs = unique(offlineSummary$mac)
online = readData("Data/online.final.trace.txt", subMacs = macs)

online$posXY = paste(online$posX, online$posY, sep = "-")

keepVars = c("posXY", "posX","posY", "orientation", "angle")
byLoc = with(online, 
             by(online, list(posXY), 
                function(x) {
                  ans = x[1, keepVars]
                  avgSS = tapply(x$signal, x$mac, mean)
                  y = matrix(avgSS, nrow = 1, ncol = 6,
                             dimnames = list(ans$posXY, names(avgSS)))
                  cbind(ans, y)
                }))

onlineSummary = do.call("rbind", byLoc)  

names(onlineSummary)







m = 3; angleNewObs = 230
refs = seq(0, by = 45, length  = 8)
nearestAngle = roundOrientation(angleNewObs)

if (m %% 2 == 1) {
  angles = seq(-45 * (m - 1) /2, 45 * (m - 1) /2, length = m)
} else {
  m = m + 1
  angles = seq(-45 * (m - 1) /2, 45 * (m - 1) /2, length = m)
  if (sign(angleNewObs - nearestAngle) > -1) 
    angles = angles[ -1 ]
  else 
    angles = angles[ -m ]
}
angles = angles + nearestAngle
angles[angles < 0] = angles[ angles < 0 ] + 360
angles[angles > 360] = angles[ angles > 360 ] - 360

offlineSubset = 
  offlineSummary[ offlineSummary$angle %in% angles, ]

trainSS = reshapeSS(offlineSubset, varSignal = "avgSignal")

selectTrain = function(angleNewObs, signals = NULL, m = 1){
  # m is the number of angles to keep between 1 and 5
  refs = seq(0, by = 45, length  = 8)
  nearestAngle = roundOrientation(angleNewObs)
  
  if (m %% 2 == 1) 
    angles = seq(-45 * (m - 1) /2, 45 * (m - 1) /2, length = m)
  else {
    m = m + 1
    angles = seq(-45 * (m - 1) /2, 45 * (m - 1) /2, length = m)
    if (sign(angleNewObs - nearestAngle) > -1) 
      angles = angles[ -1 ]
    else 
      angles = angles[ -m ]
  }
  angles = angles + nearestAngle
  angles[angles < 0] = angles[ angles < 0 ] + 360
  angles[angles > 360] = angles[ angles > 360 ] - 360
  angles = sort(angles) 
  
  offlineSubset = signals[ signals$angle %in% angles, ]
  reshapeSS(offlineSubset, varSignal = "avgSignal")
}

train130 = selectTrain(130, offlineSummary, m = 3)






### Run Predictions


# KNN function

estXYk1 = predXY(newSignals = onlineSummary[ , 6:11], 
                 newAngles = onlineSummary[ , 4], 
                 offlineSummary, numAngles = 3, k = 1)

estXYk3 = predXY(newSignals = onlineSummary[ , 6:11], 
                 newAngles = onlineSummary[ , 4], 
                 offlineSummary, numAngles = 3, k = 3)

estXYk5 = predXY(newSignals = onlineSummary[ , 6:11], 
                 newAngles = onlineSummary[ , 4], 
                 offlineSummary, numAngles = 3, k = 5)

estXYk7 = predXY(newSignals = onlineSummary[ , 6:11], 
                 newAngles = onlineSummary[ , 4], 
                 offlineSummary, numAngles = 3, k = 7)



### Error calculations
calcError = 
  function(estXY, actualXY) 
    sum( rowSums( (estXY - actualXY)^2) )

actualXY = onlineSummary[ , c("posX", "posY")]
sapply(list(estXYk7, estXYk5, estXYk3, estXYk1), calcError, actualXY)



