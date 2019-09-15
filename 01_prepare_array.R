
# SCRIPT TO:
#   - Extract CHIRPS data from NetCDF files
#   - Build a stars object for Mixteca Alta
# *******************************************


# Load libraries
library(stars)
library(ncdf4)
library(tidyverse)
library(lubridate)
library(tictoc)


# Vector of filenames
chirps_files <- list.files("/home/cdobler/Documents/chirps_data/", full.names = T)

# Create connection with first file
ncin <- chirps_files[1] %>% 
  nc_open()

# ncin # (print metadata)

# Obtain extreme coordinates
func_get_nc_coord <- function(dimension, coord, tol){
  near(dimension, coord, tol = tol) %>% 
    which() %>% 
    dimension[.] %>% 
    round(3)
}

# (Mixteca)
# Papers used to approximate the extent:
# http://www.scielo.org.mx/pdf/sh/v19n38/1665-4420-sh-19-38-00056.pdf
# http://www.scielo.org.mx/pdf/desacatos/n27/n27a2.pdf

max_lon <- func_get_nc_coord(ncin$dim$longitude$vals, -97.007, 0.03)
min_lon <- func_get_nc_coord(ncin$dim$longitude$vals, -97.909, 0.03)
max_lat <- func_get_nc_coord(ncin$dim$latitude$vals, 17.794, 0.03)
min_lat <- func_get_nc_coord(ncin$dim$latitude$vals, 16.505, 0.03)

# (Yucatan peninsula)
# max_lon <- func_get_nc_coord(ncin$dim$longitude$vals, -86.086, 0.03)
# min_lon <- func_get_nc_coord(ncin$dim$longitude$vals, -92.345, 0.03)
# max_lat <- func_get_nc_coord(ncin$dim$latitude$vals, 22.130, 0.03)
# min_lat <- func_get_nc_coord(ncin$dim$latitude$vals, 17.774, 0.03)

# Obtain sequence of coordinates and position
range_lon_coord <- seq(min_lon, max_lon, by = 0.05)
range_lon_pos <- map_int(range_lon_coord, function(i) which(near(ncin$dim$longitude$vals, i, 0.01)))
range_lat_coord <- seq(min_lat, max_lat, by = 0.05)
range_lat_pos <- map_int(range_lat_coord, function(i) which(near(ncin$dim$latitude$vals, i, 0.01)))

# Origin date
orig <- ncin$dim$time$units %>%
  str_split(" ", simplify = T) %>% 
  .[,3]


# Create super stars object ***********************************************************************
tic()
chirps_stars <- map(seq_along(chirps_files), function(yr){
 

  # Days after origin
  ncin_dates <- chirps_files[yr] %>% 
    nc_open() %>% 
    {.$dim$time$vals}
  
  # Extract data (stars format)
  ncin_data <- read_ncdf(
    chirps_files[yr],
    ncsub = cbind(start = c(range_lon_pos[1],
                            range_lat_pos[1],
                            1),
                  count = c(length(range_lon_pos),
                            length(range_lat_pos),
                            length(ncin_dates)))
  )
  
  # Edit dimensions
  ncin_data %>% 
    st_set_dimensions("longitude", offset = min_lon, delta = 0.05, refsys = "+proj=longlat +datum=WGS84 +ellps=WGS84 +towgs84=0,0,0") %>% 
    st_set_dimensions("latitude", offset = min_lat, delta = 0.05, refsys = "+proj=longlat +datum=WGS84 +ellps=WGS84 +towgs84=0,0,0") %>% 
    st_set_dimensions("time", values = as_date(ncin_dates, origin = orig))
  
}) %>% 
  do.call(c, .) # Combine
toc() # 20.87 sec

rm(list=setdiff(ls(), "chirps_stars"))

# END *********************************************************************************************

