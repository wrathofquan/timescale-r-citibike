library(RPostgres)
library(tidyverse)
library(sf)


# raw data: https://ride.citibikenyc.com/system-data

# R Timescale Citbike Tutorial

# Open a connection to Timescale Cloud

conn <- dbConnect(drv = RPostgres::Postgres(),
                  dbname = "tsdb",
                  host = "<YOUR_TIMESCALE_HOST>",
                  user = "tsdbadmin",
                  password = "<YOUR_TIMESCALE_PASSWORD>",
                  port = "<YOUR_TIMESCALE_PORT>")

rides <- dbGetQuery(conn, paste0("SELECT * FROM rides WHERE duration <= 3600 AND duration > 0;"))


# distributions

options(scipen=10000)

p1 <- rides %>%
  group_by(rideable_type) %>%
  count() %>%
  ggplot(aes(rideable_type, n)) +
  geom_col() +
  scale_y_sqrt() +
  theme(legend.position = "none") +
  coord_flip()


p2 <- rides %>% filter(duration < 3600 & duration > 0) %>% 
  ggplot(aes(x = duration)) + 
  geom_histogram(binwidth = 300)


# map
# community district shape file
# https://data.cityofnewyork.us/City-Government/Community-Districts/yfnk-k7r4

nyc <- read_sf("https://data.cityofnewyork.us/api/geospatial/yfnk-k7r4?method=export&format=GeoJSON")
nyc <- st_simplify(nyc)

ggplot(nyc) + geom_sf()


# filter out data points that are less than 2 hours and greater than 0.

start_coordinates <- rides %>% 
  select(start_lng, start_lat)


# overlay points on shapefile

ggplot(nyc) + geom_sf(size = 0.25) +
  geom_point(data = start_coordinates, 
             aes(x= start_lng, y= start_lat, alpha = 1/10))


# add 2d contour for overplotting

p3 <- ggplot() + 
  geom_sf(size = 0.25, data = nyc) +
  geom_jitter(aes(x= start_lng, y= start_lat), 
              size = 0.5, alpha = 0.025, shape = 3, 
              data = start_coordinates) +
  stat_density2d(aes(x= start_lng, y= start_lat, fill = ..level..,alpha = ..level..), 
                 geom = "polygon", contour_var = "count",
                 data = start_coordinates) +
  scale_fill_gradient(low = "blue", high = "red") +
  theme(axis.ticks = element_blank(), axis.text = element_blank(), legend.position="none")



