/*===================================================================================================================
 Purpose    : Provides analysis of product performance by revenue and quantity 
              for the current year/month. Identifies top-selling products and 
              underperforming products relative to peers.
 -------------------------------------------------------------------------------------------------------------------
 Description:
 - Aggregates order and product data at the monthly level
 - Calculates product revenue and quantity purchased
 - Uses DENSE_RANK to rank products by revenue within each month/year
 - Flags products as performing or underperforming compared to monthly averages
 - Enables stakeholders to monitor product sales performance
 ===================================================================================================================*/
 
 CREATE OR REPLACE VIEW top_and_underperforming_products AS 

 WITH order_table AS (
 SELECT
 YEAR(order_creation_date) AS Order_creation_year,
 DATE_FORMAT(order_creation_date, '%M') AS order_creation_month_name,
 MONTH(order_creation_date) AS order_creation_month_num,
 product_id,
 COALESCE(ordered_quantity, 0) AS ordered_quantity,
 COALESCE(returned_quantity, 0) AS returned_quantity,
 COALESCE(cancelled_quantity, 0) AS cancelled_quantity,
 COALESCE(ordered_quantity, 0) - (COALESCE(returned_quantity, 0) + COALESCE(cancelled_quantity, 0)) AS quantity_purchased
 FROM sales_details_silver__layer 
),
 
 Product_table as (
 SELECT
 product_id,
 product_name,
 product_price_usd
 FROM product_silver_layer
 ),
 
joint_table AS (
SELECT
so.Order_creation_year,
order_creation_month_name,
order_creation_month_num,
P.product_id,
p.product_name,
SUM(so.quantity_purchased) AS quantity_purchased,
SUM(so.quantity_purchased * p.product_price_usd) AS Revenue
FROM Product_table p
LEFT JOIN order_table SO ON so.product_id = p.product_id
GROUP BY P.product_id,
p.product_name, so.Order_creation_year,
order_creation_month_name,
order_creation_month_num)

SELECT 
Product_id,
product_name,
order_creation_year,
order_creation_month_name,
quantity_purchased AS current_month_purchased,
Revenue AS current_product_month_revenue,
DENSE_RANK() OVER (PARTITION BY order_creation_year, order_creation_month_num ORDER BY revenue DESC) AS month_revenue_product_rank,
SUM(revenue) OVER (PARTITION BY order_creation_year, order_creation_month_num) AS current_month_revenue_accross_all_products,


ROUND(AVG(revenue) OVER (PARTITION BY order_creation_year, order_creation_month_num), 2) AS current_month_avg_revenue,
CASE
    WHEN Revenue < ROUND(AVG(revenue) OVER (PARTITION BY order_creation_year, order_creation_month_num), 2)
    THEN 'Underperforming (Low Revenue contribution)'
    WHEN Revenue >= ROUND(AVG(revenue) OVER (PARTITION BY order_creation_year, order_creation_month_num), 2)
    THEN 'Performing' END AS product_category_monthly_rating
FROM joint_table
WHERE order_creation_year IN (2025)
ORDER BY order_creation_month_num ASC;



/*===================================================================================================================
 Purpose    : Provides a consolidated view of customer sales performance and behaviour, 
              combining transactional sales data with customer information.  
 -------------------------------------------------------------------------------------------------------------------
 Description:
 - Joins sales fact table with customer and product dimensions at the order-line level
 - Aggregates customer activity across orders (sales, returns, cancellations, order lifespan)
 - Calculates KPIs including:
      * Total purchases and distinct products purchased
      * Gross sales, Net sales, Average order value, Average monthly net sales
      * Return rate, Cancellation rate, Order completion rate
      * Customer lifespan (in months), first/last purchase dates, days since last purchase
 - Segments customers with flags:
      * Active/Inactive status
      * Customer tier (Tier-1 / Tier-2) based on lifetime value and activity
      * Churn risk category (High / Medium / Low)
 - Enables stakeholders to track customer performance, retention, and lifetime value
 ===================================================================================================================*/
 
 /*--------------------------------------------------------------------------------------------------------------------------------------------
  1. Base Query: consolidate fact table, sales orders with each of the dimension table, customer & product information at the order line level
  --------------------------------------------------------------------------------------------------------------------------------------------*/
CREATE OR REPLACE VIEW customer_sales_report AS
WITH Base_Table AS (
SELECT
C.customer_id AS customer_number,
C.customer_full_name AS Customer_Name,
C.customer_address AS Customer_Address,
C.customer_state AS Customer_state,
C.customer_country AS Customer_Country,
C.customer_postcode AS Customer_postcode,
SO.order_number,
SO.Order_id,
SO.product_id,
SO.product_number,
SO.ordered_quantity,
SO.returned_quantity,
SO.cancelled_Quantity,
P.product_price_USD,
SO.order_creation_date
FROM sales_details_silver__layer SO
LEFT JOIN customer_silver_layer C ON C.customer_id = SO.customer_id
LEFT JOIN Product_silver_layer P ON P.product_id = SO.product_id),

/*-------------------------------------------------------------------------------------------------------------
  2. Customer Aggregates: summarise customer activity across all orders (sales, returns, cancellations, lifespan)
  ----------------------------------------------------------------------------------------------------------------*/

Aggregated_Table AS ( 
SELECT 
customer_number,
Customer_Name,
Customer_Address,
Customer_state,
Customer_Country,
Customer_postcode,
COUNT(DISTINCT Order_id) AS Total_Occurence_Of_Customer_Purchase,
COUNT(DISTINCT product_id) AS Distinct_product_purchased,
SUM(COALESCE(Ordered_Quantity, 0)) AS Ordered_Quantity,
SUM(COALESCE(Ordered_Quantity, 0) - (COALESCE(returned_Quantity, 0) + COALESCE(cancelled_quantity, 0))) AS Actual_Quantity_purchased,
SUM(COALESCE(returned_Quantity, 0)) AS Quantity_of_product_returned,
SUM(COALESCE(cancelled_quantity, 0)) AS Quantity_of_product_cancelled,
SUM(((COALESCE(ordered_quantity) - (COALESCE(cancelled_quantity) + COALESCE(returned_quantity))) * product_price_USD)) AS Net_Sales,
SUM(COALESCE(Ordered_Quantity, 0) * Product_price_usd) AS Gross_sales,
CASE
    WHEN COUNT(DISTINCT Order_id) > 0
    THEN SUM(((COALESCE(ordered_quantity) - (COALESCE(cancelled_quantity) + COALESCE(returned_quantity))) * product_price_USD)) / COUNT(DISTINCT Order_id)
    END AS Average_Order_Value,
MAX(order_creation_date) AS Customer_Last_Order_Date,
MIN(order_creation_date) AS Customer_First_Order_Date,
TIMESTAMPDIFF(MONTH, MIN(order_creation_date), MAX(order_creation_date)) AS Customer_Lifepan_Month
FROM Base_Table
GROUP BY customer_number,
Customer_Name,
Customer_Address,
Customer_state,
Customer_Country,
Customer_postcode)

/*-------------------------------------------------------------------------------------------------------------
  3. Final Customer Kpi: returns customer level metrics and flags
  ----------------------------------------------------------------------------------------------------------------*/

SELECT
customer_number,
Customer_Name,
Customer_Address,
Customer_state,
Customer_Country,
Customer_postcode,
Total_Occurence_Of_Customer_Purchase,
Ordered_Quantity,
Quantity_of_product_returned,
Quantity_of_product_cancelled,
CONCAT(ROUND((Quantity_of_product_returned * 100) / IFNULL(Ordered_Quantity,0), 2), '%') AS Return_Rate,
CONCAT(ROUND((Quantity_of_product_cancelled * 100) / IFNULL(Ordered_Quantity,0), 2), '%') AS Cancellationn_Rate,
CONCAT(ROUND((Actual_Quantity_purchased * 100) / IFNULL(Ordered_Quantity,0), 2), '%') AS order_completion_rate,
Net_Sales,
Gross_sales,
Average_Order_Value,
Net_sales / Customer_Lifepan_Month AS Average_monthly_Net_Sales_usd,
Customer_Last_Order_Date,
Customer_First_Order_Date,
Customer_Lifepan_Month,
CASE
    WHEN TIMESTAMPDIFF(DAY, Customer_Last_Order_Date, SYSDATE()) BETWEEN 0 AND 1
    THEN CONCAT(TIMESTAMPDIFF(DAY, Customer_Last_Order_Date, SYSDATE()), ' ', 'Day')
    ELSE CONCAT(TIMESTAMPDIFF(DAY, Customer_Last_Order_Date, SYSDATE()), ' ', 'Days')
    END AS Day_since_last_purchase,
CASE
    WHEN TIMESTAMPDIFF(DAY, Customer_Last_Order_Date, SYSDATE()) > 365
    THEN 'N' ELSE 'Y' END AS Customer_Active_Flag,
CASE 
    WHEN Customer_Lifepan_Month > 24 AND TIMESTAMPDIFF(DAY, Customer_Last_Order_Date, SYSDATE()) > 365 AND Net_sales / Customer_Lifepan_Month > 200
    THEN 'Tier-1 Customer'
    ELSE 'Tier-2 Customer' END AS Customer_category,
    CASE 
    WHEN TIMESTAMPDIFF(DAY, Customer_Last_Order_Date, SYSDATE()) > 365 THEN 'High Churn Risk'
    WHEN TIMESTAMPDIFF(DAY, Customer_Last_Order_Date, SYSDATE()) BETWEEN 180 AND 365 THEN 'Medium Churn Risk'
    ELSE 'Low Churn' 
END AS Churn_Risk_Flag

FROM Aggregated_Table;


/*===================================================================================================================
 Purpose    : Provides monthly and yearly customer revenue trends and quantifies 
              each customer’s contribution to total business revenue.  
 -------------------------------------------------------------------------------------------------------------------
 Description:
 - Aggregates sales orders by customer, month, and year
 - Calculates:
      * Quantity purchased
      * Customer’s revenue in the current month
      * Total business revenue for the month
      * Customer’s percentage contribution to monthly revenue
 - Enables stakeholders to:
      * Identify key revenue-driving customers
      * Track customer revenue trends across months/years
      * Compare contribution patterns between 2024 and 2025
 ===================================================================================================================*/
 
 
 CREATE OR REPLACE VIEW customer_current_revenue_contribution AS
 WITH revenue_agg_table AS (
 SELECT
 so.customer_id,
 YEAR(so.order_creation_date) AS order_creation_year,
 MONTH(so.order_creation_date) AS order_creation_month,
 date_format(so.order_creation_date, '%M') AS order_creation_Month_name,
 SUM(COALESCE(so.ordered_quantity, 0) - (COALESCE(so.cancelled_quantity, 0) + COALESCE(so.returned_quantity, 0))) AS quantity_purchased,
 SUM((COALESCE(so.ordered_quantity, 0) - (COALESCE(so.cancelled_quantity, 0) + COALESCE(so.returned_quantity, 0))) * p.product_price_usd) AS Revenue
 FROM sales_details_silver__layer so
 LEFT JOIN product_silver_layer p ON p.product_id = so.product_id
 GROUP BY order_creation_year, order_creation_month, order_creation_Month_name, customer_id),
 
 Customer_table AS (
 SELECT
 customer_id,
 customer_full_name AS customer_name
 FROM customer_silver_layer
 )
 
 SELECT
 c.customer_id,
 c.customer_name,
 order_creation_year,
 order_creation_month_name,
 quantity_purchased AS current_month_purchase,
 Revenue AS customer_current_month_revenue,
 SUM(revenue) OVER (PARTITION BY order_creation_year, order_creation_month) AS present_month_revenue,
 CONCAT(ROUND((revenue * 100) / SUM(revenue) OVER (PARTITION BY order_creation_year, order_creation_month), 2), '%') AS percentage_current_month_revenue_contribution
 
 FROM customer_table c
 JOIN revenue_agg_table sp ON sp.customer_id = c.customer_id
 WHERE order_creation_year IN ('2025', '2024')
 ORDER BY order_creation_year,order_creation_month ASC;
 
 
/*===================================================================================================================
 Purpose    : Consolidates sales order metrics to monitor revenue performance, fulfillment, and customer trends.
 -------------------------------------------------------------------------------------------------------------------
 Description:
 - Provides a consolidated sales orders dataset with business KPIs.
 - Combines sales fact table with key dimensions (Product, Customer, Store, Sales Person).
 - Includes:
      * Net/Gross order values
      * Quantity purchased, cancellations, returns
      * Average selling price & average order value
      * Fulfillment time (days to ship)
      * On-time delivery flag
      * Customer-request-to-ship aging
 - Enables stakeholders to:
      * Track revenue performance
      * Monitor fulfillment KPIs
      * Identify top-performing products, stores, and sales reps
 ===================================================================================================================*/ 


CREATE OR REPLACE VIEW sales_orders_report AS
WITH Base_Table AS (
SELECT 
SO.order_number,
SO.invoice_number,
SO.payment_method,
SO.order_line_status,
SO.order_creation_date,
p.product_id AS product_number,
P.product_name,
P.product_category,
C.customer_id AS customer_number,
c.customer_full_name AS Customer_Name,
C.customer_country,
C.customer_Address,
ST.store_location_id AS Sold_from,
ST.store_country AS Sold_From_Country,
ST.store_country AS store_country,
COALESCE(so.ordered_quantity, 0) - (COALESCE(SO.cancelled_quantity, 0) + COALESCE(SO.returned_quantity, 0)) AS Actual_Quantity_purchased,
COALESCE(so.ordered_quantity, 0) AS ordered_quantity,
COALESCE(SO.cancelled_quantity, 0) AS cancelled_quantity, 
COALESCE(SO.returned_quantity, 0) AS returned_quantity,
p.product_price_usd,
SO.customer_request_date,
SO.actual_shipment_date AS Order_Ship_date,
SP.Sales_person_full_name AS Sales_Rep
FROM sales_details_silver__layer SO
LEFT JOIN Product_silver_layer P ON P.product_id = SO.product_id
LEFT JOIN customer_silver_layer C ON C.customer_id = SO.customer_id
LEFT JOIN sales_person_silver_layer SP ON Sp.sales_person_id = SO.sales_person_id
LEFT JOIN store_silver_layer ST ON ST.store_location_id = SO.store_location_id
)


/*--------------------------------------------------------------------------------------------------------------------
 2. Sales aggregations with additional business KPIs
 ----------------------------------------------------------------------------------------------------------------------*/
SELECT
order_number,
product_number,
product_name,
product_category,
Sold_From,
Sold_From_Country,
customer_number,
Customer_Name,
Customer_Address,
Customer_Country,
invoice_number,
payment_method,
order_line_status,
SUM(ordered_quantity) AS ordered_quantity,
SUM(cancelled_quantity) AS cancelled_quantity, 
SUM(returned_quantity) AS returned_quantity,
SUM(Actual_Quantity_purchased) AS Quantity_purchased,
SUM(Actual_Quantity_purchased * product_price_usd) AS Net_order_value, ## Order Value
SUM(ordered_quantity * product_price_usd) AS Gross_order_value, ## Before cancellation/return
COUNT(DISTINCT order_number) AS Line_Number,
## Average Selling Price
CASE
    WHEN SUM(Actual_quantity_purchased) > 0
    THEN SUM(Actual_quantity_purchased * Product_price_usd) / SUM(Actual_quantity_purchased)
    END AS Avg_Selling_Price,

CASE
    WHEN COUNT(DISTINCT order_number) > 0
    THEN SUM(Actual_Quantity_purchased * product_price_usd) / COUNT(DISTINCT order_number)
    END AS Average_Order_Value,

order_creation_date,
customer_request_date,
Order_Ship_date,
CASE
    WHEN TIMESTAMPDIFF(DAY, order_creation_date, Order_Ship_date) = 1
    THEN CONCAT(TIMESTAMPDIFF(DAY, order_creation_date, Order_Ship_date), 'Day')
    ELSE CONCAT(TIMESTAMPDIFF(DAY, order_creation_date, Order_Ship_date), 'Days')
    END AS Fulfillment_Days,
CASE 
    WHEN Order_Ship_date <= customer_request_date
    THEN 'Y' ELSE 'N' END AS On_Time_Flag,
CASE 
    WHEN TIMESTAMPDIFF(DAY, customer_request_date, Order_Ship_date) = 1 
    THEN CONCAT(TIMESTAMPDIFF(DAY, customer_request_date, Order_Ship_date), 'Day')
    ELSE CONCAT(TIMESTAMPDIFF(DAY, customer_request_date, Order_Ship_date), 'Days')
    END AS Customer_Request_Aged_To_Ship_Date,
Sales_Rep
FROM Base_Table
GROUP BY 
order_creation_date,
product_number,
product_name,
product_category,
customer_number,
Sold_From,
Sold_From_Country,
product_price_usd,
Order_number,
invoice_number,
payment_method,
Customer_Name,
Customer_Address,
Customer_Country,
order_creation_date,
customer_request_date,
Order_Ship_date,
Sales_Rep,
order_line_status;


/*===================================================================================================================
 Purpose    : Provides consolidated shipment performance metrics by combining sales orders, shipments, customers, 
              stores, and products at the delivery line level.
 -------------------------------------------------------------------------------------------------------------------
 Description:
 - This report enables monitoring of delivery efficiency.  
 - Key Features:
      * Links shipment details with customer, store, product, and order data.
      * Tracks shipped vs. delivered quantities.
      * Captures shipping and delivery dates for lead-time analysis.
      * Provides KPIs including:
          - Delivery lead times (ship-to-delivery days)
          - Delivery accuracy rates
          - On-time vs overdue delivery performance
          - Full vs partial delivery flag
 - Supports supply chain and logistics teams in evaluating carrier reliability, fulfillment accuracy, and 
   overall delivery performance.  
 ===================================================================================================================*/


CREATE OR REPLACE VIEW shipment_report AS 
WITH Shipment_Aggregates AS (
    SELECT
        C.Customer_id AS Customer_Number,
        C.customer_full_name AS Customer_Name,
        C.Customer_Address AS Ship_to_Address,
        C.Customer_State AS Ship_to_State,
        C.Customer_Postcode AS Ship_to_Postcode,
        C.Customer_Country AS Ship_to_Country,
        S.Store_Location_id AS Ship_From,
        S.Store_Address AS Ship_From_Location,
        S.Store_City AS Ship_From_City,
        S.Store_Country AS Ship_From_Country,
        OS.Delivery_Number,
        OS.Delivery_Type,
        OS.Shipping_Method,
        OS.Carrier_Type,
        OS.Delivery_status,
        OS.Tracking_Number,
        SUM(
            CASE 
                WHEN OS.Delivered_Quantity > OS.Shipped_Quantity THEN NULL 
                ELSE OS.Shipped_Quantity 
            END
        ) AS Shipped_Quantity,
        SUM(OS.Delivered_Quantity) AS Delivered_Quantity,
        MIN(OS.Ship_Date) AS Ship_Date,       
        MAX(OS.Delivery_Date) AS Delivery_Date, 
        MIN(SO.Customer_Request_Date) AS Customer_Request_Date
    FROM order_ship_silver_layer OS
    LEFT JOIN customer_silver_layer C ON C.customer_id = OS.customer_id
    LEFT JOIN store_silver_layer S ON S.store_location_id = OS.store_location_id
    LEFT JOIN product_silver_layer P ON P.product_id = OS.product_id
    LEFT JOIN sales_details_silver__layer SO ON SO.order_id = OS.order_id
    GROUP BY
        C.Customer_id, C.customer_full_name, C.Customer_Address, 
        C.Customer_State, C.Customer_Postcode, C.Customer_Country,
        S.Store_Location_id, S.Store_Address, S.Store_City, S.Store_Country,
        OS.Delivery_Number, OS.Delivery_Type, OS.Shipping_Method, 
        OS.Carrier_Type, OS.Delivery_status, OS.Tracking_Number)
 /*--------------------------------------------------------------------------------------------------------------------------------------------
  2. Shipment Kpis: delivery lead times, on-time performance, and delivery accuracy
  --------------------------------------------------------------------------------------------------------------------------------------------*/       
  
 SELECT
    SA.Customer_Number,
    SA.Customer_Name,
    SA.Ship_to_Address,
    SA.Ship_to_State,
    SA.Ship_to_Postcode,
    SA.Ship_to_Country,
    SA.Ship_From,
    SA.Ship_From_Location,
    SA.Ship_From_City,
    SA.Ship_From_Country,
    SA.Delivery_Number,
    SA.Delivery_Type,
    SA.Shipping_Method,
    SA.Carrier_Type,
    SA.Delivery_status,
    SA.Tracking_Number,
    SA.Shipped_Quantity,
    SA.Delivered_Quantity,
    SA.Ship_Date,
    SA.Delivery_Date,
    SA.Customer_Request_Date,
    CASE 
        WHEN TIMESTAMPDIFF(DAY, SA.Ship_Date, SA.Delivery_Date) = 0 
		THEN 'Delivered Same Day'
        WHEN TIMESTAMPDIFF(DAY, SA.Ship_Date, SA.Delivery_Date) = 1
		THEN '1 Day'
        WHEN TIMESTAMPDIFF(DAY, SA.Ship_Date, SA.Delivery_Date) >= 2
		THEN CONCAT(TIMESTAMPDIFF(DAY, SA.Ship_Date, SA.Delivery_Date), ' Days')
        END AS Ship_to_Delivery_Days,
	ROUND(
        CASE 
             WHEN SA.Shipped_Quantity > 0 
             THEN (SA.Delivered_Quantity * 100.0 / SA.Shipped_Quantity) 
             ELSE NULL END, 2
    ) AS Delivery_Accuracy_Rate,
        CASE 
        WHEN SA.Delivered_Quantity < SA.Shipped_Quantity THEN 'Partial' 
        ELSE 'Full' 
    END AS Delivery_Type_Flag,
    CASE 
        WHEN SA.Delivery_Date <= SA.Customer_Request_Date THEN 'On-Time' 
        ELSE 'Overdue' 
    END AS On_Time_Delivery_Flag
FROM Shipment_Aggregates SA;



/*==============================================================================================================
Building Report:
                  product report
==============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------
Purpose:
- this report consolidates key product metrics and behaviour

Highlights: 
1. Gathers essential fields such as product name, product category and product cost
2. segments products by revenue to identify high-performers, mid-range, or low-performers.
3. aggregate product level metrics:
 - total orders
 - total sales
 - total quantity sold
 - total customers (unique),
 - lifespan (in months)
 4. Calculate valuable KPIS
  - recency (months since last sales)
  - average order revenue (AOR)
  - Average Month revenue
-------------------------------------------------------------------------------------------------------------*/
  
  /*-------------------------------------------------------------------------------------------------------------
  1. Base Query: Retrieve core columns from fact table and each of the dimension(product and customer) table
  ----------------------------------------------------------------------------------------------------------------*/
  CREATE OR REPLACE VIEW product_report AS
  WITH Base_Table AS (
  SELECT 
  C.customer_id,
  P.product_name,
  P.product_category,
  so.order_number,
  so.order_creation_date,
  SUM(COALESCE(SO.ordered_quantity, 0) - (COALESCE(so.cancelled_quantity, 0) + COALESCE(so.returned_quantity,0))) AS net_ordered_quantity,
  SUM((COALESCE(SO.ordered_quantity, 0) - (COALESCE(so.cancelled_quantity, 0) + COALESCE(so.returned_quantity,0))) * p.Product_Price_USD) AS product_Net_amount
  FROM sales_details_silver__layer SO
  LEFT JOIN Product_silver_layer P ON P.product_id = SO.product_id
  LEFT JOIN customer_silver_layer C ON C.customer_id = SO.customer_id
  GROUP BY so.order_number, so.order_creation_date, P.product_name, P.product_category, C.customer_id),
 
 /*--------------------------------------------------------------------------------------------------------------------
 2. product aggregations: summarises key metrics at product level
 ----------------------------------------------------------------------------------------------------------------------*/
  Aggregated AS (
  SELECT 
  product_name,
  product_category,
  COUNT(DISTINCT customer_id) AS count_customers_who_purchase_product,
  COUNT(DISTINCT order_number) AS Count_of_orders,
  net_ordered_quantity,
  product_net_amount AS Total_product_sales_contribution,
  CASE
    WHEN net_ordered_quantity > 0
    THEN ROUND(product_Net_amount / net_ordered_quantity, 2)
    END AS Avg_Selling_product_Price,
  MAX(order_creation_date) AS Last_order_date
  FROM BASE_table
  GROUP BY product_name, product_category, net_ordered_quantity, product_net_amount)
  
  /* -------------------------------------------------------------------------------------------------------------
    3. final query: combines all product results into one output
    --------------------------------------------------------------------------------------------------------------*/
  
  SELECT
  product_name,
  product_category,
  count_customers_who_purchase_product,
  Count_of_orders,
  net_ordered_quantity,
  Total_product_sales_contribution,
  Avg_Selling_product_Price,
  Last_order_date,
  TIMESTAMPDIFF(MONTH,Last_order_date, SYSDATE()) AS Month_since_last_order,
  ROUND(AVG(Total_product_sales_contribution / IFNULL(count_of_orders, 0)), 2) AS Average_Order_Sales,
  CASE
      WHEN Total_product_sales_contribution < 100000 THEN 'Tier-4 product'
      WHEN Total_product_sales_contribution BETWEEN 100000 AND 200000 THEN 'Tier-3 product'
      WHEN Total_product_sales_contribution BETWEEN 200000 AND 300000 THEN 'Tier-2 product'
      ELSE 'Tier-1 product' END AS product_category_based_on_total_sales
  FROM Aggregated
  GROUP BY product_name,
  product_category,
  count_customers_who_purchase_product,
  Count_of_orders,
  net_ordered_quantity,
  Total_product_sales_contribution,
  Last_order_date,
  Month_since_last_order
  ORDER BY Total_product_sales_contribution DESC;






 
 
