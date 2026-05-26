 Uber Operational Data Analysis — SQL Project

Analysed Uber's operational data using advanced T-SQL to uncover $$11,410.61in revenue leakage, identify peak cancellation windows, and classify driver performance across cities.

 Table of Contents
•	Problem Statement
•	Database Schema
•	Data Cleaning
•	Key Findings
•	SQL Techniques Used
•	Query Results
•	Project Structure
•	How to Run

 Problem Statement
Uber operates across multiple cities and faces operational challenges including:
•	Revenue leakage — completed rides with no corresponding payment
•	Driver shortages — cities where ride demand exceeds driver supply
•	High cancellation rates — particularly during peak hours
•	Fare inconsistencies — mismatches between ride and payment records
This project uses T-SQL to analyse 4 relational tables and produce actionable insights for Uber's operations team.

Database Schema
 <img width="878" height="766" alt="schema_diagram" src="https://github.com/user-attachments/assets/d640c34c-86c0-4401-b5fc-accec1d8a452" />

Table	Description	Key Columns
rides	All ride records	ride_id, driver_id, fare, ride_status, ride_date, start_time, end_time
driver	Driver profiles	driver_id, city_id, avg_driver_rating, total_earnings, ride_acceptance_rate
payment	Payment transactions	payment_id, ride_id, fare, surge_multiplier, uber_commission, transaction_status
city	City-level metrics	city_id, city_name, number_of_drivers, number_of_rides, avg_fare, avg_wait_time_min


 Data Cleaning
Before analysis, the following data quality steps were performed:
Issue	Action Taken
NULL driver_id records	Detected with SELECT WHERE IS NULL → Removed with DELETE
Missing PRIMARY KEY on driver table	Added via ALTER TABLE ADD CONSTRAINT PK_driver
NULL fares in rides table	Imputed with city-level average using UPDATE + subquery JOIN
Duplicate ride_ids	Checked with GROUP BY HAVING COUNT(*) > 1
Invalid ratings (outside 1–5)	Flagged with WHERE rating NOT BETWEEN 1 AND 5
Impossible fares (≤ 0)	Identified with WHERE fare <= 0 OR fare IS NULL

🔍 Key Findings

 1. Revenue Leakage
 <img width="602" height="143" alt="revenue_leakage" src="https://github.com/user-attachments/assets/baada25e-eb64-4875-8be0-e1976ee563ee" />

•	$22,241.67 in completed rides with no matching payment record detected
•	Identified using LEFT JOIN + IS NULL pattern — completed rides with no payment entry
•	Additional fare discrepancies found between rides.fare and payment.fare (threshold > $1.00)

 2. Demand vs Driver Supply
 <img width="599" height="222" alt="demand_supply" src="https://github.com/user-attachments/assets/211f2149-d3e7-4c90-819d-660de47e3ce5" />

•	Cities ranked by rides_per_driver ratio to identify recruitment pressure
•	High rides-per-driver ratio + high cancellation rate = urgent recruitment need
•	avg_wait_time_min used as secondary signal for driver shortage

 3. Cancellation Patterns
 <img width="602" height="276" alt="cancellation_hours" src="https://github.com/user-attachments/assets/d084bea5-b193-41ae-8493-8ebb58f44ebe" />

•	Evening rush (5–8 PM) showed the highest cancellation activity
•	Hourly analysis using DATEPART(HOUR, start_time) with cancel_rate_pct calculation
•	City-level estimated lost revenue calculated using completed_revenue / completed_rides × cancelled_rides

 4. Revenue & Commission by Payment Method
 <img width="602" height="125" alt="payment_analysis" src="https://github.com/user-attachments/assets/f4772cbb-5a09-4b64-b810-43f93115d573" />

•	Gross booking value, driver payout, and Uber commission broken down by payment method
•	Surge multiplier average tracked per payment type
•	Failed/pending transactions identified via transaction_status grouping

 5. Seasonal Fare Variation
 <img width="602" height="233" alt="seasonal_fares" src="https://github.com/user-attachments/assets/a96ded24-c66c-4e56-93d0-1466c2188ea8" />

•	Rides grouped into Winter / Spring / Summer / Autumn using CASE WHEN MONTH()
•	Average fare, min, max, and STDEV compared across seasons
•	Dynamic pricing (surge) multiplier tracked alongside fare changes

 6. Driver Performance Tiers
 <img width="602" height="324" alt="driver_tiers" src="https://github.com/user-attachments/assets/1e06b7d2-9819-46bc-9293-39a66e492277" />

•	Drivers classified as HIGH / MID / LOW performer using weighted composite score: 
o	avg_driver_rating × 0.4 + ride_acceptance_rate × 0.3 + earnings_score × 0.3
•	Underperformers flagged: avg_driver_rating < 3.5 OR personal_cancel_rate > 20%
•	View vw_driver_performance created for reusable access
 

SQL Techniques Used
<img width="576" height="646" alt="image" src="https://github.com/user-attachments/assets/21f3f43c-7598-4848-aafa-2e4c3da35444" />

Technique	Where Applied
CTEs (WITH clause)	City recruitment scoring, cancellation analysis, top/bottom earner ranking
Window Functions	RANK() OVER, ROW_NUMBER() OVER for ranking and classification
CASE WHEN	Season labels, driver tier classification, time-of-day segmentation
LEFT JOIN + NULL check	Revenue leakage detection (completed rides with no payment)
UPDATE with subquery JOIN	NULL fare imputation using city-level average
DATEDIFF(MINUTE, ...)	Average ride duration per city
ABS() threshold logic	Fare discrepancy detection between tables
DATEPART(HOUR, ...)	Hourly cancellation pattern analysis
SQL Views	vw_avg_fare_by_city, vw_driver_performance
NONCLUSTERED Indexes	ride_date, payment_method, (start_city, ride_status)
IF NOT EXISTS	Safe index creation without duplication errors
ALTER TABLE / CONSTRAINT	Enforcing PRIMARY KEY after data cleaning
sp_help	Table structure inspection in SSMS







 Query Results
<img width="479" height="324" alt="image" src="https://github.com/user-attachments/assets/0c0ce22c-9a22-4ac5-81ef-beedb4e58f92" />

Revenue leakage (leaked rides + amount)	=results/revenue_leakage.png

Demand vs driver supply by city=	results/demand_supply.png

Cancellation rate by hour	=results/cancellation_hours.png

Seasonal fare breakdown=	results/seasonal_fares.png

Driver tier classification=	results/driver_tiers.png

Payment method revenue split=	results/payment_analysis.png

Top + Bottom 5 earner cities=	results/top_bottom_cities.png


📁 Project Structure
uber-sql-analysis/
├── README.md
├── queries/
│   └── uber_analysis.sql
├── schema/
│   └── schema_diagram.png
└── results/
    ├── revenue_leakage.png
    ├── demand_supply.png
    ├── cancellation_hours.png
    ├── seasonal_fares.png
    ├── driver_tiers.png
    ├── payment_analysis.png
    └── top_bottom_cities.png

How to Run
Prerequisites
•	Microsoft SQL Server (any edition) or SQL Server Express (free)
•	SQL Server Management Studio (SSMS) — Download free
•	Uber dataset CSV files (rides, driver, payment, city)
Steps
-- 1. Open SSMS and connect to your server instance
-- 2. Create the database
CREATE DATABASE uber1;
USE uber1;
-- 3. Import CSV files:
--    Right-click database → Tasks → Import Flat File
--    Import in this order: city → driver → rides → payment
--    (respects foreign key dependencies)
-- 4. Open queries/uber_analysis.sql
-- 5. Run section by section (select each section, press F5)
--    Recommended order: Data Cleaning → Analysis → Views → Indexes
💡 Tip: Use Ctrl + M in SSMS before running index queries to see the execution plan and confirm Index Seek (not Table Scan).

Tools & Technologies
 <img width="225" height="225" alt="ssms" src="https://github.com/user-attachments/assets/0e5c592c-2d09-461f-96fd-523903ec07e6" />

•	Database: Microsoft SQL Server
•	IDE: SQL Server Management Studio (SSMS)
•	Language: T-SQL (Transact-SQL)
•	Dataset: IntelliPaat Uber Capstone Dataset


👤 Author
Saikiran Ganga Deenadayalu
📧 [saikiranganga13@gmail.com]
🔗 (https://www.linkedin.com/in/saikiranganga/)
🐙 github.com/saikiranganga
________________________________________
Project completed: January 2025 

