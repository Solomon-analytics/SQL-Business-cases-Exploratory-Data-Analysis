/*-------------------------------------------------------------------------------------
    SECTION 1a: Sales Trends Over the Years
    Purpose: Analyze yearly sales performance & order volumes
-------------------------------------------------------------------------------------*/
SELECT
    YEAR(Order_Creation_date) AS Order_creation_Year,
    SUM(IFNULL(ordered_quantity, 0)) AS quantity_ordered
FROM sales_details_silver__layer
WHERE Order_Creation_date IS NOT NULL
GROUP BY Order_creation_Year
ORDER BY quantity_ordered DESC;


/*-------------------------------------------------------------------------------------
    SECTION 1b: Net Sales & Order Performance
    Purpose: Calculate net ordered quantities and net sales after cancellations/returns
-------------------------------------------------------------------------------------*/
SELECT
    YEAR(SO.Order_Creation_date) AS Order_creation_Year,
    SUM(COALESCE(SO.ordered_quantity, 0)) AS quantity_ordered,
    SUM(COALESCE(SO.ordered_quantity) - (COALESCE(so.cancelled_quantity) 
       + COALESCE(so.returned_quantity))) AS Net_ordered_quantity,
    SUM(((COALESCE(SO.ordered_quantity) - (COALESCE(so.cancelled_quantity) 
       + COALESCE(so.returned_quantity))) * p.product_price_USD)) AS Net_sales
FROM sales_details_silver__layer SO
JOIN product_silver_layer P ON SO.product_id = P.product_id
GROUP BY Order_creation_Year
ORDER BY quantity_ordered DESC;


/*-------------------------------------------------------------------------------------
    SECTION 1c: Monthly Sales Trends & Seasonality
    Purpose: Granular view of monthly revenue performance with ranking
-------------------------------------------------------------------------------------*/
SELECT
    Order_creation_Year,
    Order_creation_Month,
    quantity_ordered,
    Net_ordered_quantity,
    Net_sales,
    ROW_NUMBER() OVER (
        PARTITION BY Order_creation_Year, Order_Creation_Month
        ORDER BY Net_sales DESC
    ) AS Month_Rank
FROM (
    SELECT 
        YEAR(SO.Order_Creation_date) AS Order_creation_Year,
        MONTH(SO.Order_Creation_date) AS Order_Creation_Month,
        SUM(COALESCE(SO.ordered_quantity, 0)) AS quantity_ordered,
        SUM(COALESCE(SO.ordered_quantity) - (COALESCE(so.cancelled_quantity) 
           + COALESCE(so.returned_quantity))) AS Net_ordered_quantity,
        SUM(((COALESCE(SO.ordered_quantity) - (COALESCE(so.cancelled_quantity) 
           + COALESCE(so.returned_quantity))) * p.product_price_USD)) AS Net_sales
    FROM sales_details_silver__layer SO
    JOIN product_silver_layer P ON SO.product_id = P.product_id
    WHERE SO.Order_Creation_date IS NOT NULL
    GROUP BY YEAR(SO.Order_Creation_date), MONTH(SO.Order_Creation_date)
) T
ORDER BY Order_creation_Year, Net_sales DESC;


/*=====================================================================================
 SECTION 2: Cumulative Sales Analysis
    - Analyze progression of net sales over time
    - Calculate running total, previous month, and next month sales
    - Identify long-term growth trends and sales momentum

=====================================================================================*/

WITH Net_sales_table  AS (
SELECT
YEAR(SO.Order_Creation_Date) AS Order_Year,
MONTH(SO.Order_Creation_Date) AS Order_Month_Num,
DATE_FORMAT(Order_Creation_Date, '%Y-%M') AS Order_Month,
SUM((COALESCE(so.ordered_quantity) - (COALESCE(so.returned_quantity) + COALESCE(so.cancelled_quantity))) * P.product_price_USD) AS Net_sales
FROM sales_details_silver__layer SO
JOIN product_silver_layer P ON SO.product_id = p.product_id
GROUP BY Order_Month, Order_Year, Order_Month_Num
)
SELECT 
Order_Month,
Net_sales,
SUM(Net_sales) OVER (ORDER BY Order_Year,Order_Month_Num) AS Running_Net_Sales,
LAG(Net_sales) OVER (ORDER BY Order_Year,Order_Month_Num) AS Previous_month_Net_sales,
LEAD(Net_sales) OVER (ORDER BY Order_Year,Order_Month_Num) AS Next_Month_Net_sales
FROM Net_sales_table;


/*==============================================================================================================
SECTION 3: Product Category Performance Analyzer
==============================================================================================================

Purpose:
- This query analyzes the performance of product categories by comparing current net order values 
  against key benchmarks, such as average order value and previous year order value.

Key Analysis:
1. Compares current net order value to the average net order value for the product category.
2. Compares current year net order value to the previous year’s net order value.
3. Flags each product category as 'Above Average', 'Below Average', or 'Average'.
4. Flags year-over-year performance as 'Exceed previous Year', 'Less than previous Year', or 'No change'.
5. Generates a row number per order year for ranking purposes.
==============================================================================================================*/

SELECT
Order_Year,
product_category,
Net_order_Value,
AVG(Net_order_Value) OVER (PARTITION BY product_category) AS avg_net_order_value_for_product,
Net_order_Value - AVG(Net_order_Value) OVER (PARTITION BY product_category) AS product_Average_vs_value_variation,
CASE 
     WHEN Net_order_Value - AVG(Net_order_Value) OVER (PARTITION BY product_category) > 0 THEN 'Above Average'
     WHEN Net_order_Value - AVG(Net_order_Value) OVER (PARTITION BY product_category) < 0 THEN 'Below Average'
     ELSE 'Average' END AS product_Average_vs_value_check,
     LAG(Net_order_Value) OVER (PARTITION BY product_category ORDER BY order_year) AS previous_year_order_value,
Net_order_Value - LAG(Net_order_Value) OVER (PARTITION BY product_category ORDER BY order_year) AS Product_current_vs_previous_year_value,
CASE 
     WHEN Net_order_Value - LAG(Net_order_Value) OVER (PARTITION BY product_category ORDER BY order_year) > 0 THEN 'Exceed previous Year'
     WHEN Net_order_Value - LAG(Net_order_Value) OVER (PARTITION BY product_category ORDER BY order_year) < 0 THEN 'Less than previous Year'
     WHEN Net_order_Value - LAG(Net_order_Value) OVER (PARTITION BY product_category ORDER BY order_year) = 0 THEN 'No change'
     ELSE NULL END AS Product_current_vs_previous_year_value_check,
ROW_NUMBER() OVER (PARTITION BY order_year) as row_num
FROM(
SELECT
YEAR(SO.Order_Creation_Date) AS Order_Year,
P.product_category AS product_category,
SUM(((COALESCE(SO.ordered_quantity) - (COALESCE(so.cancelled_quantity) + COALESCE(so.returned_quantity))) * p.product_price_USD)) AS Net_order_Value
FROM sales_details_silver__layer SO
JOIN product_silver_layer P ON SO.product_id = p.product_id
WHERE SO.Order_Creation_Date IS NOT NULL
GROUP BY Order_Year, product_category
) T
GROUP BY Order_Year,
product_category,
Net_order_Value;


/*--------------------------------------------------------------------------------------------------------------------------
SECTION 4: Part-To-Whole Analysis
## this query reveals how a category is performing compared to the overall,
allowing business to uncover insights on which category has the greatest impact on the business
---------------------------------------------------------------------------------------------------------------------------*/

/*--------------------------------------------------------------------------------------------------------------------------
   ## Category
---------------------------------------------------------------------------------------------------------------------------*/
SELECT
Product_category,
Net_order_Value,
SUM(Net_order_Value) OVER () AS Overall_order_value,
CONCAT(ROUND((CAST(Net_order_Value AS DECIMAL(10,3)) / SUM(Net_order_Value) OVER ()) * 100, 2), '%') AS Product_category_percentage_contribution
FROM(
SELECT
P.product_category AS Product_category,
SUM(((COALESCE(SO.ordered_quantity) - (COALESCE(so.cancelled_quantity) + COALESCE(so.returned_quantity))) * p.product_price_USD)) AS Net_order_Value
FROM sales_details_silver__layer SO
JOIN product_silver_layer P ON SO.product_id = p.product_id
GROUP BY P.product_category) T
GROUP BY Product_category
ORDER BY Product_category_percentage_contribution DESC;


/*-------------------------------------------------------------------------------------------------------
   ## Products
   -----------------------------------------------------------------------------------------------------*/
SELECT
Product_name,
Net_order_Value,
SUM(Net_order_Value) OVER () AS Overall_order_value,
CONCAT(ROUND((CAST(Net_order_Value AS DECIMAL(10,3)) / SUM(Net_order_Value) OVER ()) * 100, 2), '%') AS Product_name_percentage_contribution
FROM(
SELECT
P.product_name AS Product_name,
SUM(((COALESCE(SO.ordered_quantity) - (COALESCE(so.cancelled_quantity) + COALESCE(so.returned_quantity))) * p.product_price_USD)) AS Net_order_Value
FROM sales_details_silver__layer SO
JOIN product_silver_layer P ON SO.product_id = p.product_id
GROUP BY P.product_name) T
GROUP BY product_name
ORDER BY product_name_percentage_contribution DESC;

/*------------------------------------------------------------------------------------------------------------------------
## Stores contribution
-------------------------------------------------------------------------------------------------------------------------*/

SELECT
Store_Name,
Net_order_Value,
SUM(Net_order_Value) OVER () AS Net_order_value,
CONCAT(ROUND((CAST(Net_order_Value AS DECIMAL(10,3)) / SUM(Net_order_Value) OVER ()) * 100, 2), '%') AS Store_percentage_contribution
FROM(
SELECT
S.store_location_id AS Store_Name,
SUM(((COALESCE(SO.ordered_quantity) - (COALESCE(so.cancelled_quantity) + COALESCE(so.returned_quantity))) * p.product_price_USD)) AS Net_order_Value
FROM sales_details_silver__layer SO
JOIN product_silver_layer P ON SO.product_id = p.product_id
LEFT JOIN Store_silver_layer S ON S.store_location_id = SO.store_location_id
GROUP BY S.store_location_id) T
GROUP BY Store_Name
ORDER BY Store_percentage_contribution ASC; ## 21087

/*-------------------------------------------------------------------------------------------------------------
## Sales_Person contribution to total order value
--------------------------------------------------------------------------------------------------------------*/

SELECT
Sales_Rep,
Sales_Rep_id,
Store_Name,
Net_order_Value,
SUM(Net_order_Value) OVER () AS Overall_order_value,
CONCAT(ROUND((CAST(Net_order_Value AS DECIMAL(10,3)) / SUM(Net_order_Value) OVER ()) * 100, 2), '%') AS Sales_Rep_percentage_contribution
FROM(
SELECT
Sp.sales_person_full_name AS Sales_Rep,
Sp.sales_person_id AS Sales_Rep_id,
S.store_location_id AS Store_Name,
SUM(((COALESCE(SO.ordered_quantity) - (COALESCE(so.cancelled_quantity) + COALESCE(so.returned_quantity))) * p.product_price_USD)) AS Net_order_Value
FROM sales_details_silver__layer SO
LEFT JOIN product_silver_layer P ON SO.product_id = p.product_id
LEFT JOIN sales_person_silver_layer SP ON Sp.sales_person_id = SO.sales_person_id
LEFT JOIN Store_silver_layer S ON S.store_location_id = SO.store_location_id
GROUP BY Sp.sales_person_full_name, Sp.sales_person_id, S.store_location_id) T
GROUP BY Sales_Rep, Sales_Rep_id, Store_Name
ORDER BY Sales_Rep_percentage_contribution DESC;



/*--------------------------------------------------------------------------------------------------------------------
 SECTION 5: Which customers purchased from multiple store locations across different countries within the same calendar year, 
   and what was their net revenue contributionm of these “multi-country” customers to global sales?
  ----------------------------------------------------------------------------------------------------------------------*/

 SELECT
 Customer_id,
 Customer_Name,
 order_year,
 Net_revenue,
 ROW_NUMBER() OVER (PARTITION BY  Order_year) AS row_num
 FROM(
 SELECT
 C.customer_id,
 C.customer_full_name AS Customer_name,
 YEAR(so.order_creation_date) AS Order_year,
 COUNT(DISTINCT S.store_country) AS Store_location_country,
 SUM((SO.Ordered_quantity - (SO.cancelled_quantity + so.returned_quantity)) * P.product_price_usd) AS Net_revenue
 FROM sales_details_silver__layer SO
 LEFT JOIN customer_silver_layer C ON C.customer_id = SO.customer_id
 LEFT JOIN product_silver_layer P ON P.product_id = SO.product_id
 LEFT JOIN store_silver_layer S ON S.Store_Location_Id = SO.Store_Location_Id
 GROUP BY Order_year, C.customer_id, Customer_name)T
 WHERE Store_location_country > 1
 ORDER BY Net_revenue DESC;
 
 
 /*--------------------------------------------------------------------------------------------------------------------
   SECTION 6: List all customers and their most recent shipment details (tracking number, carrier, delivery date), 
   ensuring even customers who have never received shipments are included.
  ----------------------------------------------------------------------------------------------------------------------*/
SELECT
C.customer_id,
C.customer_full_name AS Customer_Name,
S.Recent_Ship_date,
S.delivery_date,
S.tracking_number,
S.carrier_type
FROM customer_silver_layer C
LEFT JOIN (
    SELECT
        OS.customer_id,
        OS.ship_date AS Recent_Ship_date,
        OS.delivery_date,
        OS.tracking_number,
        OS.carrier_type
    FROM order_ship_silver_layer OS
    INNER JOIN (
        -- find the latest ship_date per customer
        SELECT 
            customer_id, 
            MAX(ship_date) AS MaxShipDate
        FROM order_ship_silver_layer
        GROUP BY customer_id
    ) latest 
    ON OS.customer_id = latest.customer_id 
   AND OS.ship_date = latest.MaxShipDate
) S
ON C.customer_id = S.customer_id;
