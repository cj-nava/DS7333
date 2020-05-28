
### loading libraries
library(tidyverse)
library(XML)
library(stringi)
library(rvest)
library(RCurl)
library(xml2)
library(purrr)
library(ggplot2)
library(VIM)


# women results
urlWomen <- c(
  'http://cherryblossom.org/results/1999/cb99f.html',
  'http://cherryblossom.org/results/2000/Cb003f.htm',
  'http://cherryblossom.org/results/2001/oof_f.html',
  'http://cherryblossom.org/results/2002/ooff.htm',
  'http://cherryblossom.org/results/2003/CB03-F.HTM',
  'http://cherryblossom.org/results/2004/women.htm',
  'http://cherryblossom.org/results/2005/CB05-F.htm',
  'http://cherryblossom.org/results/2006/women.htm',
  'http://cherryblossom.org/results/2007/women.htm',
  'http://cherryblossom.org/results/2008/women.htm',
  'http://cherryblossom.org/results/2009/09cucb-F.htm',
  'http://cherryblossom.org/results/2010/2010cucb10m-f.htm',
  'http://cherryblossom.org/results/2011/2011cucb10m-f.htm',
  'http://cherryblossom.org/results/2012/2012cucb10m-f.htm'
)

# helper function that reads women URLs, then the table nodes marked with 'pre', and then splits on new lines.
extractTable <- function(url) {
  read_html(url) %>% 
  html_nodes('pre') %>% 
  html_text() %>% 
  str_split('\\r\\n') %>% 
  .[[1]]
}


# creates list with each row being a string of the year run.
womenTable <- map(urlWomen, extractTable)

# validate row counts for each year
# NOTE: first one is 1999, second is 2000, etc
# note that 1999 and 2000 have issues, much lower than expected row counts
map_int(womenTable, length)

#compare [[1]] vs [[6]] of womenTable
womenTable[[1]] # complete mess
womenTable[[6]] # even line breaks

# first entry of 1999
# note its not performing line breaks
str_sub(womenTable[[1]], 1, 210)


# validate we can force a split on new line breaks
str_split(womenTable[[1]], '\\n')[[1]]

# update womenTable
str_split(womenTable[[1]], '\\n')[[1]] -> womenTable[[1]]





# need to update extractTable() to process 1999 as a new line split
# also for 2000 data to parse <font> html tag vs <pre> html tag

extractTable <- function(url, year = 2001, female = TRUE) {
  selector <- if (year == 2000) 'font' else 'pre'
  regexp <- if (year == 1999) '\\n' else '\\r\\n'
  #read urls and respective table tags
  result <- read_html(url) %>% 
    html_nodes(selector)
  
  if (year == 2000) result <- result[[4]]
  #parse htmltext
  result <- result %>% html_text()
  #splits the table nodes with respective function for year
  if (year == 2009 && female == FALSE) return(result)
  
  result %>% str_split(regexp) %>% .[[1]]
}




years <- 1999:2012
womenTable <- map2(urlWomen, years, extractTable)

# validate row counts
# FINALLY
names(womenTable) <- years
map_int(womenTable, length)




### CHALLENGE: CODE NEEDS INDIVIDUAL TXT FILE FOR EACH YEAR

# create dir
dir.create('women')

# create txt file for each year
walk2(womenTable, paste('women', paste(years, 'txt', sep = '.'), sep = '/'), writeLines)




### HELPER FUNCTIONS FOR COLUMNS ###


# find start / end of each column
findColLocs <- function(spacerRow) {
  
  spaceLocs = gregexpr(" ", spacerRow)[[1]]
  rowLength = nchar(spacerRow)
  
  # safeguard against more ==== lines
  if (substring(spacerRow, rowLength, rowLength) != " ")
    return( c(0, spaceLocs, rowLength + 1))
  else return(c(0, spaceLocs))
}




# extract columns 

selectCols <- function(shortColNames, headerRow, searchLocs) {
  sapply(shortColNames, function(shortName, headerRow, searchLocs){
    
    startPos = regexpr(shortName, headerRow)[[1]]
    
    if (startPos == -1) return( c(NA, NA) )
    
    index = sum(startPos >= searchLocs)
    c(searchLocs[index] + 1, searchLocs[index + 1])
  }, 
  
  headerRow = headerRow, searchLocs = searchLocs )
}


# extract only desired columns

extractVariables <- function(file, varNames =c("name", "home", "ag", "gun", "net", "time")) {
    # find the index of the row with === lines
    eqIndex = grep("^===", file)
    # extract key rows and the data
    spacerRow = file[eqIndex] 
    headerRow = tolower(file[ eqIndex - 1 ])
    body = file[ -(1 : eqIndex) ]
    
    # Obtain the starting and ending positions of variables
    searchLocs = findColLocs(spacerRow)
    locCols = selectCols(varNames, headerRow, searchLocs)
    Values = mapply(substr, list(body), start = locCols[1, ], 
                    stop = locCols[2, ])
    colnames(Values) = varNames
    
    invisible(Values)
  }




wfilenames <- paste("women/", 1999:2012, ".txt", sep = "")
womenFiles <- lapply(wfilenames, readLines)
names(womenFiles) <- 1999:2012

# FAILS
womenResMat <- lapply(womenFiles, extractVariables)


# NOTE: 2001 HAS A PROBLEM
# NO HEADERS
womenFiles[['2001']][1:15]

# check 2002
womenFiles[['2002']][1:15]

# copy headers from 2002 into 2001
womenFiles[['2002']][2:3] -> womenFiles[['2001']][2:3]


# check 2001 again
womenFiles[['2001']][1:15]


# Retry w/ corrected 2001
womenResMat <- lapply(womenFiles, extractVariables)

# verify we have 14 separate entries for each year 1999 - 2012
length(womenResMat)
# verify row count
sapply(womenResMat, nrow)




### COMPARING AGE DISTRIBUTION ###


# formatting ages as numeric
age <- map(womenResMat, ~ as.numeric(.x[ ,'ag']))


# we some have missing values
sapply(age, function(x) sum(is.na(x)))


# some of these are due to comments
# can update the extractVariables function

extractVariables = 
  function(file, varNames =c("name", "home", "ag", "gun",
                             "net", "time"))
  {
    
    # Find the index of the row with =s
    eqIndex = grep("^===", file)
    # Extract the two key rows and the data 
    spacerRow = file[eqIndex] 
    headerRow = tolower(file[ eqIndex - 1 ])
    body = file[ -(1 : eqIndex) ]
    # Remove footnotes and blank rows
    footnotes = grep("^[[:blank:]]*(\\*|\\#)", body)
    if ( length(footnotes) > 0 ) body = body[ -footnotes ]
    blanks = grep("^[[:blank:]]*$", body)
    if (length(blanks) > 0 ) body = body[ -blanks ]
    
    
    # Obtain the starting and ending positions of variables   
    searchLocs = findColLocs(spacerRow)
    locCols = selectCols(varNames, headerRow, searchLocs)
    
    Values = mapply(substr, list(body), start = locCols[1, ], 
                    stop = locCols[2, ])
    colnames(Values) = varNames
    
    return(Values)
  }

# update matrix
womenResMat = lapply(womenFiles, extractVariables)

# convert age to numeric
age = sapply(womenResMat, function(x) as.numeric(x[ , 'ag']))

# recheck missing values
# results are better
sapply(age, function(x) sum(is.na(x)))





# we have some potential bad data
# 2001 has a racer under age 7
sapply(age, function(x) which(x < 7))

# Look at womens box plots: filter out ages younger than 7
age %>% enframe(name = "year", value = "age") %>% unnest() %>% filter(age, age > 7) %>% ggplot(aes(year, age)) + geom_boxplot() + ggtitle("Women's Ages 1999-2012")





# NOTE: race times are not all in the same format
charTime = womenResMat[['2012']][, 'time']
head(charTime)
tail(charTime)









# Converting time by str_split, then mapping them to numeric.
convertTime <- function(t) {
  timePieces <- str_split(t, ":")
  map_dbl(timePieces, function(x) {
    x <- as.numeric(x)
    if (length(x) == 2) 
      x[1] + x[2]/60 
    else 60 * x[1] + x[2] + x[3]/60
  })
}






# Creating dataframe
createDf = function(Res, year, sex) {
  if (!is.na(Res[1, "net"])) 
    useTime = Res[, "net"] else if (!is.na(Res[1, "gun"])) 
      useTime = Res[, "gun"] else useTime = Res[, "time"]
      
      useTime = gsub("[#\\*[:blank:]]", "", useTime)
      runTime = convertTime(useTime[useTime != ""])
      
      Res = Res[useTime != "", ]
      age = gsub("X{2}\\s{1}?|\\s{3}?", "0  ", Res[, "ag"])
      Res[, "ag"] = age
      
      Results = data.frame(year = rep(year, nrow(Res)), 
                           sex = rep(sex, nrow(Res)), 
                           name = Res[, "name"], 
                           home = Res[, "home"], 
                           age = as.numeric(Res[, "ag"]), 
                           runTime = runTime, 
                           stringsAsFactors = FALSE)
      invisible(Results)
}



# gets every line that starts with ===
separatorIdx <- grep("^===", womenFiles[["2006"]])

# filters the list to 2006
separatorRow <- womenFiles[["2006"]][separatorIdx]

# makes a separator row
paste(substring(separatorRow, 1, 63), " ", substring(separatorRow, 65, nchar(separatorRow)), sep = "") -> separatorRowX

# replaces the === with the separator row
womenFiles[["2006"]][separatorIdx] -> separatorRowX




# extracts vars from the files
womenResMat <- sapply(womenFiles, extractVariables)

# makes a list of data frames from these things
womenDF <- mapply(createDf, womenResMat, year = 1999:2012, sex = rep("W", 14), SIMPLIFY = FALSE)

# investigage: HUGE DF w/ year hierarchy
head(womenDF)

# collapse into DF w/ year separated out from 1999 - 2012
allWomen <- do.call(rbind, womenDF)





# sorting by year, then run times
# allWomen <- allWomen %>% dplyr::arrange(year, runTime)
allWomen[order(allWomen$year, allWomen$runTime),] -> allWomen




# we see 23 runners with an age of 0
count(allWomen[allWomen$age == 0, ])

# removing rows with 0 / NA's in age column
allWomen <- allWomen[allWomen$age != 0, ]

# summary stats for womens age
allWomen %>% group_by(year) %>% summarise(ag_mean = mean(age, na.rm = T), 
                                          ag_max = max(age, na.rm = T), 
                                          ag_min = min(age, na.rm = T), 
                                          ag_median = median(age, na.rm = T), 
                                          ag_sd = sd(age, na.rm = T)) 















# show NA values

# we can see 5432 missing values for runTime
aggr(allWomen, 
     prop = FALSE, 
     combined = TRUE, 
     numbers = TRUE, 
     sortVars = TRUE, 
     sortCombs = TRUE)

# validate missing values
sum(is.na(allWomen$runTime))
is.na(allWomen$runTime)
allWomen[is.na(allWomen$runTime),]

# the NA's count as 0 showing the same 5432
count(allWomen[allWomen$runTime == 0, ])



























