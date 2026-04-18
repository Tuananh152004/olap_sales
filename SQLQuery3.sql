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

USE Retail_DW;
GO
--1.Top sản phẩm: Doanh thu cao nhất theo từng tháng
WITH MonthlyProductRevenue AS (
    SELECT 
        d.Year, 
        d.Month, 
        p.ProductName, 
        SUM(f.TotalAmount) AS Revenue,
        RANK() OVER (PARTITION BY d.Year, d.Month ORDER BY SUM(f.TotalAmount) DESC) AS Rank
    FROM Fact_Sales f
    JOIN Dim_Product p ON f.ProductKey = p.ProductKey
    JOIN Dim_Date d ON f.DateKey = d.DateKey
    GROUP BY d.Year, d.Month, p.ProductName
)
SELECT * FROM MonthlyProductRevenue WHERE Rank = 1;

--2. Thị trường tiềm năng: Quốc gia đóng góp doanh thu lớn nhất
SELECT 
    l.Country, 
    SUM(f.TotalAmount) AS Total_Revenue,
    COUNT(DISTINCT f.InvoiceKey) AS Total_Orders
FROM Fact_Sales f
JOIN Dim_Location l ON f.LocationKey = l.LocationKey
GROUP BY l.Country
ORDER BY Total_Revenue DESC;

--3. Xu hướng thời gian: Doanh thu theo quý
SELECT 
    d.Year, 
    d.Quarter, 
    SUM(f.TotalAmount) AS Quarterly_Revenue
FROM Fact_Sales f
JOIN Dim_Date d ON f.DateKey = d.DateKey
GROUP BY d.Year, d.Quarter
ORDER BY d.Year, d.Quarter;

--4. Phân khúc khách hàng: Giá trị đơn hàng trung bình (AOV)
SELECT 
    c.CustomerID, 
    SUM(f.TotalAmount) AS Total_Spent,
    COUNT(DISTINCT f.InvoiceKey) AS Total_Invoices,
    SUM(f.TotalAmount) / COUNT(DISTINCT f.InvoiceKey) AS AOV
FROM Fact_Sales f
JOIN Dim_Customer c ON f.CustomerKey = c.CustomerKey
GROUP BY c.CustomerID
ORDER BY AOV DESC;

--5. Tỷ lệ hoàn hàng: Sản phẩm thường xuyên bị hủy
SELECT 
    p.ProductName, 
    COUNT(f.SalesKey) AS Cancellation_Count
FROM Fact_Sales f
JOIN Dim_Product p ON f.ProductKey = p.ProductKey
JOIN Dim_Invoice i ON f.InvoiceKey = i.InvoiceKey
WHERE i.Status = 'Cancelled'
GROUP BY p.ProductName
ORDER BY Cancellation_Count DESC;

--6. Hiệu suất bán hàng: Khung giờ phát sinh nhiều đơn nhất
SELECT 
    DATEPART(HOUR, InvoiceDate) AS Order_Hour,
    COUNT(DISTINCT InvoiceNo) AS Total_Orders
FROM online_retail
GROUP BY DATEPART(HOUR, InvoiceDate)
ORDER BY Total_Orders DESC;

--7. Sức mua: Mối tương quan giữa đơn giá và số lượng
SELECT 
    p.ProductName,
    f.UnitPrice,
    AVG(f.Quantity) AS Avg_Quantity_Per_Order,
    SUM(f.TotalAmount) AS Total_Revenue
FROM Fact_Sales f
JOIN Dim_Product p ON f.ProductKey = p.ProductKey
GROUP BY p.ProductName, f.UnitPrice
ORDER BY f.UnitPrice DESC;

--8. Tăng trưởng doanh thu hàng tháng (MoM Growth)
WITH MonthlyRevenue AS (
    SELECT 
        d.Year, 
        d.Month, 
        SUM(f.TotalAmount) AS Revenue
    FROM Fact_Sales f
    JOIN Dim_Date d ON f.DateKey = d.DateKey
    GROUP BY d.Year, d.Month
)
SELECT 
    Year, Month, Revenue,
    LAG(Revenue) OVER (ORDER BY Year, Month) AS Prev_Month_Revenue,
    (Revenue - LAG(Revenue) OVER (ORDER BY Year, Month)) / LAG(Revenue) OVER (ORDER BY Year, Month)* 100 AS Growth_Percentage
FROM MonthlyRevenue;

