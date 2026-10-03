USE DWH;
GO

CREATE OR ALTER VIEW gold.vw_entity_sales_line AS
SELECT 
    f.Row_ID,
    f.Order_ID,
    f.Order_Date,
    p.Category,
    p.Sub_Category,
    c.State,
    c.City,
    f.Sales,
    f.Quantity,
    f.Discount,
    f.Profit,

    CASE WHEN f.Profit < 0 THEN 1 ELSE 0 END AS Is_Loss_Making_Line,
    CASE WHEN f.Profit < 0 THEN f.Profit ELSE 0 END AS Loss_Amount,
    CASE WHEN f.Discount >= 0.30 THEN 1 ELSE 0 END AS Is_Discount_30_Or_More,
    CASE WHEN f.Discount >= 0.30 AND f.Profit < 0 THEN f.Profit ELSE 0 END AS Loss_Amount_From_High_Discount
FROM gold.fact_sales f
JOIN gold.dim_products p ON f.Product_ID = p.Product_ID
JOIN gold.dim_customers c ON f.Customer_ID = c.Customer_ID;
GO