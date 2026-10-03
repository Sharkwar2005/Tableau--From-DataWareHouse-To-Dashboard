USE DWH;
GO

CREATE OR ALTER VIEW gold.vw_entity_order AS
WITH order_metrics AS (
    SELECT 
        Order_ID,
        Customer_ID,
        SUM(Quantity) AS Total_Items_In_Order,
        SUM(Sales) AS Order_Sales,
        SUM(Profit) AS Order_Profit
    FROM gold.fact_sales
    GROUP BY Order_ID, Customer_ID
)
SELECT 
    o.Order_ID,
    om.Customer_ID,
    o.Ship_Mode,
    
    o.Order_Date,
    YEAR(o.Order_Date) AS Order_Year,
    DATENAME(MONTH, o.Order_Date) AS Order_Month_Name,
    DATEPART(MONTH, o.Order_Date) AS Order_Month_Num,
    DATENAME(WEEKDAY, o.Order_Date) AS Order_Day_Of_Week,
    
    o.Ship_Date,
    DATEDIFF(DAY, o.Order_Date, o.Ship_Date) AS Shipping_Days,
    
    om.Total_Items_In_Order,
    om.Order_Sales,
    om.Order_Profit,
    CASE WHEN om.Order_Sales = 0 THEN 0 ELSE (om.Order_Profit / om.Order_Sales) * 100 END AS Order_Profit_Margin_Pct,
    
    COUNT(o.Order_ID) OVER (PARTITION BY om.Customer_ID, YEAR(o.Order_Date)) AS Customer_Orders_This_Year,
    CASE WHEN COUNT(o.Order_ID) OVER (PARTITION BY om.Customer_ID, YEAR(o.Order_Date)) > 1 THEN 1 ELSE 0 END AS Is_Repeat_Order_In_Year
FROM gold.dim_orders o
LEFT JOIN order_metrics om ON o.Order_ID = om.Order_ID;
GO