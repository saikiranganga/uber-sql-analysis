/*
=============================================================
  PROJECT    : Analysis of Uber Operational Data
  TOOL       : SSMS
  AUTHOR     : Saikiran Ganga Deenadayalu
  DATE       : JAN 2025
  DATASET    : Uber Dataset 
  GITHUB     : https://github.com/saikiranganga
=============================================================
  TABLES     : rides, driver, payment, city
  OBJECTIVE  : Analyse ride-hailing operations to identify
               revenue leakage, driver performance issues,
               cancellation patterns, and city-level KPIs
               using advanced T-SQL queries.
=============================================================
  SECTIONS:
  1. Database setup
  2. Data cleaning & quality checks
  3. City-level performance analysis
  4. Revenue leakage detection
  5. Cancellation pattern analysis
  6. Fare & seasonal analysis
  7. SQL Views
  8. Indexes & performance
  9. Key findings & recommendations
=============================================================
*/

Create database uber1
use uber1 

SELECT *
FROM driver
WHERE driver_id IS NULL;
DELETE FROM driver
WHERE driver_id IS NULL;

exec sp_help city
exec sp_help rides
exec sp_help payment
exec sp_help driver

--Data cleaning queries
SELECT * FROM driver WHERE driver_id IS NULL;
DELETE FROM driver WHERE driver_id IS NULL;

ALTER TABLE driver
ALTER COLUMN driver_id NVARCHAR(100) NOT NULL;

ALTER TABLE driver ADD CONSTRAINT PK_driver PRIMARY KEY (driver_id);

-- 1. Check for NULLs in critical columns
SELECT
  SUM(CASE WHEN fare IS NULL THEN 1 ELSE 0 END) AS null_fares,
  SUM(CASE WHEN ride_id IS NULL THEN 1 ELSE 0 END) AS null_rides,
  SUM(CASE WHEN driver_id IS NULL THEN 1 ELSE 0 END) AS null_drivers
FROM rides;

-- 2. Find duplicate ride_ids
SELECT ride_id, COUNT(*)as count FROM rides
GROUP BY ride_id
HAVING COUNT(*) > 1;

-- 3. Flag rides with impossible fare (0 or negative)
SELECT ride_id, fare, ride_status
FROM rides
WHERE fare <= 0 OR fare IS NULL;

-- 4. Check rating values are within valid range (1-5)
SELECT COUNT(*) AS invalid_ratings
FROM rides
WHERE rating NOT BETWEEN 1 AND 5 AND rating IS NOT NULL;

-- 5. Replace NULL fares with city average (safe imputation)
UPDATE r
SET r.fare = avg_tbl.avg_fare
FROM rides r
JOIN (SELECT start_city, AVG(fare) AS avg_fare FROM rides
WHERE fare IS NOT NULL
GROUP BY start_city) avg_tbl
ON r.start_city = avg_tbl.start_city
WHERE r.fare IS NULL;

-- Demand vs Driver Supply Analysis
SELECT city_name,number_of_rides, number_of_drivers,ROUND(number_of_rides * 1.0 / number_of_drivers, 2) 
AS rides_per_driver, avg_wait_time_min FROM city
ORDER BY rides_per_driver DESC;

-- Dynamic Pricing Impact on Revenue
SELECT dynamic_pricing, COUNT(*) AS total_rides, ROUND(AVG(fare),2) AS avg_fare,
ROUND(SUM(fare),2) AS total_revenue FROM rides WHERE ride_status = 'Completed'
GROUP BY dynamic_pricing;

-- Driver Performance vs Earnings
SELECT driver_name, avg_driver_rating, total_rides, total_earnings, ride_acceptance_rate, years_of_experience FROM driver
ORDER BY total_earnings DESC;

--Uber Revenue & Commission Analysis
SELECT payment_method, ROUND(SUM(fare),2) AS gross_booking, ROUND(SUM(driver_earnings),2) AS total_driver_payout,
ROUND(SUM(uber_commission),2) AS uber_revenue,
ROUND(AVG(surge_multiplier),2) AS avg_surge FROM payment
GROUP BY payment_method
ORDER BY uber_revenue DESC;

-- Top Performing Cities
SELECT city_name, avg_fare, avg_wait_time_min, number_of_rides, market_competition
FROM city
ORDER BY number_of_rides DESC;

-- Best Driver Type
SELECT vehicle_type,ROUND(AVG(total_earnings),2) AS avg_earnings, ROUND(AVG(avg_driver_rating),2) AS avg_rating FROM driver
GROUP BY vehicle_type;

-- Failed Payments Analysis
SELECT transaction_status, COUNT(*) AS total_transactions, ROUND(AVG(fare),2) AS avg_fare
FROM payment
GROUP BY transaction_status;

-- Average ride duration by city and link to customer rating
SELECT
  r.start_city,
  ROUND(AVG(DATEDIFF(MINUTE, r.start_time, r.end_time)), 1) AS avg_duration_min,
  ROUND(AVG(r.rating), 2) AS avg_passenger_rating,
  COUNT(r.ride_id) AS total_rides,
  ROUND(AVG(r.fare), 2) AS avg_fare
FROM rides r
WHERE r.ride_status = 'completed'
  AND r.end_time > r.start_time
GROUP BY r.start_city
ORDER BY avg_duration_min DESC;


-- Revenue leakage — completed rides with no payment record
SELECT
  COUNT(*) AS leaked_rides,
  ROUND(SUM(r.fare), 2) AS total_leaked_revenue
FROM rides r
LEFT JOIN payment p ON r.ride_id = p.ride_id
WHERE r.ride_status = 'completed'
  AND p.payment_id IS NULL;

-- Fare discrepancies — rides table fare vs payment table fare don't match
SELECT COUNT(*) AS discrepant_rides,ROUND(SUM(ABS(r.fare - p.fare)), 2) AS total_discrepancy_value, 
ROUND(AVG(ABS(r.fare - p.fare)), 2) AS avg_discrepancy FROM rides r
JOIN payment p ON r.ride_id = p.ride_id
WHERE ABS(r.fare - p.fare) > 1.00;

-- Cancellation patterns by city and ride category vs completed revenue
WITH city_cancel AS 
(SELECT start_city,COUNT(*) AS total_rides,
    SUM(CASE WHEN ride_status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled,
    SUM(CASE WHEN ride_status = 'completed' THEN fare ELSE 0 END) AS completed_revenue FROM rides
 GROUP BY start_city)
SELECT start_city, total_rides, cancelled,ROUND(completed_revenue, 2) AS completed_revenue,
  ROUND(cancelled * (completed_revenue / NULLIF(total_rides - cancelled, 0)), 2) AS est_lost_revenue
FROM city_cancel
ORDER BY cancelled,total_rides DESC ;

-- Cancellation by hour of day — find peak cancellation hours
SELECT DATEPART(HOUR, start_time) AS hour_of_day, COUNT(*) AS total_rides,
SUM( CASE WHEN ride_status = 'cancelled' THEN 1 ELSE 0 END ) AS cancellations,
ROUND(SUM(CASE WHEN ride_status = 'completed' THEN fare ELSE 0 END),2) AS 'completed_revenue',
CASE
  WHEN DATEPART(HOUR, start_time) BETWEEN 6 AND 9 THEN 'Morning rush'
  WHEN DATEPART(HOUR, start_time) BETWEEN 10 AND 16 THEN 'Midday'
  WHEN DATEPART(HOUR, start_time) BETWEEN 17 AND 20 THEN 'Evening rush'ELSE 'Late night'
END AS time_segment
FROM rides
GROUP BY DATEPART(HOUR, start_time)
ORDER BY cancellations DESC;

-- Seasonal fare variation — MONTH() and CASE WHEN for season labels
SELECT CASE WHEN MONTH(ride_date) IN (12,1,2) THEN 'Winter'
            WHEN MONTH(ride_date) IN (3,4,5)  THEN 'Spring'
            WHEN MONTH(ride_date) IN (6,7,8)  THEN 'Summer'
            ELSE 'Autumn'
            END AS 'season',COUNT(*) AS total_rides, ROUND(AVG(fare), 2) AS avg_fare,
            ROUND(MIN(fare), 2) AS min_fare, ROUND(MAX(fare), 2) AS max_fare,
            ROUND(AVG(dynamic_pricing), 2) AS avg_surge_multiplier,
            ROUND(SUM(fare), 2) AS total_revenue
FROM rides WHERE ride_status = 'completed'
GROUP BY
    CASE
        WHEN MONTH(ride_date) IN (12,1,2) THEN 'Winter'
        WHEN MONTH(ride_date) IN (3,4,5)  THEN 'Spring'
        WHEN MONTH(ride_date) IN (6,7,8)  THEN 'Summer'
        ELSE 'Autumn'
    END
ORDER BY avg_fare DESC;

-- View — average fare by city
CREATE VIEW vw_avg_fare_by_city AS
SELECT
  r.start_city,
  COUNT(r.ride_id) AS total_rides,
  ROUND(AVG(r.fare), 2) AS avg_fare,
  ROUND(SUM(r.fare), 2) AS total_revenue,
  ROUND(AVG(p.surge_multiplier), 2) AS avg_surge
FROM rides r
LEFT JOIN payment p ON r.ride_id = p.ride_id
WHERE r.ride_status = 'completed'
GROUP BY r.start_city;
-- Use the view instantly:
SELECT * FROM vw_avg_fare_by_city ORDER BY total_revenue DESC;
----------------------------------------------------------------
WITH ranked_cities AS (
    SELECT
        start_city, total_rides, avg_fare, total_revenue, avg_surge,
        ROW_NUMBER() OVER (ORDER BY total_revenue DESC) AS top_rank,
        ROW_NUMBER() OVER (ORDER BY total_revenue ASC)  AS bottom_rank
    FROM vw_avg_fare_by_city
)
SELECT start_city, total_rides, avg_fare, total_revenue, avg_surge,
    'TOP earner' AS category
FROM ranked_cities WHERE top_rank <= 5
UNION ALL
SELECT start_city, total_rides, avg_fare, total_revenue, avg_surge,
    'BOTTOM earner' AS category
FROM ranked_cities WHERE bottom_rank <= 5
ORDER BY category, total_revenue DESC;
----------------------------------------------------------------

--View — driver performance metrics dashboard
CREATE VIEW vw_driver_performance AS
SELECT d.driver_id,d.driver_name,d.avg_driver_rating,d.total_rides,d.total_earnings,d.ride_acceptance_rate,d.years_of_experience,
COUNT(r.ride_id) AS actual_rides_in_data,
ROUND(SUM(CASE WHEN r.ride_status = 'cancelled' THEN 1 ELSE 0 END) * 100.0 /NULLIF(COUNT(r.ride_id), 0), 1) AS personal_cancel_rate,
ROUND(AVG(r.rating), 2) AS avg_passenger_rating_given
FROM driver d
LEFT JOIN rides r ON d.driver_id = r.driver_id
GROUP BY d.driver_id, d.driver_name, d.avg_driver_rating,d.total_rides, d.total_earnings,
d.ride_acceptance_rate, d.years_of_experience;

SELECT * FROM vw_driver_performance ORDER BY ride_acceptance_rate DESC;

----------------------------------------------------------------
SELECT driver_name, avg_driver_rating,
    personal_cancel_rate, avg_passenger_rating_given
FROM vw_driver_performance
WHERE avg_driver_rating < 3.5
   OR personal_cancel_rate > 20
ORDER BY avg_driver_rating ASC;
----------------------------------------------------------------

-- Indexes — for ride_date, payment_method, and city
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_ride_date')
CREATE INDEX idx_ride_date
ON rides(ride_date);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_payment_method')
CREATE INDEX idx_payment_method
ON payment(payment_method);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_city_status')
CREATE INDEX idx_city_status
ON rides(start_city, ride_status);
SELECT  ride_id, fare, ride_status FROM rides
WHERE ride_date BETWEEN '2024-01-01' AND '2024-03-31';

-- Driver tier classification (HIGH / MID / LOW performer)
WITH driver_scores AS (SELECT d.driver_id, d.driver_name, d.avg_driver_rating,d.ride_acceptance_rate, d.total_earnings,
COUNT(r.ride_id) AS rides_completed,
ROUND(d.avg_driver_rating * 0.4+ d.ride_acceptance_rate * 0.3+ (CASE 
                    WHEN d.total_earnings / 10000.0 > 1
                    THEN 1
                    ELSE d.total_earnings / 10000.0
                END) * 0.3, 3) AS perf_score
FROM driver d
LEFT JOIN rides r 
ON d.driver_id = r.driver_id AND r.ride_status = 'completed'
GROUP BY d.driver_id, d.driver_name, d.avg_driver_rating,d.ride_acceptance_rate, d.total_earnings)
SELECT *,CASE WHEN perf_score >= 0.75 THEN 'HIGH performer'
              WHEN perf_score >= 0.50 THEN 'MID performer'
              ELSE 'LOW performer — review needed'
              END AS driver_tier
FROM driver_scores
ORDER BY perf_score DESC;

-- Cancel_rate_pct to your SELECT and ORDER BY it
SELECT DATEPART(HOUR, start_time)  AS hour_of_day, COUNT(*) AS total_rides,
 SUM(CASE WHEN ride_status = 'cancelled' THEN 1 ELSE 0 END) AS cancellations,
-- ADD THIS LINE:
ROUND(CAST(SUM(CASE WHEN ride_status='cancelled' THEN 1 ELSE 0 END)
      AS FLOAT) * 100 / NULLIF(COUNT(*), 0), 1) AS cancel_rate_pct,
ROUND(SUM(CASE WHEN ride_status='completed' THEN fare ELSE 0 END),2) AS completed_revenue,
    CASE WHEN DATEPART(HOUR,start_time) BETWEEN 6 AND 9   THEN 'Morning rush'
         WHEN DATEPART(HOUR,start_time) BETWEEN 10 AND 16 THEN 'Midday'
         WHEN DATEPART(HOUR,start_time) BETWEEN 17 AND 20 THEN 'Evening rush'
         ELSE 'Late night'
    END AS time_segment
FROM rides
GROUP BY DATEPART(HOUR, start_time)
ORDER BY cancel_rate_pct DESC;

/*
=============================================================
                        KEY FINDINGS 
=============================================================

1. DRIVER RECRUITMENT:
   - City driver ride JOIN analysis revealed relational inconsistencies in the dataset
   - Driver-city relationships in the dataset were incomplete, affecting recruitment analysis accuracy
   - Relational inconsistencies prevented reliable city-level demand scoring

2. REVENUE LEAKAGE:
   - Detected 59 completed rides with no matching payment record
   - Total unrecovered revenue: $11,410.61
   - This represents 51.30% of total completed ride revenue
   - Most leakage concentrated in New Anthony City

3. CANCELLATION PATTERNS:
   - Highest cancellation activity observed during Evening rush hours (5 PM – 8 PM)
   - Peak cancellation hours showed significantly higher operational pressure compared to midday periods
   - Evening rush (5–8 PM) had the highest cancellation rate 
   - Estimated revenue lost to cancellations across all cities: $ 0

4. FARE & SEASONAL TRENDS:
   - Seasonal fare variation observed across different ride periods
   - Higher average fares were associated with increased dynamic pricing multipliers
   - Fare discrepancies detected between rides.fare and payment.fare records

5. DRIVER PERFORMANCE:
   - Drivers successfully classified into HIGH / MID / LOW performer categories
   - LOW performers showed lower driver ratings and higher cancellation rates
   - HIGH performers demonstrated better ride acceptance rates and stronger passenger ratings

=============================================================
                     RECOMMENDATIONS
=============================================================
1. Recruit 237 drivers in North Michaelberg City to reduce rides_per_driver
2. Investigate 59 rides with completed status +
3. Add driver incentives during 7-9am and 5-8pm to reduce cancellations
4. Review fare calculation logic — total discrepancy found
*/
