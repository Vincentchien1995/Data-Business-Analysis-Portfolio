use hotel_booking_project;

-- Step 1: Check data volume
select count(*) from hotels;
select count(*) from reviews;
select count(*) from users;

-- Step 2: Perform data quality checks (missing values, duplicates) and descriptive analysis in Python

-- Step 3: Add check-in year, month, and quarter (based on review_date)
-- assuming review_date is approximately equivalent to the check-in date.
alter table reviews
add column checkin_year int,
add column checkin_month int,
add column checkin_quarter int;

update reviews
set 
checkin_year=year(review_date),
checkin_month=month(review_date),
checkin_quarter = quarter(review_date);

select * from reviews;

-- Step 4: Join table reviews with hotels and users
select * from reviews r
left join hotels h on r.hotel_id = h.hotel_id
left join users u on r.user_id = u.user_id;

-- Step 5: Create a view for the complete dataset
create view hotel_full_data as
select 
r.review_id,
r.user_id,
r.hotel_id,
r.review_date,
r.score_overall,
r.score_cleanliness,
r.score_comfort,
r.score_facilities,
r.score_location,
r.score_staff,
r.score_value_for_money,
r.checkin_year,
r.checkin_month,
r.checkin_quarter,
h.hotel_name,
h.city,
h.country as hotel_country,
h.star_rating, 
h.lat as hotel_latitude,
h.lon as hotel_longitude,
h.cleanliness_base,
h.comfort_base,
h.facilities_base,
h.location_base,
h.staff_base,
h.value_for_money_base,
u.user_gender,
u.country as user_country,
u.age_group,
u.traveller_type
from reviews r
LEFT JOIN hotels h ON r.hotel_id = h.hotel_id
LEFT JOIN users u ON r.user_id = u.user_id;

select * from hotel_full_data;

-- Step 6: Business Goals
-- Goal #1: Identify top and bottom-performing hotels based on overall review scores
-- Method 1: Calculate average score per hotel per year
select hotel_id, hotel_name, checkin_year,avg(score_overall) as avg_score
from hotel_full_data
group by hotel_id, hotel_name, checkin_year;

-- Method 2: Rank hotels within each year using a window function
select hotel_id, hotel_name, hotel_country, checkin_year, avg(score_overall) as avg_score,
rank() over (partition by checkin_year order by avg(score_overall) desc) as yearly_rank
FROM hotel_full_data
GROUP BY hotel_id, hotel_name, hotel_country, checkin_year;


-- Goal #2: Determine which rating dimensions most influence overall satisfaction
select checkin_year,hotel_id, hotel_name, hotel_country,
avg(score_overall) as avg_score, 
avg(score_cleanliness) as avg_cleanliness, 
avg(score_comfort) as avg_comfort, 
avg(score_facilities) as avg_facilities, 
avg(score_location) as avg_location, 
avg(score_staff) as avg_staff,
avg(score_value_for_money) as avg_value_for_money
from hotel_full_data
group by checkin_year,hotel_id, hotel_name,hotel_country;


-- Goal #3: Analyze international visitor distribution and age demographics per hotel

-- Aggregate visitor counts by hotel, year, and country
create view visitors_per_hotel_year_country as
select hotel_name,checkin_year, user_country, count(*) as country_visitor_count
from hotel_full_data
group by hotel_name,checkin_year,user_country;

select * from visitors_per_hotel_year_country;

-- Identify the dominant visitor country per hotel per year
create view main_country_per_hotel_year as 
select hotel_name,checkin_year,user_country, country_visitor_count
from (
select *,rank() over (partition by hotel_name, checkin_year order by country_visitor_count desc) as rnk
from visitors_per_hotel_year_country) as ranked
where rnk=1;

select * from main_country_per_hotel_year;

-- Aggregate visitor counts by hotel, year, and age group
create view visitors_per_hotel_year_agegroup as
select hotel_name,checkin_year, age_group, count(*) as age_group_count
from hotel_full_data
group by hotel_name,checkin_year,age_group
order by hotel_name;

select * from visitors_per_hotel_year_agegroup;

-- Identify the dominant (highest) age group per hotel per year
create view main_agegroup_per_hotel_year as
select hotel_name,checkin_year, age_group, age_group_count
from (
select *, rank() over (partition by hotel_name,checkin_year order by age_group_count desc) as rn
from visitors_per_hotel_year_agegroup) as ranked2
where rn=1;

select * from main_agegroup_per_hotel_year;

-- Combine dominant visitor country, dominant age group, and hotel information
create view hotel_customer_demographics as
select 
h.hotel_name,
h.city,
h.hotel_latitude,
h.hotel_longitude,
mcp.checkin_year,
mcp.user_country,
mcp.country_visitor_count,
map.age_group,
map.age_group_count
from main_country_per_hotel_year mcp
left join main_agegroup_per_hotel_year map 
on mcp.hotel_name=map.hotel_name and mcp.checkin_year = map.checkin_year
left join (select distinct hotel_name, city, hotel_latitude, hotel_longitude from
hotel_full_data) h on mcp.hotel_name=h.hotel_name;

select * from hotel_customer_demographics;


-- Goal #4: Evaluate how satisfaction levels vary across traveler types
select hotel_name,traveller_type, checkin_year,
avg(score_overall) as avg_score, 
avg(score_cleanliness) as avg_cleanliness, 
avg(score_comfort) as avg_comfort, 
avg(score_facilities) as avg_facilities, 
avg(score_location) as avg_location, 
avg(score_staff) as avg_staff,
avg(score_value_for_money) as avg_value_for_money
from hotel_full_data
group by hotel_name,traveller_type, checkin_year;


-- Goal #5: Compare baseline quality scores with actual customer ratings
-- Method 1: Direct comparison using average baseline values from hotel metadata
select checkin_year,hotel_id, hotel_name,hotel_country, avg(score_overall) as avg_score, 
avg(cleanliness_base + comfort_base + facilities_base + location_base + staff_base + value_for_money_base) / 6 
as baseline_overall
from hotel_full_data
group by checkin_year,hotel_id, hotel_name,hotel_country;

-- Method 2: Use CTE to separately compute scores and baselines, then compare
with hotel_scores as (
select hotel_id, avg(score_overall) as avg_score
from reviews
group by hotel_id),
hotel_baselines as (
select hotel_id,hotel_name,(cleanliness_base + comfort_base + facilities_base + location_base + staff_base + value_for_money_base) / 6 
as baseline_overall from hotels)

select hs.hotel_id, hb.hotel_name, hs.avg_score, hb.baseline_overall
from hotel_scores hs
join hotel_baselines hb on hs.hotel_id= hb.hotel_id;


