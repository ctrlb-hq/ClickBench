-- Schema setup for the ClickBench `hits` table. Run (untimed) by ./start once
-- hits.parquet has been downloaded. LOCATION is written as the relative
-- 'hits.parquet' here; ./start rewrites it to the absolute path the container
-- sees (the system dir is mounted into the container) before sending these
-- statements to the engine over HTTP.
CREATE EXTERNAL TABLE hits_raw STORED AS PARQUET LOCATION 'hits.parquet' OPTIONS ('binary_as_string' 'true');
CREATE VIEW hits AS SELECT * EXCEPT("EventDate"), CAST(CAST("EventDate" AS INT) AS DATE) AS "EventDate" FROM hits_raw;
