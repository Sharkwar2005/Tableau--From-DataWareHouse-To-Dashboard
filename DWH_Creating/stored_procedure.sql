USE DWH;
GO

CREATE OR ALTER PROCEDURE staging.stage_central_superstore 
    @FilePath NVARCHAR(MAX)
AS 
BEGIN
    SET NOCOUNT ON;

    DECLARE @START_TIME DATETIME, @END_TIME DATETIME;
    DECLARE @SQL NVARCHAR(MAX);

    PRINT ''
    PRINT '================================================================';
    PRINT ' LOADING DATA INTO STAGING LAYER';
    PRINT '================================================================';
    
    SET @START_TIME = GETDATE();
    
    TRUNCATE TABLE staging.central_superstore;

    SET @SQL = N'
    BULK INSERT staging.central_superstore
    FROM ''' + REPLACE(@FilePath, '''', '''''') + '''
    WITH (
        FIRSTROW = 2,
        FORMAT = ''CSV'',
        FIELDQUOTE = ''"'',  
        CODEPAGE = ''65001'', 
        FIELDTERMINATOR = '','',
        ROWTERMINATOR = ''\n'',
        TABLOCK);';

    EXEC sp_executesql @SQL;

    SET @END_TIME = GETDATE();
    PRINT ' > LOADED FILE INTO STAGING LAYER IN : ' + CAST(DATEDIFF(MILLISECOND, @START_TIME, @END_TIME) AS NVARCHAR(20)) + ' ms';
END;
GO




CREATE OR ALTER PROCEDURE bronze.load_central_superstore AS
BEGIN
        DECLARE @START_TIME DATETIME, @END_TIME DATETIME;
        SET @START_TIME = GETDATE();
        PRINT ''
        PRINT '================================================================';
        PRINT ' LOADING DATA INTO BRONZE LAYER';
        PRINT '================================================================';
        INSERT INTO bronze.central_superstore(
               [Row_ID],[Order_ID],[Order_Date],[Ship_Date],[Ship_Mode],[Customer_ID],[Customer_Name],[Segment],[Country],[City]
              ,[State],[Postal_Code],[Region],[Product_ID],[Category],[Sub_Category],[Product_Name],[Sales],[Quantity],[Discount],[Profit]
        )
        SELECT 
               [Row_ID],[Order_ID],[Order_Date],[Ship_Date],[Ship_Mode],[Customer_ID],[Customer_Name],[Segment],[Country],[City]
              ,[State],[Postal_Code],[Region],[Product_ID],[Category],[Sub_Category],[Product_Name],[Sales],[Quantity],[Discount],[Profit]
              FROM staging.central_superstore
        EXCEPT
        SELECT 
              [Row_ID],[Order_ID],[Order_Date],[Ship_Date],[Ship_Mode],[Customer_ID],[Customer_Name],[Segment],[Country],[City]
              ,[State],[Postal_Code],[Region],[Product_ID],[Category],[Sub_Category],[Product_Name],[Sales],[Quantity],[Discount],[Profit]
        FROM bronze.central_superstore;
        SET @END_TIME = GETDATE();
        PRINT ' > POPULATED BRONZE LAYER IN : ' + CAST(DATEDIFF(MILLISECOND, @START_TIME, @END_TIME) AS NVARCHAR(20)) + ' ms';
END;
GO

CREATE OR ALTER PROCEDURE silver.load_central_superstore AS
BEGIN
        DECLARE @START_TIME DATETIME, @END_TIME DATETIME;
        PRINT ''
        PRINT '================================================================';
        PRINT ' LOADING DATA INTO SILVER LAYER';
        PRINT '================================================================';

        
        SET @START_TIME = GETDATE();

        
        SELECT 
                *,
                ROW_NUMBER() OVER (
                    PARTITION BY Row_ID, Order_Date, Customer_Name, Product_ID
                    ORDER BY bronze_id DESC
                ) AS row_num
        INTO #latest_bronze        
        FROM bronze.central_superstore 
        
        
        SELECT          
                TRY_CAST(NULLIF(TRIM(Row_ID), '') AS INT) AS Row_ID,
                NULLIF(TRIM(Row_ID), '') AS raw_Row_ID,

                TRY_CAST(NULLIF(TRIM(Order_ID), '') AS NVARCHAR(15)) AS Order_ID,
                TRY_CAST(NULLIF(TRIM(Order_Date), '') AS DATE) AS Order_Date,
                TRY_CAST(NULLIF(TRIM(Ship_Date), '') AS DATE) AS Ship_Date,
                TRY_CAST(NULLIF(TRIM(Ship_Mode), '') AS NVARCHAR(25)) AS Ship_Mode,

                TRY_CAST(NULLIF(TRIM(Customer_ID), '') AS NVARCHAR(15)) AS Customer_ID,
                 
                TRY_CAST(NULLIF(TRIM(Customer_Name), '') AS NVARCHAR(25)) AS Customer_Name,
                TRY_CAST(NULLIF(TRIM(Segment), '') AS NVARCHAR(15)) AS Segment,
                TRY_CAST(NULLIF(TRIM(Country), '') AS NVARCHAR(25)) AS Country,
                TRY_CAST(NULLIF(TRIM(City), '') AS NVARCHAR(20)) AS City,
                TRY_CAST(NULLIF(TRIM(State), '') AS NVARCHAR(20)) AS State,
                TRY_CAST(NULLIF(TRIM(Postal_Code), '') AS NVARCHAR(10)) AS Postal_Code,
                TRY_CAST(NULLIF(TRIM(Region), '') AS NVARCHAR(15)) AS Region,

                TRY_CAST(NULLIF(TRIM(Product_ID), '') AS NVARCHAR(20)) AS Product_ID,
                 
                TRY_CAST(NULLIF(TRIM(Product_Name), '') AS NVARCHAR(100)) AS Product_Name,
                TRY_CAST(NULLIF(TRIM(Category), '') AS NVARCHAR(25)) AS Category,
                TRY_CAST(NULLIF(TRIM(Sub_Category), '') AS NVARCHAR(15)) AS Sub_Category,

                TRY_CAST(NULLIF(TRIM(Sales), '') AS DECIMAL(10,2)) AS Sales,
                NULLIF(TRIM(Sales), '') AS raw_Sales,

                TRY_CAST(NULLIF(TRIM(Quantity), '') AS SMALLINT) AS Quantity,
                NULLIF(TRIM(Quantity), '') AS raw_Quantity,

                TRY_CAST(NULLIF(TRIM(Discount), '') AS DECIMAL(3,2)) AS Discount,
                NULLIF(TRIM(Discount), '') AS raw_Discount,

                TRY_CAST(NULLIF(TRIM(Profit), '') AS DECIMAL(10,2)) AS Profit,
                NULLIF(TRIM(Profit), '') AS raw_Profit,
                created_at
        INTO #clean
        FROM #latest_bronze
        WHERE row_num = 1

        CREATE CLUSTERED INDEX IX_clean_OrderID ON #clean(Order_ID);
        
        WITH iqr_bounders AS (
                SELECT DISTINCT
                        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY Sales) OVER () AS q1_Sales,
                        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY Sales) OVER () AS q3_Sales,
        
                        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY Profit) OVER () AS q1_Profit,
                        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY Profit) OVER () AS q3_Profit,
        
                        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY Discount) OVER () AS q1_Discount,
                        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY Discount) OVER () AS q3_Discount
                FROM #clean
        ),
        Flagged as (
                SELECT
                        c.Row_ID,
                        c.raw_Row_ID,

                        c.Order_ID,
                        c.Order_Date,
                        c.Ship_Date,
                        c.Ship_Mode,
                        
                        c.Customer_ID,
                        c.Customer_Name,
                        c.Segment,
                        c.Country,
                        c.City,
                        c.State,
                        c.Postal_Code,
                        c.Region,
                        
                        c.Product_ID,
                        c.Category,
                        c.Sub_Category,
                        c.Product_Name,
                        c.Sales,
                        c.raw_Sales,         
                        c.Quantity,
                        c.raw_Quantity,      
                        c.Discount,
                        c.raw_Discount,      
                        c.Profit,
                        c.raw_Profit,        
                        c.created_at,
                        CASE 
                                WHEN 
                                        c.raw_Row_ID IS NULL
                                        OR c.Order_ID IS NULL
                                        OR c.Order_Date IS NULL
                                        OR c.Ship_Date IS NULL
                                        OR c.Ship_Mode IS NULL
                                        OR c.Customer_ID IS NULL
                                        OR c.Customer_Name IS NULL
                                        OR c.Segment IS NULL
                                        OR c.Country IS NULL
                                        OR c.City IS NULL
                                        OR c.State IS NULL
                                        OR c.Postal_Code IS NULL
                                        OR c.Region IS NULL
                                        OR c.Product_ID IS NULL
                                        OR c.Category IS NULL
                                        OR c.Sub_Category IS NULL
                                        OR c.Product_Name IS NULL
                                        OR c.raw_Sales IS NULL
                                        OR c.raw_Quantity IS NULL
                                        OR c.raw_Discount IS NULL
                                        OR c.raw_Profit IS NULL
                                        OR c.created_at IS NULL
                                THEN 1 ELSE 0
                                END AS has_missing_values,
                        CASE 
                                WHEN 
                                        (c.Row_ID IS NOT NULL AND c.raw_Row_ID IS NULL) OR
                                        (c.Sales IS NOT NULL AND c.raw_Sales IS NULL) OR
                                        (c.Profit IS NOT NULL AND c.raw_Profit IS NULL) OR
                                        (c.Quantity IS NOT NULL AND c.raw_Quantity IS NULL) OR
                                        (c.Discount IS NOT NULL AND c.raw_Discount IS NULL) OR
                                        (c.Sales IS NOT NULL AND (c.Sales < 0)) OR
                                        (c.Quantity IS NOT NULL AND (c.Quantity < 0)) OR 
                                        (c.Discount IS NOT NULL AND (c.Discount < 0 OR c.Discount > 1)) 
                                THEN 1 ELSE 0 
                        END AS has_invalid_value,
                        CASE 
                        WHEN (c.Sales IS NOT NULL AND (
                                c.Sales < b.q1_Sales - 1.5 * (b.q3_Sales - b.q1_Sales)
                                OR c.Sales > b.q3_Sales + 1.5 * (b.q3_Sales - b.q1_Sales)
                        )) THEN 1 ELSE 0 
                        END AS has_outlier_Sales,

                        CASE 
                            WHEN (c.Profit IS NOT NULL AND (
                                c.Profit < b.q1_Profit - 1.5 * (b.q3_Profit - b.q1_Profit)
                                OR c.Profit > b.q3_Profit + 1.5 * (b.q3_Profit - b.q1_Profit)
                        )) THEN 1 ELSE 0 
                        END AS has_outlier_Profit,

                        CASE 
                            WHEN (c.Discount IS NOT NULL AND (
                                c.Discount < b.q1_Discount - 1.5 * (b.q3_Discount - b.q1_Discount)
                                OR c.Discount > b.q3_Discount + 1.5 * (b.q3_Discount - b.q1_Discount)
                        )) THEN 1 ELSE 0 
                        END AS has_outlier_Discount
                FROM #clean as c
                CROSS JOIN iqr_bounders as b 
        )
        MERGE silver.central_superstore AS tgt
        USING Flagged AS src
        ON tgt.Order_ID = src.Order_ID
        AND tgt.Row_ID = src.Row_ID
        AND tgt.Order_Date = src.Order_Date
        AND tgt.Customer_Name = src.Customer_Name
        AND tgt.Product_ID = src.Product_ID
        WHEN MATCHED THEN
                UPDATE SET
                        tgt.Row_ID = src.Row_ID,
                        tgt.Order_ID = src.Order_ID,
                        tgt.Order_Date = src.Order_Date,
                        tgt.Ship_Date = src.Ship_Date,
                        tgt.Ship_Mode = src.Ship_Mode,
                        tgt.Customer_ID = src.Customer_ID,
                        tgt.Customer_Name = src.Customer_Name,
                        tgt.Segment = src.Segment,
                        tgt.Country = src.Country,
                        tgt.City = src.City,
                        tgt.State = src.State,
                        tgt.Postal_Code = src.Postal_Code,
                        tgt.Region = src.Region,
                        tgt.Product_ID = src.Product_ID,
                        tgt.Category = src.Category,
                        tgt.Sub_Category = src.Sub_Category,
                        tgt.Product_Name = src.Product_Name,
                        tgt.Sales = src.Sales,
                        tgt.Quantity = src.Quantity,
                        tgt.Discount = src.Discount,
                        tgt.Profit = src.Profit,
                        tgt.has_missing_values = src.has_missing_values,
                        tgt.has_invalid_value = src.has_invalid_value,
                        tgt.has_outlier_Sales = src.has_outlier_Sales,
                        tgt.has_outlier_Profit = src.has_outlier_Profit,
                        tgt.has_outlier_Discount = src.has_outlier_Discount
                WHEN NOT MATCHED THEN
                        INSERT (Row_ID,Order_ID, Order_Date, Ship_Date, Ship_Mode, Customer_ID, Customer_Name, Segment,Country, City, State, Postal_Code, Region,Product_ID, Category, Sub_Category, Product_Name,Sales,Quantity, Discount, Profit, created_at,has_missing_values,has_invalid_value,has_outlier_Sales,has_outlier_Profit,has_outlier_Discount)
                        VALUES (src.Row_ID,src.Order_ID, src.Order_Date, src.Ship_Date, src.Ship_Mode, src.Customer_ID, src.Customer_Name, src.Segment,src.Country, src.City, src.State, src.Postal_Code, src.Region,src.Product_ID, src.Category, src.Sub_Category, src.Product_Name,src.Sales, src.Quantity, src.Discount, src.Profit, src.created_at,src.has_missing_values,src.has_invalid_value,src.has_outlier_Sales,src.has_outlier_Profit,src.has_outlier_Discount);
        ;
        SET @END_TIME = GETDATE();
        PRINT ' > POPULATED SILVER LAYER IN : ' + CAST(DATEDIFF(MILLISECOND, @START_TIME, @END_TIME) AS NVARCHAR(20)) + ' ms';

END;
GO 


CREATE OR ALTER PROCEDURE gold.load_gold_layer AS
BEGIN
    SET NOCOUNT ON;
    PRINT ''
    PRINT '================================================================';
    PRINT ' LOADING DATA INTO GOLD LAYER ';
    PRINT '================================================================';

    DECLARE @START_TIME DATETIME = GETDATE();

    WITH UniqueCustomers AS (
        SELECT 
            Customer_ID, Customer_Name, Segment, 
            Country, City, State, Postal_Code, Region,
            ROW_NUMBER() OVER (PARTITION BY Customer_ID ORDER BY Order_Date DESC) AS rn
        FROM silver.central_superstore
        WHERE has_missing_values = 0 
          AND has_invalid_value = 0 
          AND Customer_ID IS NOT NULL
    )
    INSERT INTO gold.dim_customers (
        Customer_ID, Customer_Name, Segment, 
        Country, City, State, Postal_Code, Region
    )
    SELECT 
        Customer_ID, Customer_Name, Segment, 
        Country, City, State, Postal_Code, Region
    FROM UniqueCustomers
    WHERE rn = 1
      AND Customer_ID NOT IN (SELECT Customer_ID FROM gold.dim_customers);



    WITH UniqueProducts AS (
        SELECT 
            Product_ID, Category, Sub_Category, Product_Name,
            ROW_NUMBER() OVER (PARTITION BY Product_ID ORDER BY Order_Date DESC) AS rn
        FROM silver.central_superstore
        WHERE has_missing_values = 0 
          AND has_invalid_value = 0 
          AND Product_ID IS NOT NULL
    )
    INSERT INTO gold.dim_products (
        Product_ID, Category, Sub_Category, Product_Name
    )
    SELECT 
        Product_ID, Category, Sub_Category, Product_Name
    FROM UniqueProducts
    WHERE rn = 1
      AND Product_ID NOT IN (SELECT Product_ID FROM gold.dim_products);




    WITH UniqueOrders AS (
        SELECT 
            Order_ID, Order_Date, Ship_Date, Ship_Mode,
            ROW_NUMBER() OVER (PARTITION BY Order_ID ORDER BY Order_Date DESC) AS rn
        FROM silver.central_superstore
        WHERE has_missing_values = 0 
          AND has_invalid_value = 0 
          AND Order_ID IS NOT NULL
    )
    INSERT INTO gold.dim_orders (
        Order_ID, Order_Date, Ship_Date, Ship_Mode
    )
    SELECT 
        Order_ID, Order_Date, Ship_Date, Ship_Mode
    FROM UniqueOrders
    WHERE rn = 1
      AND Order_ID NOT IN (SELECT Order_ID FROM gold.dim_orders);



    INSERT INTO gold.fact_sales (
        Row_ID, Order_ID, Customer_ID, Product_ID, 
        Order_Date, Ship_Date, Sales, Quantity, Discount, Profit
    )
    SELECT 
        Row_ID, Order_ID, Customer_ID, Product_ID, 
        Order_Date, Ship_Date, Sales, Quantity, Discount, Profit
    FROM silver.central_superstore
    WHERE has_missing_values = 0 
      AND has_invalid_value = 0
      AND Row_ID IS NOT NULL
      AND Order_ID IS NOT NULL
      AND Customer_ID IS NOT NULL 
      AND Product_ID IS NOT NULL
      AND Row_ID NOT IN (SELECT Row_ID FROM gold.fact_sales)


    DECLARE @END_TIME DATETIME = GETDATE();
    PRINT ' > POPULATED GOLD LAYER IN : ' + CAST(DATEDIFF(MILLISECOND, @START_TIME, @END_TIME) AS NVARCHAR(20)) + ' ms';
END;
GO


CREATE OR ALTER PROCEDURE gold.sp_get_executive_kpis
AS
BEGIN
    SET NOCOUNT ON;
    PRINT ''
    PRINT '================================================================';
    PRINT ' CALCULATING EXECUTIVE KPIS';
    PRINT '================================================================';

    SELECT 
        COUNT(DISTINCT f.Order_ID) AS Total_Orders,
        SUM(f.Sales) AS Total_Revenue,
        SUM(f.Profit) AS Total_Profit,
        SUM(f.Quantity) AS Total_Items_Sold,
        CASE 
            WHEN SUM(f.Sales) = 0 THEN 0 
            ELSE CAST((SUM(f.Profit) / SUM(f.Sales)) * 100 AS DECIMAL(5,2)) 
        END AS Overall_Profit_Margin_Pct,
        CASE 
            WHEN COUNT(DISTINCT f.Order_ID) = 0 THEN 0 
            ELSE CAST(SUM(f.Sales) / COUNT(DISTINCT f.Order_ID) AS DECIMAL(10,2)) 
        END AS Average_Order_Value
    FROM gold.fact_sales f
    JOIN gold.dim_orders o ON f.Order_ID = o.Order_ID
    
END;