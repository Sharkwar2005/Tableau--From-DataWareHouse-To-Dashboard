USE master;
GO

IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'DWH')
    CREATE DATABASE DWH;
GO

USE DWH;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'staging')
        EXEC('CREATE SCHEMA staging');
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bronze')
        EXEC('CREATE SCHEMA bronze');
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'silver')
        EXEC('CREATE SCHEMA silver');
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')
        EXEC('CREATE SCHEMA gold');
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'central_superstore' AND schema_id = SCHEMA_ID('staging'))
        CREATE TABLE staging.central_superstore (
                Row_ID          NVARCHAR(255),
                Order_ID        NVARCHAR(255),
                Order_Date      NVARCHAR(255),
                Ship_Date       NVARCHAR(255),
                Ship_Mode       NVARCHAR(255),
                Customer_ID     NVARCHAR(255),
                Customer_Name   NVARCHAR(255),
                Segment	        NVARCHAR(255),
                Country         NVARCHAR(255),
                City	        NVARCHAR(255),
                State	        NVARCHAR(255),
                Postal_Code	NVARCHAR(255),
                Region	        NVARCHAR(255),
                Product_ID	NVARCHAR(255),
                Category	NVARCHAR(255),
                Sub_Category	NVARCHAR(255),
                Product_Name	NVARCHAR(255),
                Sales	        NVARCHAR(255),
                Quantity	NVARCHAR(255),
                Discount	NVARCHAR(255),
                Profit          NVARCHAR(255)
        );


EXEC staging.stage_central_superstore;
GO
       

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'central_superstore' AND schema_id = SCHEMA_ID('bronze'))
        CREATE TABLE bronze.central_superstore (
                bronze_id       INT IDENTITY(1,1) PRIMARY KEY,
                Row_ID          NVARCHAR(255),
                Order_ID        NVARCHAR(255),
                Order_Date      NVARCHAR(255),
                Ship_Date       NVARCHAR(255),
                Ship_Mode       NVARCHAR(255),
                Customer_ID     NVARCHAR(255),
                Customer_Name   NVARCHAR(255),
                Segment	        NVARCHAR(255),
                Country         NVARCHAR(255),
                City	        NVARCHAR(255),
                State	        NVARCHAR(255),
                Postal_Code	NVARCHAR(255),
                Region	        NVARCHAR(255),
                Product_ID	NVARCHAR(255),
                Category	NVARCHAR(255),
                Sub_Category	NVARCHAR(255),
                Product_Name	NVARCHAR(255),
                Sales	        NVARCHAR(255),
                Quantity	NVARCHAR(255),
                Discount	NVARCHAR(255),
                Profit          NVARCHAR(255),
                created_at      DATETIME DEFAULT GETDATE()
        );
GO

EXEC bronze.load_central_superstore;
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'central_superstore' AND schema_id = SCHEMA_ID('silver'))
        CREATE TABLE silver.central_superstore (
                Row_ID                  INT,
                Order_Key               NVARCHAR(15) NOT NULL,
                Order_ID                INT,
                Order_Date              DATE,
                Ship_Date               DATE,
                Ship_Mode               NVARCHAR(25),
                Customer_Key            NVARCHAR(15) NOT NULL,
                Customer_ID             INT,
                Customer_Name           NVARCHAR(25),
                Segment	                NVARCHAR(15),
                Country                 NVARCHAR(25),
                City	                NVARCHAR(20),
                State	                NVARCHAR(20),
                Postal_Code	        NVARCHAR(10),
                Region	                NVARCHAR(15),
                Product_Key	        NVARCHAR(20) NOT NULL,
                Product_ID	        INT,
                Category	        NVARCHAR(25),
                Sub_Category	        NVARCHAR(15),
                Product_Name	        NVARCHAR(100),
                Sales	                DECIMAL(10,2),
                Quantity	        SMALLINT,
                Discount	        DECIMAL(3,2),
                Profit                  DECIMAL(10,2),
                has_missing_values      BIT DEFAULT 0,
                has_invalid_value       BIT DEFAULT 0,
                has_outlier_Sales       BIT DEFAULT 0,
                has_outlier_Profit      BIT DEFAULT 0,
                has_outlier_Discount    BIT DEFAULT 0,
                created_at              DATETIME 
        );
GO

EXEC silver.load_central_superstore;
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'dim_customers' AND schema_id = SCHEMA_ID('gold'))
        CREATE TABLE gold.dim_customers (
                Customer_ID             INT PRIMARY KEY,
                Customer_Key            NVARCHAR(25),
                Customer_Name           NVARCHAR(25),
                Segment	                NVARCHAR(15),
                Country                 NVARCHAR(25),
                City	                NVARCHAR(20),
                State	                NVARCHAR(20),
                Postal_Code	        NVARCHAR(10),
                Region	                NVARCHAR(15)
                )

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'dim_products' AND schema_id = SCHEMA_ID('gold'))
        CREATE TABLE gold.dim_products (
                Product_ID	        INT PRIMARY KEY,
                Product_Key	        NVARCHAR(20) NOT NULL,
                Category	        NVARCHAR(25),
                Sub_Category	        NVARCHAR(15),
                Product_Name	        NVARCHAR(100)
        )

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'dim_orders' AND schema_id = SCHEMA_ID('gold'))
        CREATE TABLE gold.dim_orders (
                Order_ID                INT PRIMARY KEY,
                Order_Key               NVARCHAR(15) NOT NULL,
                Order_Date              DATE,
                Ship_Date               DATE,
                Ship_Mode               NVARCHAR(25)
        )

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'fact_sales' AND schema_id = SCHEMA_ID('gold'))
        CREATE TABLE gold.fact_sales (
                Row_ID                  INT PRIMARY KEY,
                Order_ID                INT FOREIGN KEY REFERENCES gold.dim_orders(Order_ID),
                Customer_ID             INT FOREIGN KEY REFERENCES gold.dim_customers(Customer_ID),
                Product_ID              INT FOREIGN KEY REFERENCES gold.dim_products(Product_ID),
                Order_Date              DATE,
                Ship_Date               DATE,
                Sales	                DECIMAL(10,2),
                Quantity	        SMALLINT,
                Discount	        DECIMAL(3,2),
                Profit                  DECIMAL(10,2)
                )


EXEC gold.load_gold_layer;
GO



EXEC gold.sp_get_executive_kpis ;
GO



SELECT * FROM gold.vw_sales_trends ORDER BY Order_Year, Order_Month;
GO



SELECT TOP 10 * FROM gold.vw_customer_behavior ORDER BY Total_Spent DESC;
GO



SELECT * FROM gold.vw_profitability_analysis ORDER BY Total_Profit DESC;
