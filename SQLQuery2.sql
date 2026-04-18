USE Retail_DW;
GO

DELETE FROM Fact_Sales; 
DELETE FROM Dim_Product;

-- Đếm số dòng trong bảng nguồn (online_retail) và bảng đích (Dim_Product)
SELECT 
    (SELECT COUNT(*) FROM online_retail) AS [Source_Rows],
    (SELECT COUNT(*) FROM Dim_Product) AS [DW_Rows],
    (SELECT COUNT(*) FROM online_retail) - (SELECT COUNT(*) FROM Dim_Product) AS [Difference];

-- Xem danh sách cột của bảng Fact
SELECT TOP 0 * FROM Fact_Sales;

SELECT 
    (SELECT COUNT(*) FROM online_retail) AS [Source_Total_Rows],
    (SELECT COUNT(*) FROM Dim_Product) AS [Dim_Product_Rows],
    -- Nếu ông đã nạp bảng Fact rồi thì chạy thêm dòng dưới
    (SELECT COUNT(*) FROM Fact_Sales) AS [Fact_Sales_Rows];


SELECT 
    COUNT(*) AS [Total_Products],
    SUM(CASE WHEN ProductName IS NULL THEN 1 ELSE 0 END) AS [Null_ProductNames],
    AVG(UnitPrice) AS [Average_Price]
FROM Dim_Product;

SELECT 
    COUNT(*) AS [Total_Sales_Records],
    SUM(CASE WHEN Quantity <= 0 THEN 1 ELSE 0 END) AS [Invalid_Quantity],
    SUM(CASE WHEN UnitPrice <= 0 THEN 1 ELSE 0 END) AS [Invalid_UnitPrice],
    SUM(TotalAmount) AS [Total_Revenue]
FROM Fact_Sales;