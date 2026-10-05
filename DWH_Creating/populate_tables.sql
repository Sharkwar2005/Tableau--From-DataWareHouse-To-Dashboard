USE DWH;
GO

EXEC staging.stage_central_superstore @FilePath = N'E:\Projects\_Others\DEPI\Tableau\Mini-Project 3\Tableau--From-DataWareHouse-To-Dashboard\Data\Central_Superstore.csv';
GO

EXEC bronze.load_central_superstore;
GO

EXEC silver.load_central_superstore;
GO

EXEC gold.load_gold_layer;
GO