USE DWH;
GO

CREATE OR ALTER VIEW gold.vw_entity_product AS
WITH product_metrics AS (
    SELECT 
        Product_ID,
        COUNT(DISTINCT Order_ID) AS Times_Ordered,
        SUM(Quantity) AS Total_Quantity_Sold,
        SUM(Sales) AS Total_Sales,
        SUM(Profit) AS Total_Profit
    FROM gold.fact_sales
    GROUP BY Product_ID
)
SELECT 
    p.Product_ID,
    p.Category,
    p.Sub_Category,
    p.Product_Name,
    pm.Times_Ordered,
    pm.Total_Quantity_Sold,
    pm.Total_Sales,
    pm.Total_Profit,
    -- Pre-calculated Product Financials (CFO Q1, Q2)
    CASE WHEN pm.Total_Sales = 0 THEN 0 ELSE (pm.Total_Profit / pm.Total_Sales) * 100 END AS Profit_Margin_Pct,
    pm.Total_Profit / NULLIF(pm.Total_Quantity_Sold, 0) AS Profit_Per_Unit_Sold,
    -- Pre-calculated Rankings for Top/Bottom 10 (CFO Q3)
    RANK() OVER(ORDER BY pm.Total_Profit DESC) AS Profit_Rank_Highest,
    RANK() OVER(ORDER BY pm.Total_Profit ASC) AS Profit_Rank_Lowest,
    -- Flags
    CASE WHEN pm.Total_Profit < 0 THEN 1 ELSE 0 END AS Is_Loss_Making_Product
FROM gold.dim_products p
LEFT JOIN product_metrics pm ON p.Product_ID = pm.Product_ID;
GO