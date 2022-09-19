-- create table

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

-- create hypertable

SELECT create_hypertable('rides', 'started_at');

-- copy sample data to table

\COPY rides from 'rides_cleaned.csv' DELIMITER ',' CSV HEADER;
