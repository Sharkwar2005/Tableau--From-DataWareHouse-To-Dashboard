USE DWH;
GO

CREATE OR ALTER VIEW gold.vw_entity_customer AS
WITH customer_metrics AS (
    SELECT 
        f.Customer_ID,
        COUNT(DISTINCT f.Order_ID) AS Total_Orders,
        SUM(f.Sales) AS Total_Sales,
        SUM(f.Profit) AS Total_Profit,
        SUM(f.Quantity) AS Total_Items_Bought,
        AVG(f.Discount) AS Avg_Discount_Rate,
        MIN(f.Order_Date) AS First_Order_Date,
        MAX(f.Order_Date) AS Last_Order_Date,
        AVG(CAST(DATEDIFF(DAY, o.Order_Date, o.Ship_Date) AS DECIMAL(10,2))) AS Avg_Shipping_Days
    FROM gold.fact_sales f
    JOIN gold.dim_orders o ON f.Order_ID = o.Order_ID
    GROUP BY f.Customer_ID
)
SELECT 
    c.Customer_ID,
    c.Customer_Name,
    c.Segment,
    c.Country,
    c.Region,
    c.State,
    c.City,
    cm.Total_Orders,
    cm.Total_Sales,
    cm.Total_Profit,
    cm.Total_Items_Bought,
    cm.Avg_Discount_Rate,
    cm.Avg_Shipping_Days,
    CASE WHEN cm.Total_Sales = 0 THEN 0 ELSE (cm.Total_Profit / cm.Total_Sales) * 100 END AS Profit_Margin_Pct,
    cm.Total_Sales / NULLIF(cm.Total_Orders, 0) AS Customer_Avg_Order_Value,
    RANK() OVER(ORDER BY cm.Total_Profit DESC) AS Lifetime_Profit_Rank,
    -- Flags
    CASE WHEN cm.Total_Profit < 0 THEN 1 ELSE 0 END AS Is_Unprofitable_Customer
FROM gold.dim_customers c
LEFT JOIN customer_metrics cm ON c.Customer_ID = cm.Customer_ID;
GO