USE DWH;
GO

CREATE OR ALTER VIEW gold.vw_dashboard_yearly_performance AS
WITH YearlyStats AS (
    SELECT
        YEAR(Order_Date) AS Order_Year,
        SUM(Sales) AS Total_Sales,
        SUM(Profit) AS Total_Profit
    FROM gold.fact_sales
    GROUP BY YEAR(Order_Date)
)
SELECT
    Order_Year,
    Total_Sales,
    Total_Profit,
    CASE 
        WHEN Total_Sales = 0 THEN 0 
        ELSE (Total_Profit / Total_Sales) * 100 
    END AS Profit_Margin_Pct,
    LAG(Total_Sales) OVER(ORDER BY Order_Year) AS Prev_Year_Sales,
    CASE 
        WHEN LAG(Total_Sales) OVER(ORDER BY Order_Year) IS NULL THEN NULL 
        ELSE ((Total_Sales - LAG(Total_Sales) OVER(ORDER BY Order_Year)) / LAG(Total_Sales) OVER(ORDER BY Order_Year)) * 100 
    END AS YoY_Sales_Growth_Pct
FROM YearlyStats;
GO

CREATE OR ALTER VIEW gold.vw_dashboard_yearly_order_metrics AS
WITH OrderAgg AS (
    SELECT 
        YEAR(Order_Date) AS Order_Year,
        Order_ID,
        Customer_ID,
        SUM(Sales) AS Order_Sales,
        SUM(Quantity) AS Order_Items
    FROM gold.fact_sales
    GROUP BY YEAR(Order_Date), Order_ID, Customer_ID
)
SELECT 
    Order_Year,
    COUNT(DISTINCT Order_ID) AS Total_Orders,
    COUNT(DISTINCT Customer_ID) AS Unique_Customers,
    AVG(Order_Sales) AS Average_Order_Value,
    AVG(CAST(Order_Items AS DECIMAL(10,2))) AS Average_Items_Per_Order
FROM OrderAgg
GROUP BY Order_Year;
GO


CREATE OR ALTER VIEW gold.vw_dashboard_state_city_profitability AS
SELECT 
    c.State,
    c.City,
    SUM(f.Sales) AS Total_Sales,
    SUM(f.Profit) AS Total_Profit
FROM gold.fact_sales f
JOIN gold.dim_customers c ON f.Customer_ID = c.Customer_ID
GROUP BY c.State, c.City;
GO


CREATE OR ALTER VIEW gold.vw_dashboard_category_share AS
WITH CategoryTotals AS (
    SELECT 
        p.Category,
        SUM(f.Sales) AS Category_Sales,
        SUM(f.Profit) AS Category_Profit
    FROM gold.fact_sales f
    JOIN gold.dim_products p ON f.Product_ID = p.Product_ID
    GROUP BY p.Category
),
GrandTotals AS (
    SELECT 
        SUM(Sales) AS Grand_Total_Sales,
        SUM(Profit) AS Grand_Total_Profit
    FROM gold.fact_sales
)
SELECT 
    ct.Category,
    ct.Category_Sales,
    (ct.Category_Sales / gt.Grand_Total_Sales) * 100 AS Sales_Share_Pct,
    ct.Category_Profit,
    (ct.Category_Profit / gt.Grand_Total_Profit) * 100 AS Profit_Share_Pct
FROM CategoryTotals ct
CROSS JOIN GrandTotals gt;
GO

CREATE OR ALTER VIEW gold.vw_dashboard_segment_performance AS
WITH SegmentOrders AS (
    SELECT 
        c.Segment,
        f.Order_ID,
        c.Customer_ID,
        SUM(f.Sales) AS Order_Sales,
        SUM(f.Profit) AS Order_Profit
    FROM gold.fact_sales f
    JOIN gold.dim_customers c ON f.Customer_ID = c.Customer_ID
    GROUP BY c.Segment, f.Order_ID, c.Customer_ID
)
SELECT 
    Segment,
    SUM(Order_Sales) AS Total_Sales,
    SUM(Order_Profit) AS Total_Profit,
    COUNT(DISTINCT Customer_ID) AS Customer_Count,
    AVG(Order_Sales) AS Average_Order_Value
FROM SegmentOrders
GROUP BY Segment;
GO


CREATE OR ALTER VIEW gold.vw_dashboard_top_10_customers AS
WITH CustomerProfit AS (
    SELECT 
        c.Customer_ID,
        c.Customer_Name,
        SUM(f.Profit) AS Customer_Total_Profit
    FROM gold.fact_sales f
    JOIN gold.dim_customers c ON f.Customer_ID = c.Customer_ID
    GROUP BY c.Customer_ID, c.Customer_Name
),
TotalProfit AS (
    SELECT SUM(Profit) AS Grand_Total_Profit 
    FROM gold.fact_sales
),
RankedCustomers AS (
    SELECT 
        Customer_Name,
        Customer_Total_Profit,
        -- Assign a rank based on highest profit
        RANK() OVER (ORDER BY Customer_Total_Profit DESC) AS Profit_Rank
    FROM CustomerProfit
)
SELECT 
    rc.Profit_Rank,
    rc.Customer_Name,
    rc.Customer_Total_Profit,
    (rc.Customer_Total_Profit / tp.Grand_Total_Profit) * 100 AS Profit_Share_Pct
FROM RankedCustomers rc
CROSS JOIN TotalProfit tp
WHERE rc.Profit_Rank <= 10;
GO



CREATE OR ALTER VIEW gold.vw_dashboard_yearly_repeat_rate AS
WITH CustomerOrdersPerYear AS (
    SELECT 
        YEAR(Order_Date) AS Order_Year,
        Customer_ID,
        COUNT(DISTINCT Order_ID) AS Order_Count
    FROM gold.fact_sales
    GROUP BY YEAR(Order_Date), Customer_ID
),
YearlyCounts AS (
    SELECT 
        Order_Year,
        COUNT(Customer_ID) AS Total_Customers,
        SUM(CASE WHEN Order_Count > 1 THEN 1 ELSE 0 END) AS Repeat_Customers
    FROM CustomerOrdersPerYear
    GROUP BY Order_Year
)
SELECT 
    Order_Year,
    Total_Customers,
    Repeat_Customers,
    (CAST(Repeat_Customers AS DECIMAL(10,2)) / Total_Customers) * 100 AS Repeat_Rate_Pct
FROM YearlyCounts;
GO