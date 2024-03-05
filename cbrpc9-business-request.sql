USE retail_events_db;

-- 1. Products with a base price greater than 500 that have a 'buy one get one free' (BOGOF) promotion
SELECT DISTINCT 
    fe.product_code AS 'Product Code', 
    dp.product_name AS 'Product Name',
    fe.base_price AS 'Base Price (₹)',
    fe.promo_type AS 'Promo Type'
FROM fact_events AS fe 
INNER JOIN dim_products AS dp ON fe.product_code = dp.product_code
WHERE fe.promo_type = 'BOGOF' AND fe.base_price > 500
ORDER BY fe.base_price DESC;


-- 2. Number of stores in each city, sorted in descending order by store count
SELECT 
    city AS 'City', 
    COUNT(store_id) AS 'Store Count' 
FROM dim_stores
GROUP BY city
ORDER BY COUNT(store_id) DESC;

-- 3. Total revenue before and after promotions for each campaign
SELECT 
    dc.campaign_name AS 'Campaign Name', 
    SUM(fe.base_price * fe.`quantity_sold(before_promo)` / 1000000) AS 'Total Revenue Before Promotion (million ₹)',
    SUM(
        CASE
            WHEN fe.promo_type = '50% OFF' THEN (fe.base_price * fe.`quantity_sold(after_promo)` * (1 - 0.5))
            WHEN fe.promo_type = '33% OFF' THEN (fe.base_price * fe.`quantity_sold(after_promo)` * (1 - 0.33))
            WHEN fe.promo_type = '25% OFF' THEN (fe.base_price * fe.`quantity_sold(after_promo)` * (1 - 0.25))        
            WHEN fe.promo_type = '500 Cashback' THEN ((fe.base_price - 500) * fe.`quantity_sold(after_promo)`) 
            WHEN fe.promo_type = 'BOGOF' THEN (fe.base_price * fe.`quantity_sold(after_promo)`)     
        END / 1000000
    ) AS 'Total Revenue After Promotion (million ₹)'
FROM fact_events AS fe
INNER JOIN dim_campaigns AS dc ON fe.campaign_id = dc.campaign_id
GROUP BY dc.campaign_name;

-- 4. Incremental Sold Quantity (ISU%) of each category during the Diwali campaign
SELECT
    DENSE_RANK() OVER (ORDER BY isu_pct DESC) AS 'Rank',
    ctgy AS 'Category',
    isu_pct AS 'ISU (%)',
    SUM(qty_before) AS 'Quantity Before Promotion',
    SUM(qty_after) AS 'Quantity After Promotion'
FROM (
    SELECT
        dp.category AS ctgy,
        SUM(fe.`quantity_sold(before_promo)`) AS qty_before,
        SUM(fe.`quantity_sold(after_promo)`) AS qty_after,
        SUM((fe.`quantity_sold(after_promo)` - fe.`quantity_sold(before_promo)`)) / SUM(fe.`quantity_sold(before_promo)`) * 100 AS isu_pct
    FROM fact_events AS fe
    INNER JOIN dim_campaigns AS dc ON fe.campaign_id = dc.campaign_id
    INNER JOIN dim_products AS dp ON fe.product_code = dp.product_code
    WHERE dc.campaign_name = 'Diwali'
    GROUP BY dp.category
) AS isu_calc
GROUP BY ctgy;

-- 5. Top 5 products with their category, ranked by Incremental Revenue Percentage (IR%)
SELECT 
	DENSE_RANK() OVER(ORDER BY ir_calc.ir DESC) AS 'Rank',
    dp.product_name AS 'Product Name',
    dp.category AS 'Category',
    ir_calc.ir AS 'IR (%)',
    ir_calc.total_rev_before / 1000000 AS 'Total Revenue Before Promotion (million ₹)',
    ir_calc.total_rev_after / 1000000 AS 'Total Revenue After Promotion (million ₹)'
FROM (
    SELECT 
        product_code,
        ((SUM(rev_after_promo) - SUM(rev_before_promo)) / SUM(rev_before_promo) * 100) AS ir,
        SUM(rev_before_promo) AS total_rev_before,
        SUM(rev_after_promo) AS total_rev_after
    FROM (
        SELECT 
            *,
            base_price * `quantity_sold(before_promo)` AS rev_before_promo,
            CASE
                WHEN promo_type = '50% OFF' THEN (base_price * `quantity_sold(after_promo)` * (1 - 0.5))
                WHEN promo_type = '33% OFF' THEN (base_price * `quantity_sold(after_promo)` * (1 - 0.33))
                WHEN promo_type = '25% OFF' THEN (base_price * `quantity_sold(after_promo)` * (1 - 0.25))
                WHEN promo_type = '500 Cashback' THEN ((base_price - 500)* `quantity_sold(after_promo)`)
                WHEN promo_type = 'BOGOF' THEN (base_price * `quantity_sold(after_promo)` * (1 - 0.5))
            END AS rev_after_promo
        FROM fact_events
    ) AS rev_calc
    GROUP BY product_code
) AS ir_calc
INNER JOIN dim_products AS dp ON ir_calc.product_code = dp.product_code
ORDER BY ir_calc.ir DESC
LIMIT 5;