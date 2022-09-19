# Connecting R to Timescale Cloud

[R](https://www.r-project.org/) is an open-source programming language that has powerful features for statistics, data visualization, and machine learning among many other analytics use cases. In this tutorial, I want to demonstrate how to connect an R session to a Timescale Cloud database and create some exploratory data anayses and visualizations. The [data](https://ride.citibikenyc.com/system-data) is provided by CitibikeNYC to look at bicycle ridership in New York City for March 2022. We'll be using a smaller random sample of the raw data provided under `data/rides-cleaned.csv.zip` for demonstration. A few things we'll need first to get started:

- A Timescale Cloud account. You can sign up for a free 30-day trial [here](https://www.timescale.com/).
- The latest version of R. You can download R for your operating system right from the [project website](https://www.r-project.org/)
- [optional] Download the free and open-source [RStudio IDE](https://www.rstudio.com/products/rstudio/)
- After downloading the R and Rstudio software, you'll want to install the R libraries we'll be using in the tutorial. You can do that in R/RStudio with this command: ```install.packages(c("RPostgres", "tidyverse", "sf"))```

## Create rides schema and hypertable

After getting our Timescale Cloud instance [setup](https://docs.timescale.com/getting-started/latest/create-database/), we'll want to create our first table:

```
-- create the rides table
CREATE TABLE "rides"(
    ride_id TEXT,
    rideable_type TEXT,
    started_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    ended_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    start_station_name TEXT,
    start_station_id TEXT,
    end_station_name TEXT,
    end_station_id TEXT,
    start_lat NUMERIC, 
    start_lng NUMERIC,
    end_lat NUMERIC,
    end_lng NUMERIC,
    member_casual TEXT,
    duration NUMERIC
);

-- turn the rides table into a hypertable
SELECT create_hypertable('rides', 'started_at');

```

After that, we want to make sure our sample data, rides-cleaned.csv.zip is unzipped and stored in our working directory. From the Timescale command line, we can copy the csv into our rides table (this may take a minute or so depending on network connectivity):


```
 \COPY rides from 'rides_cleaned.csv' DELIMITER ',' CSV HEADER;
```
If this is successful we should see the message `COPY 378304`

## Creating a connection in R/RStudio

In our R environment, we first want to load our R libraries we downloaded earlier and setup the connection to Timescale Cloud. You'll need to fill in your own Timescale credentials in the `dbConnect` function. If you can't find this information please feel free to reach out to [Timescale Support](https://www.timescale.com/support/) for help. 

```
library(RPostgres)
library(tidyverse)
library(sf)


conn <- dbConnect(drv = RPostgres::Postgres(),
                  dbname = "tsdb",
                  host = "<YOUR_TIMESCALE_HOST>",
                  user = "tsdbadmin",
                  password = "<YOUR_TIMESCALE_PASSWORD>",
                  port = "<YOUR_TIMESCALE_PORT>")

```
Next, let's pass a query to the rides table in Timescale Cloud that selects all columns where the ride duration is equal to or less than an hour but greater than 0. We assign that data to an object called `rides`

```
rides <- dbGetQuery(conn, paste0("SELECT * FROM rides WHERE duration <= 3600 AND duration > 0;"))
```

We can take a look at the first 6 observations with `head()`

```
head(rides)
           ride_id rideable_type          started_at            ended_at      start_station_name
1 9381AD44AC422975  classic_bike 2022-03-16 18:17:23 2022-03-16 18:27:19      E 13 St & Avenue A
2 19BB5857A4252A83  classic_bike 2022-03-16 01:08:36 2022-03-16 01:11:00 Grand St & Havemeyer St
3 4F1E2AAE8AD84445  classic_bike 2022-03-16 09:07:37 2022-03-16 09:14:24        W 26 St & 10 Ave
4 2B6BCFC4E56529E8 electric_bike 2022-03-11 22:53:25 2022-03-11 23:05:01      E 5 St & Cooper Sq
5 F08287F7EB311BBD electric_bike 2022-03-13 18:42:04 2022-03-13 19:14:59  Norfolk St & Broome St
6 7B15283C3D2721DF  classic_bike 2022-03-11 00:35:27 2022-03-11 00:42:53     St Marks Pl & 1 Ave
  start_station_id              end_station_name end_station_id start_lat start_lng  end_lat   end_lng
1          5779.09     Thompson St & Bleecker St        5721.07  40.72967 -73.98068 40.72840 -73.99969
2          5267.08 Metropolitan Ave & Meeker Ave        5300.05  40.71287 -73.95698 40.71413 -73.95234
3          6382.05            Broadway & W 25 St        6173.08  40.74972 -74.00295 40.74287 -73.98919
4          5712.12          E 30 St & Park Ave S        6206.08  40.72769 -73.99099 40.74445 -73.98304
5          5374.01        Hanson Pl & Ashland Pl        4395.07  40.71723 -73.98802 40.68507 -73.97791
6          5626.13    Greenwich Ave & Charles St        5914.08  40.72779 -73.98565 40.73524 -74.00027
  member_casual duration
1        member      596
2        member      144
3        casual      407
4        casual      696
5        casual     1975
6        member      446
```

Next, let's look at the distribution of bicycle types (docked vs. electric vs. classic)

```
options(scipen=10000)# this turns off scientific notation for ease of readability

rides %>%
  group_by(rideable_type) %>%
  count() %>%
  ggplot(aes(rideable_type, n)) +
  geom_col() +
  scale_y_sqrt() +
  theme(legend.position = "none") +
  coord_flip()
```

![](https://github.com/wrathofquan/timescale-r-citibike/blob/main/images/rideable-type.png)

Looking at the distribution of ride duration

```
rides  %>% 
  ggplot(aes(x = duration)) + 
  geom_histogram(binwidth = 300)
```
![](https://github.com/wrathofquan/timescale-r-citibike/blob/main/images/duration-histogram.png)

We can see that the peak duration of a ride is about 400-500 seconds or around 6-8 minutes. 

Next let's leverage R's geospatial capabilities to draw a map of where rides originate. We can first read in a GeoJSON shape file of New York City and then process it.

```
nyc <- read_sf("https://data.cityofnewyork.us/api/geospatial/yfnk-k7r4?method=export&format=GeoJSON")
nyc <- st_simplify(nyc)

ggplot(nyc) + geom_sf()
```
![](https://github.com/wrathofquan/timescale-r-citibike/blob/main/images/nyc-map.png)

Let's next plot the longitude and latitude of the rides by first creating a new dataframe with this data.

```
start_coordinates <- rides %>% 
  select(start_lng, start_lat)
```

And then overlaying these points on our map

```
ggplot(nyc) + geom_sf(size = 0.25) +
  geom_point(data = start_coordinates, 
             aes(x= start_lng, y= start_lat, alpha = 0.1))
```
![](https://github.com/wrathofquan/timescale-r-citibike/blob/main/images/nyc-points.png)

Not bad but there is clearly an overplotting problem. We can try to do better by experimenting with ggplot's [geoms](https://ggplot2.tidyverse.org/reference/) to overlay density plots to show where more rides are originating.

```
ggplot() + 
  geom_sf(size = 0.25, data = nyc) +
  geom_jitter(aes(x= start_lng, y= start_lat), 
              size = 0.5, alpha = 0.025, shape = 3, 
              data = start_coordinates) +
  stat_density2d(aes(x= start_lng, y= start_lat, fill = ..level..,alpha = ..level..), 
                 geom = "polygon", contour_var = "count",
                 data = start_coordinates) +
  scale_fill_gradient(low = "blue", high = "red") +
  theme(axis.ticks = element_blank(), axis.text = element_blank(), legend.position="none") +
  ggtitle("NYC Citibike Rides Origin, March 2022")

```

![](https://github.com/wrathofquan/timescale-r-citibike/blob/main/images/nyc-points-density.png)

