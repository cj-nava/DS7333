

library(tidyverse)

# one off example of different web pages from same base domain
urlBase <- 'http://cherryblossom.org/'
urlFull <- paste0(urlBase, 'results/2012/2012cucb10m-m.htm')
doc <- read_html(urlFull)


# men subdirectories
men_urls <- c(
  'results/1999/cb99m.html',
  'results/2000/Cb003m.htm',
  'results/2001/oof_m.html',
  'results/2002/oofm.htm',
  'results/2003/CB03-M.HTM',
  'results/2004/men.htm',
  'results/2005/CB05-M.htm',
  'results/2006/men.htm',
  'results/2007/men.htm',
  'results/2008/men.htm',
  'results/2009/09cucb-M.htm',
  'results/2010/2010cucb10m-m.htm',
  'results/2011/2011cucb10m-m.htm',
  'results/2012/2012cucb10m-m.htm'
)


