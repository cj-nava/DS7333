
### loading libraries
library(tidyverse)
library(XML)
library(stringi)
library(rvest)
library(RCurl)
library(xml2)
library(purrr)
library(ggplot2)


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

# Look at womens box plots
age %>% enframe(name = "year", value = "age") %>% unnest() %>% filter(age, age > 7) %>% ggplot(aes(year, age)) + geom_boxplot() + ggtitle("Women's Ages 1999-2012")



















