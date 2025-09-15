/*=====================================================================================
    PROCEDURE: Customer_order_info
    PURPOSE: Given a customer_id, return:
        * Orders
        * Shipments
        * Cancellations
        * Returns
    - Calculate customer-specific return rate
    - Compare against the global average return rate
    - Derive relative return rate (customer vs overall)

INPUT:
    -------------------------------------------------------------------------------
	P_customer_id VARCHAR(30) → Unique store identifier
  
OUTPUT:
    -------------------------------------------------------------------------------
    - Customer details (name, ordered, cancelled, returned, shipped qty)
    - Customer return rate (%)
    - Global return rate across database (%)
    - Relative return rate (Customer vs Global)
=====================================================================================*/

DROP PROCEDURE IF EXISTS Customer_order_info;
  
  DELIMITER $$
  CREATE PROCEDURE Customer_order_info(IN P_customer_id VARCHAR(30))
  BEGIN
    WITH sales_table AS (
  SELECT
  customer_id,
  SUM(COALESCE(ordered_quantity, 0)) AS ordered_quantity,
  SUM(COALESCE(cancelled_quantity, 0)) AS cancelled_quantity,
  SUM(COALESCE(returned_quantity, 0)) AS returned_quantity
  FROM sales_details_silver__layer
  GROUP BY customer_id),
  
  Ship_table AS (
  SELECT
  customer_id,
  SUM(COALESCE(shipped_quantity, 0)) AS shipped_quantity
  FROM order_ship_silver_layer
  GROUP BY customer_id
  ),
  
  Base_table AS (
  SELECT
  c.customer_id,
  c.customer_full_name,
  s.ordered_quantity,
  s.cancelled_quantity,
  s.returned_quantity,
  sh.shipped_quantity
  FROM customer_silver_layer c
  JOIN Sales_table s ON s.customer_id = c.customer_id
  JOIN ship_table sh ON sh.customer_id = c.customer_id
  )
  
  SELECT
  customer_full_name,
  ordered_quantity,
  cancelled_quantity,
  returned_quantity,
  shipped_quantity,
  CASE
      WHEN ordered_quantity > 0 THEN
      CONCAT(ROUND((returned_quantity * 100) / ordered_quantity, 2), '%') 
      END AS customer_return_rate,
  CASE
      WHEN ordered_quantity > 0 THEN
      CONCAT(ROUND(SUM(returned_quantity) OVER() * 100 / SUM(ordered_quantity) OVER(), 2), '%') 
      END AS return_rate_accross_database,
CASE
    WHEN ordered_quantity > 0 
    THEN CONCAT(ROUND((SUM(returned_quantity) OVER() * 100 / SUM(ordered_quantity) OVER()) / ((returned_quantity * 100) / ordered_quantity), 2), '%')
    END AS relative_return_rate
FROM Base_table T
WHERE T.customer_id = P_customer_id;
  
  END $$
  
  DELIMITER ;
  
  
  /*=====================================================================================
    PROCEDURE: Store_revenue_rank
    PURPOSE: Given a store_id, calculate:
        * Ordered, cancelled, returned, and net ordered quantities
        * Net revenue for the store
        * Store’s revenue contribution rate relative to all stores
        * Ranking position among stores by net revenue
    INPUT:
    -------------------------------------------------------------------------------
	P_store_location_id (VARCHAR) → Unique store identifier

    OUTPUT:
    -------------------------------------------------------------------------------
    - Store details (id, quantities, net revenue)
    - Net revenue across all stores
    - Store revenue rate (% share of total)
=====================================================================================*/

DROP PROCEDURE IF EXISTS Store_revenue_rank;

DELIMITER $$
CREATE PROCEDURE Store_revenue_rank(
    IN P_store_location_id VARCHAR(30))
BEGIN
SELECT  
A.store_location_id,
A.ordered_quantity,
A.cancelled_quantity,
A.returned_quantity,
A.Net_ordered_quantity,
A.Net_revenue,
T.total_revenue AS Net_revenue_across_db,
CONCAT(ROUND(A.Net_revenue * 100 / T.total_revenue, 2), '%') AS store_revenue_rate
FROM(
SELECT
s.store_location_id,
SUM(COALESCE(s.ordered_quantity, 0)) AS ordered_quantity,
SUM(COALESCE(s.cancelled_quantity, 0)) AS cancelled_quantity,
SUM(COALESCE(s.returned_quantity, 0)) AS returned_quantity,
SUM(COALESCE(s.ordered_quantity, 0) - (COALESCE(s.cancelled_quantity, 0) + COALESCE(s.returned_quantity, 0))) AS Net_ordered_quantity,
SUM((COALESCE(s.ordered_quantity, 0) - (COALESCE(s.cancelled_quantity, 0) + COALESCE(s.returned_quantity, 0))) * p.product_price_usd) AS Net_revenue
FROM store_silver_layer st
JOIN sales_details_silver__layer s ON s.store_location_id = st.store_location_id
LEFT JOIN product_silver_layer p ON p.product_id = s.product_id
GROUP BY st.store_location_id
) AS A
CROSS JOIN
(
SELECT
SUM((COALESCE(s.ordered_quantity, 0) - (COALESCE(s.cancelled_quantity, 0) + COALESCE(s.returned_quantity, 0))) * p.product_price_usd) AS total_revenue
FROM store_silver_layer st
JOIN sales_details_silver__layer s ON s.store_location_id = st.store_location_id
LEFT JOIN product_silver_layer p ON p.product_id = s.product_id) AS T
WHERE A.store_location_id = p_store_location_id
ORDER BY store_revenue_rate ASC;

END$$
DELIMITER ;
