-- Active: 1764375135052@@127.0.0.1@5432@toy_store
-- Active: 1764375135052@@127.0.0.1@5432@postgres

CREATE DATABASE toy_store ;

CREATE SCHEMA e_commerce ;

CREATE table e_commerce.orders (
    Order_id int,
    Created_at TIMESTAMP ,
    website_session_id INT ,
    user_id int ,
    primary_product_id int ,
    items_purchased int ,
    price_usd DECIMAL ,
    cogs_usd DECIMAL
);

COPY e_commerce.orders (order_id, created_at, website_session_id, user_id, primary_product_id ,items_purchased ,price_usd ,cogs_usd)
FROM '/usr/databases/Project two/orders.csv'
DELIMITER ','
CSV HEADER;

ALTER table e_commerce.orders
ADD PRIMARY KEY (order_id);

ALTER Table e_commerce.orders
alter COLUMN created_at set NOT null ;

alter Table e_commerce.orders
alter COLUMN price_usd type NUMERIC(10,2);

ALTER Table e_commerce.orders
alter COLUMN cogs_usd type NUMERIC(10,2);


CREATE Table e_commerce.order_items (
    order_item_id int PRIMARY KEY ,
    created_at TIMESTAMP ,
    order_id int ,
    product_id int ,
    is_primary_item BOOLEAN ,
    price_usd NUMERIC(10,2),
    cogs_usd NUMERIC(10,2) ,

    Constraint fk_order
    Foreign Key (order_id) 
    REFERENCES e_commerce.orders(order_id)
) ;

COPY e_commerce.order_items (order_item_id, created_at, order_id, product_id, is_primary_item ,price_usd ,cogs_usd)
FROM '/usr/databases/Project two/order_items.csv'
DELIMITER ','
CSV HEADER;



CREATE table e_commerce.order_item_refunds(
order_item_refund_id int PRIMARY KEY ,
created_at	TIMESTAMP not null ,
order_item_id int not NULL,
order_id int not null,
refund_amount_usd NUMERIC (10,2) check (refund_amount_usd >= 0) ,

constraint fk_order_items
Foreign Key (order_item_id) 
REFERENCES e_commerce.order_items(order_item_id)
,
constraint fk_orders_refund
Foreign Key (order_id) 
REFERENCES e_commerce.orders(order_id)
) ;

COPY e_commerce.order_item_refunds (order_item_refund_id, created_at, order_item_id, order_id, refund_amount_usd)
FROM '/usr/databases/Project two/order_item_refunds.csv'
DELIMITER ','
CSV HEADER;

CREATE TABLE e_commerce.products (
    product_id INT PRIMARY KEY,
    created_at TIMESTAMP NOT NULL,
    product_name VARCHAR(300) 
);

COPY e_commerce.products (product_id, created_at, product_name)
FROM '/usr/databases/Project two/products.csv'
DELIMITER ','
CSV HEADER;

CREATE TABLE e_commerce.website_sessions (
    website_session_id INT PRIMARY KEY,
    created_at TIMESTAMP NOT NULL,
    user_id INT,
    is_repeat_session BOOLEAN,
    utm_source VARCHAR(100),
    utm_campaign VARCHAR(100),
    utm_content VARCHAR(100),
    device_type VARCHAR(20),
    http_referer TEXT
);

COPY e_commerce.website_sessions (website_session_id, created_at,user_id , is_repeat_session,utm_source,utm_campaign,utm_content,device_type,http_referer)
FROM '/usr/databases/Project two/website_sessions.csv'
DELIMITER ','
CSV HEADER;

CREATE TABLE e_commerce.website_pageviews (
    website_pageview_id INT PRIMARY KEY,
    created_at TIMESTAMP NOT NULL,
    website_session_id INT NOT NULL,
    pageview_url TEXT,

    CONSTRAINT fk_session_pageviews
    FOREIGN KEY (website_session_id)
    REFERENCES e_commerce.website_sessions(website_session_id)
);

COPY e_commerce.website_pageviews (website_pageview_id, created_at,website_session_id , pageview_url)
FROM '/usr/databases/Project two/website_pageviews.csv'
DELIMITER ','
CSV HEADER;

ALTER TABLE e_commerce.orders
ADD CONSTRAINT fk_orders_session
FOREIGN KEY (website_session_id)
REFERENCES e_commerce.website_sessions(website_session_id);

ALTER TABLE e_commerce.orders
ADD CONSTRAINT fk_orders_primary_product
FOREIGN KEY (primary_product_id)
REFERENCES e_commerce.products(product_id);

ALTER TABLE e_commerce.order_items
ADD CONSTRAINT fk_product
FOREIGN KEY (product_id)
REFERENCES e_commerce.products(product_id);

ALTER TABLE e_commerce.products
ALTER COLUMN product_name SET NOT NULL;
--here we are incvestigating the date of the data in months
select DISTINCT date_trunc('month',created_at) as month_num 
FROM e_commerce.website_sessions
ORDER BY month_num ASC ;

--here we are looking for the repeted users who have more than 1 sessions which means they are returned users 
SELECT user_id ,count(*) as repeated 
FROM e_commerce.website_sessions
GROUP BY user_id 
having count(*) > 1;

-- we are investigating in the number of returning sessions and the percentage from the new commers
select count(*) as count_num ,
is_repeat_session 
FROM e_commerce.website_sessions
GROUP BY is_repeat_session ;


--here we are investigating in the users with 1 sessions but having the flag for returning users is true 
--basicly it was understanding the system and we store the data and if there is a returning users from beyond our data with 1 sessions in the data that we have
SELECT user_id,
COUNT(*) AS total_sessions,
bool_or(is_repeat_session) AS any_repeat
FROM e_commerce.website_sessions
GROUP BY user_id
HAVING COUNT(*) = 1 and bool_or(is_repeat_session) = TRUE
ORDER BY total_sessions DESC
LIMIT 20;

--investigationg in the differnce between number of users and returning sessions 
--earlier we found out that 57 K of users are returned users but we have around 71 K returning sessions 
--so we want to know why the diffrence
WITH sessions_repeted as (
select user_id ,
count(*) as sessions_count
FROM e_commerce.website_sessions
GROUP BY user_id
)
SELECT 
count(*) as number_of_users ,
sessions_count
FROM sessions_repeted
GROUP BY sessions_count
ORDER BY sessions_count ASC ;

-- cleaning the final table for website_sessions after cleaning the table
CREATE or REPLACE VIEW website_session_marketing as 
WITH cleaned_table as ( 
SELECT 
website_session_id,
created_at,
user_id,
is_repeat_session,
NULLIF(utm_source , 'NULL') as clean_source ,
NULLIF(utm_campaign , 'NULL') as clean_campaign ,
NULLIF(utm_content , 'NULL' ) as clean_content ,
device_type,
NULLIF(http_referer,'NULL') AS clean_referer
FROM e_commerce.website_sessions 
)
SELECT 
website_session_id ,
created_at ,
user_id ,
is_repeat_session ,
CASE 
    WHEN clean_source is NULL AND clean_referer is NULL THEN 'direct'
    WHEN clean_source is NULL and clean_referer is NOT NULL THEN 'organic'  
    ELSE  clean_source
END as campaign_source ,
CASE 
    WHEN clean_campaign is NULL AND clean_referer is NULL THEN 'direct'
    WHEN clean_campaign is NULL and clean_referer is NOT NULL THEN 'organic'  
    ELSE  clean_campaign
END campaign_type ,
CASE 
    WHEN clean_content is NULL AND clean_referer is NULL THEN 'direct'
    WHEN clean_content is NULL and clean_referer is NOT NULL THEN 'organic'  
    ELSE  clean_content
END as content_type ,
device_type ,
CASE 
    WHEN clean_referer is NULL THEN 'direct'  
    ELSE  clean_referer
END as http_referer_type 
FROM cleaned_table ;





--- gona cancel this
WITH merged_table as(
SELECT 
s.website_session_id ,
s.user_id ,
s.is_repeat_session ,
s.campaign_source ,
s.campaign_type ,
s.content_type ,
s.device_type ,
s.http_referer_type ,
p.website_pageview_id,
p.created_at ,
p.pageview_url
FROM e_commerce.website_pageviews p
left JOIN e_commerce.website_session_marketing s on s.website_session_id =p.website_session_id 
) ,
-- q1- what is the number of the users ?
count_users as (SELECT  user_id ,
count(*) as users_num
FROM merged_table
GROUP BY  DISTINCT user_id
HAVING count(*) > 1 )
-- q2- what is the number of the visits for each campaign source, device type and pageview url?
SELECT campaign_source, device_type, pageview_url, COUNT(*) as visits
FROM merged_table
GROUP BY campaign_source, device_type, pageview_url
ORDER BY visits DESC;






CREATE OR REPLACE VIEW e_commerce.session_summary as 
with ranked_pages AS(
website_session_id ,
count(*) as pageview_count ,
min(created_at) as session_start ,
max(created_at) as session_end ,
extract(epoch from max(created_At) - min(created_At)) as session_duration_sec ,
CASE 
    WHEN count(*) > 1 AND extract(epoch from max(created_At) - min(created_At)) > 86400 THEN 1 
    ELSE  0
END as Bounce_flag ,
 case 
 when min(created_at)  OVER (PARTITION BY website_session_id ) > then pageview_url
END as start_page ,
 case 
 when max(created_at) OVER (PARTITION BY website_session_id )>00:00 then pageview_url
END as end_page 
FROM e_commerce.website_pageviews
GROUP BY website_session_id

SELECT * FROM e_commerce.session_summary
WHERE session_duration_sec > 1500;

CREATE OR REPLACE VIEW e_commerce.session_summary AS
WITH ranked_pages AS (
    SELECT
        website_session_id,
        pageview_url,
        created_at,

        ROW_NUMBER() OVER (
            PARTITION BY website_session_id
            ORDER BY created_at ASC
        ) AS rn_first,

        ROW_NUMBER() OVER (
            PARTITION BY website_session_id
            ORDER BY created_at DESC
        ) AS rn_last

    FROM e_commerce.website_pageviews
)
SELECT
    rp.website_session_id,

    COUNT(*) AS pageviews_count,
    MIN(created_at) AS session_start,
    MAX(created_at) AS session_end,

    EXTRACT(EPOCH FROM MAX(created_at) - MIN(created_at)) AS session_duration_sec,

    CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS bounce_flag,

    MAX(CASE WHEN rn_first = 1 THEN pageview_url END) AS entry_page,
    MAX(CASE WHEN rn_last  = 1 THEN pageview_url END) AS exit_page

FROM ranked_pages rp
GROUP BY rp.website_session_id;


CREATE or REPLACE VIEW e_commerce.session_summary as
WITH Pre_page as (
    SELECT
     website_session_id ,
    pageview_url ,
    created_at ,
    ROW_NUMBER() OVER (PARTITION BY website_session_id ORDER BY created_at ASC) as rn_first ,
    ROW_NUMBER() OVER (PARTITION BY website_session_id ORDER BY created_at DESC) as rn_last 
    FROM e_commerce.website_pageviews
)
SELECT
pg.website_session_id ,
count(*) as pageviews_count ,
min(created_at) As session_start ,
max(created_at) as session_end ,
 extract(epoch from max(created_at) - min(created_at))as session_duration_sec ,
CASE 
    WHEN count(*) = 1 AND  extract(epoch from max(created_at) - min(created_at)) > 86400 THEN 1
    ELSE 0
END as bounce_flag ,
max(CASE WHEN rn_first = 1 then pageview_url END ) as entry_page ,
max(case when rn_last = 1 then pageview_url end) as exit_page
FROM pre_page pg
GROUP BY pg.website_session_id ;




CREATE or REPLACE VIEW e_commerce.session_summary as
 WITH entry_page as (
    select DISTINCT ON (website_session_id) 
    website_session_id ,
    pageview_url as start_page
    FROM e_commerce.website_pageviews
    ORDER BY website_session_id , created_at ASC
) ,
last_page as (
    select DISTINCT ON (website_session_id)
    website_session_id , 
    pageview_url as exit_page 
    FROM e_commerce.website_pageviews 
    ORDER BY website_session_id , created_at DESC
) ,
first_product as (
    SELECT DISTINCT ON (website_session_id)
    website_session_id ,
    pageview_url as first_product_viewed
    FROM e_commerce.website_pageviews 
    WHERE pageview_url IN('/the-original-mr-fuzzy',
                '/the-birthday-sugar-panda',
                '/the-hudson-river-mini-bear',
                '/the-forever-love-bear')
    ORDER BY website_session_id ,created_at ASC
) ,
final_look as(
SELECT
pg.website_session_id ,
count(*) as pageviews_count ,
min(created_at) As session_start ,
max(created_at) as session_end ,
extract(epoch from max(created_at) - min(created_at)) / 60 as session_duration_min ,
CASE 
    WHEN count(*) = 1  THEN 1
    ELSE 0
END as bounce_flag ,
 ep.start_page ,
 lp.exit_page ,
 fp.first_product_viewed
FROM e_commerce.website_pageviews pg 
JOIN entry_page ep ON pg.website_session_id = ep.website_session_id
JOIN last_page lp ON pg.website_session_id = lp.website_session_id
left JOIN first_product fp ON fp.website_session_id = pg.website_session_id
GROUP BY 
pg.website_session_id ,
ep.start_page ,
lp.exit_page ,
fp.first_product_viewed 
)
SELECT
fl.website_session_id,
fl.pageviews_count ,
fl.session_start ,
fl.session_end,
fl.session_duration_min,
fl.bounce_flag,
fl.start_page,
fl.exit_page ,
COALESCE(fl.first_product_viewed ,'No Views')as first_product_viewed
FROM final_look fl ;


SELECT * FROM e_commerce.session_summary ;

SELECT * FROM e_commerce.website_pageviews;

create or REPLACE VIEW e_commerce.pageview_with_stages as
(
    SELECT 
    website_pageview_id ,
    created_at ,
    website_session_id ,
    pageview_url ,
    CASE 
       WHEN pageview_url IN ( '/home','/lander-1','/lander-2','/lander-3','/lander-4','/lander-5' )THEN 'Landing'
       WHEN pageview_url IN ( '/products', '/the-original-mr-fuzzy','/the-birthday-sugar-panda','/the-hudson-river-mini-bear','/the-forever-love-bear' )THEN 'Product' 
       WHEN pageview_url = '/cart' THEN 'Cart' 
       WHEN pageview_url IN ('/shipping','/billing','/billing-2') THEN 'Checkout'
       WHEN pageview_url = '/thank-you-for-your-order' THEN 'Purchase'
       ELSE 'Other' 
    END as funnel_stage
    FROM e_commerce.website_pageviews
)

select * from  e_commerce.pageview_with_stages


CREATE OR replace view e_commerce.order_Summary_view as
WITH refund_order as
(
    SELECT order_id ,
    sum(refund_amount_usd) as total_refund
    FROM e_commerce.order_item_refunds
    GROUP BY order_id
)
SELECT o.order_id,
o.created_at ,
o.website_session_id,
o.user_id,
o.primary_product_id ,
o.items_purchased,
CASE 
   WHEN COALESCE(ro.total_refund,0) > 0 THEN 1 ELSE 0
END AS is_refunded,
o.price_usd as gross_revenue,
o.cogs_usd,
(o.price_usd - o.cogs_usd) as gross_margin,
COALESCE(ro.total_refund,0) as total_refunds ,
(o.price_usd - COALESCE(ro.total_refund,0)) AS net_revenue
from e_commerce.orders o
left JOIN refund_order ro on ro.order_id = o.order_id ;

SELECT * from e_commerce.order_summary_view;


CREATE OR REPLACE VIEW e_commerce.order_items_enriched_view AS

WITH refund_per_item AS (
    SELECT
        order_item_id,
        SUM(refund_amount_usd) AS refund_amount_usd
    FROM e_commerce.order_item_refunds
    GROUP BY order_item_id
)


SELECT * from e_commerce.order_items ;


CREATE or REPLACE view e_commerce.order_item_view as
SELECT oi.order_item_id ,
oi.order_id ,
oi.product_id ,
oi.created_at ,
oi.is_primary_item ,
oi.price_usd ,
oi.cogs_usd,
COALESCE(oir.refund_amount_usd,0::NUMERIC(10,2)) as refund_amount_usd ,
CASE 
    WHEN COALESCE(oir.refund_amount_usd,0::NUMERIC(10,2)) > 0  THEN  1
    ELSE  0
END as refund_flag
FROM e_commerce.order_items oi
left JOIN e_commerce.order_item_refunds oir on oir.order_item_id = oi.order_item_id ;



SELECT * FROM e_commerce.order_item_view
WHERE is_primary_item ='false' AND refund_amount_usd > 0;

SELECT order_id , count(*) FROM e_commerce.order_item_view 
GROUP BY order_id
HAVING count(*) > 1 ;

