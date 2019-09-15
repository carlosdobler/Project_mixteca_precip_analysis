
# SCRIPT TO:
#   - Extract CHIRPS data from NetCDF files
#   - Build a raster stack object
# *******************************************

# Load libraries
library(ncdf4)
library(tidyverse)
library(lubridate)
library(raster)
library(tictoc)

# List of files
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

# Obtain sequence of coordinates
range_lon_coord <- seq(min_lon, max_lon, by = 0.05)
range_lat_coord <- seq(min_lat, max_lat, by = 0.05)

# Obtain origin date
orig <- ncin$dim$time$units %>%
  str_split(" ", simplify = T) %>% 
  .[,3] %>% 
  as_date() %>% 
  {.+ncin$dim$time$vals[1]}

# Create super raster stack ***********************************************************************

tic()

# Loop through all annual files
chirps_stack <- map(seq_along(chirps_files), function(yr){
  
  # Open connection
  nc <- chirps_files[yr] %>% 
    nc_open()
  
  # Extract data (results in an array)
  data <- ncvar_get(nc, 
                    "precip",
                    start = c(which(near(ncin$dim$longitude$vals, min_lon, 0.01)), # left-most
                              which(near(ncin$dim$latitude$vals, min_lat, 0.01)), # lowest
                              1), # time dim from the beginning
                    count = c(length(range_lon_coord), 
                              length(range_lat_coord), 
                              -1)) # all entries in time dim
  
  # Rotate data (loop through doys)
  map(seq_len(dim(data)[3]), function(doy){
    empty_matrix <- matrix(NA, dim(data)[2], dim(data)[1])
    for(r in seq_along(range_lat_coord)){
      for(c in seq_along(range_lon_coord)){
        empty_matrix[length(range_lat_coord)-r+1, c] <- data[c, r, doy]
      }
    }
    
    # Convert to raster
    empty_matrix %>% 
      raster(xmx = max_lon,
             xmn = min_lon,
             ymx = max_lat,
             ymn = min_lat,
             crs = "+proj=longlat +datum=WGS84 +ellps=WGS84 +towgs84=0,0,0")
    
  }) %>% 
    stack() # one year

}) %>% 
  stack() # all years

toc()


# Create vector of all dates
time_vector <- seq(
  orig,
  as_date(dim(chirps_stack)[3], origin = orig - days(1)),
  by = "1 day"
)

# Clean-up
rm(list=ls()[!ls() %in% c("chirps_stack", "time_vector")])


