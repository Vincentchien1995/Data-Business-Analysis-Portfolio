USE walmart_project;

-- Data Quality Check
-- Purpose: Perform initial exploration and ensure data integrity before analysis.
-- --------------------------------------------------------------------------------

-- Preview sample records
select * from walmart_sales;

-- Count total records
select count(*) as total_records from walmart_sales;

-- Check date range
select min(Date) as start_date, MAX(Date) as end_date from walmart_sales; 

-- Detect duplicate records by Store + Date
select Store, Date, count(*) as duplicate
from walmart_sales
group by Store, Date
having count(*)>1;

-- Check missing values for all columns (Method 1)
select * 
from walmart_sales
where Store is null 
or Date is null 
or Weekly_sales is null
or Holiday_Flag is null
or Temperature is null
or Fuel_Price is null
or CPI is null
or Unemployment is null;

-- Check missing values summary (Method #2)
SELECT
  SUM(Store IS NULL) AS missing_store,
  SUM(Date IS NULL) AS missing_date,
  SUM(Weekly_Sales IS NULL) AS missing_sales,
  SUM(Holiday_Flag IS NULL) AS missing_holiday,
  SUM(Temperature IS NULL) AS missing_temp,
  SUM(Fuel_Price IS NULL) AS missing_fuel,
  SUM(CPI IS NULL) AS missing_cpi,
  SUM(Unemployment IS NULL) AS missing_unemp
FROM walmart_sales;



-- Feature Engineering
-- --------------------------------------------------------------------------------

-- Add columns of year, month and quarter
alter table walmart_sales
add column Year int,
add column Month int,
add column Quarter int;

update walmart_sales
set
Year=YEAR(str_to_date(Date, '%d-%m-%Y')),
Month= MONTH(str_to_date(Date, '%d-%m-%Y')),
Quarter=QUARTER(str_to_date(Date, '%d-%m-%Y'));


-- Business Goal
-- --------------------------------------------------------------------------------

#1 Analyze overall sales trends over time
create view sales_trend as
SELECT Year, Quarter,
round(sum(Weekly_sales),0) as quarterly_revenue,
round(avg(Weekly_sales),0) as avg_weekly_sales
from walmart_sales
group by Year, Quarter
order by Year, Quarter;

select * from sales_trend;


#2 Evaluate store-level performance
Create view store_performance as
select store, year,
round(sum(Weekly_Sales),0) as total_revenue,
round(avg(Weekly_sales),0) as avg_weekly_sales,
round(stddev(Weekly_sales),0) as sales_volatility
from walmart_sales
group by store, year;

select * from store_performance;


#3 Compare sales performance during holiday vs non-holiday weeks
create view holiday_performance as 
select Year, Holiday_Flag, 
round(avg(Weekly_Sales),0) as avg_weekly_sales, 
COUNT(*) AS total_weeks
from walmart_sales 
group by Year, Holiday_Flag
order by Year;

select * from holiday_performance;


#4 Identify weather patterns affecting weekly sales
select min(Temperature) as min_temp, max(Temperature) as max_temp from walmart_sales;


create view weather_sales_analysis as
select
year,
case
when Temperature<32 then 'cold'
when Temperature between 32 and 60 then 'mild'
when Temperature between 60 and 85 then 'warm'
else 'hot'
end as temp_category,
round(avg(Weekly_sales),0) as avg_weekly_sales,
count(*) as total_weeks
from walmart_sales
group by year,temp_category;

select * from weather_sales_analysis;


#5 Examine the relationship between sales and external economic factors
select 
min(Fuel_price) as min_fuel, max(Fuel_price) as max_fuel,
min(CPI) as min_cpi, max(CPI) as max_cpi,
min(Unemployment) as min_unemp, max(Unemployment) as max_unemp
from walmart_sales;


create view economic_sales_monthly as
select
Year, Month,
round(avg(Weekly_sales),0) as avg_weekly_sales,
round(avg(Fuel_price),2) as avg_fuel_price,
round(avg(CPI),2) as avg_cpi,
round(avg(Unemployment),2) as avg_unemp
from walmart_sales
group by Year, Month
order by Year, Month;

select * from economic_sales_monthly;


-- Export views to csv files 
SELECT * FROM sales_trend;
SELECT * FROM store_performance;
SELECT * FROM holiday_performance;
SELECT * FROM weather_sales_analysis;
SELECT * FROM economic_sales_quarterly;