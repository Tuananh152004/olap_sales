-- 1. Chuyển vào đúng database
USE Retail_DW; 
GO

-- 2. XÓA CÁC BẢNG CŨ (Nếu có) - Phải xóa Fact trước Dim do ràng buộc FK
IF OBJECT_ID('Fact_Sales', 'U') IS NOT NULL DROP TABLE Fact_Sales;
IF OBJECT_ID('Fact_Customer_Activity', 'U') IS NOT NULL DROP TABLE Fact_Customer_Activity;
IF OBJECT_ID('Dim_Product', 'U') IS NOT NULL DROP TABLE Dim_Product;
IF OBJECT_ID('Dim_Customer', 'U') IS NOT NULL DROP TABLE Dim_Customer;
IF OBJECT_ID('Dim_Date', 'U') IS NOT NULL DROP TABLE Dim_Date;
IF OBJECT_ID('Dim_Location', 'U') IS NOT NULL DROP TABLE Dim_Location;
IF OBJECT_ID('Dim_Invoice', 'U') IS NOT NULL DROP TABLE Dim_Invoice;
IF OBJECT_ID('Dim_PriceBand', 'U') IS NOT NULL DROP TABLE Dim_PriceBand;
GO



-- 1. Tạo Dimension: Dim_Date
CREATE TABLE Dim_Date (
    DateKey INT PRIMARY KEY, -- Định dạng YYYYMMDD
    FullDate DATE NOT NULL,
    Day INT NOT NULL,
    Month INT NOT NULL,
    Quarter INT NOT NULL,
    Year INT NOT NULL,
    DayOfWeek NVARCHAR(20),
    IsWeekend CHAR(1) -- 'Y' hoặc 'N'
);

-- 2. Tạo Dimension: Dim_Product (Bản Star Schema)
CREATE TABLE Dim_Product (
    ProductKey INT IDENTITY(1,1) PRIMARY KEY,
    ProductID NVARCHAR(20) NOT NULL, -- Natural Key
    ProductName NVARCHAR(255),
    CategoryName NVARCHAR(100),
    UnitPrice DECIMAL(18,2)
);

-- 3. Tạo Dimension: Dim_Customer
CREATE TABLE Dim_Customer (
    CustomerKey INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID NVARCHAR(20) NOT NULL,
    CustomerName NVARCHAR(100),
    Gender NVARCHAR(10),
    Age INT
);

-- 4. Tạo Dimension: Dim_Location
CREATE TABLE Dim_Location (
    LocationKey INT IDENTITY(1,1) PRIMARY KEY,
    LocationID NVARCHAR(20),
    City NVARCHAR(100),
    Country NVARCHAR(100)
);

-- 5. Tạo Dimension: Dim_Invoice
CREATE TABLE Dim_Invoice (
    InvoiceKey INT IDENTITY(1,1) PRIMARY KEY,
    InvoiceNo NVARCHAR(20) NOT NULL,
    Status NVARCHAR(20)
);

-- 6. Tạo Dimension: Dim_PriceBand
CREATE TABLE Dim_PriceBand (
    PriceBandKey INT IDENTITY(1,1) PRIMARY KEY,
    PriceBandName NVARCHAR(50),
    MinPrice DECIMAL(18,2),
    MaxPrice DECIMAL(18,2)
);

-- 7. Tạo Fact_Sales (Giao dịch)
CREATE TABLE Fact_Sales (
    SalesKey INT IDENTITY(1,1) PRIMARY KEY,
    DateKey INT REFERENCES Dim_Date(DateKey),
    ProductKey INT REFERENCES Dim_Product(ProductKey),
    CustomerKey INT REFERENCES Dim_Customer(CustomerKey),
    LocationKey INT REFERENCES Dim_Location(LocationKey),
    InvoiceKey INT REFERENCES Dim_Invoice(InvoiceKey),
    PriceBandKey INT REFERENCES Dim_PriceBand(PriceBandKey),
    Quantity INT,
    UnitPrice DECIMAL(18,2),
    TotalAmount AS (Quantity * UnitPrice) -- Cột tính toán tự động
);

-- 8. Tạo Fact_Customer_Activity (Tổng hợp)
CREATE TABLE Fact_Customer_Activity (
    ActivityKey INT IDENTITY(1,1) PRIMARY KEY,
    CustomerKey INT REFERENCES Dim_Customer(CustomerKey),
    TotalSpent DECIMAL(18,2),
    OrderCount INT,
    LastPurchaseDate DATE
);


-- Tạo bảng mới cho Snowflake
CREATE TABLE Dim_Category (
    CategoryKey INT IDENTITY(1,1) PRIMARY KEY,
    CategoryName NVARCHAR(100) NOT NULL
);

-- Sửa lại Dim_Product để nối với Dim_Category
ALTER TABLE Dim_Product DROP COLUMN CategoryName;
ALTER TABLE Dim_Product ADD CategoryKey INT REFERENCES Dim_Category(CategoryKey);

-- Nạp Dim_Date (Trích xuất từ InvoiceDate)
INSERT INTO Dim_Date (DateKey, FullDate, Day, Month, Quarter, Year, DayOfWeek, IsWeekend)
SELECT DISTINCT 
    CONVERT(INT, CONVERT(VARCHAR(8), CAST(InvoiceDate AS DATE), 112)),
    CAST(InvoiceDate AS DATE),
    DAY(InvoiceDate), MONTH(InvoiceDate), (MONTH(InvoiceDate)-1)/3+1, YEAR(InvoiceDate),
    DATENAME(WEEKDAY, InvoiceDate),
    CASE WHEN DATEPART(WEEKDAY, InvoiceDate) IN (1, 7) THEN 'Y' ELSE 'N' END
FROM online_retail WHERE InvoiceDate IS NOT NULL;

-- Nạp Dim_Product (Lấy 100 sản phẩm đầu tiên)
INSERT INTO Dim_Product (ProductID, ProductName, UnitPrice)
SELECT DISTINCT TOP 100 StockCode, Description, CAST(UnitPrice AS DECIMAL(18,2))
FROM online_retail WHERE StockCode IS NOT NULL;

-- Nạp Dim_Customer (Lấy khách hàng duy nhất)
INSERT INTO Dim_Customer (CustomerID)
SELECT DISTINCT TOP 100 CustomerID
FROM online_retail WHERE CustomerID IS NOT NULL;

-- 4. Nạp Dim_Location (Lấy từ cột Country trong file)
INSERT INTO Dim_Location (Country, City)
SELECT DISTINCT Country, 'Unknown' FROM online_retail;

-- 5. Nạp Dim_Invoice (Tính toán Status từ tiền tố 'C')
INSERT INTO Dim_Invoice (InvoiceNo, Status)
SELECT DISTINCT InvoiceNo, 
    CASE WHEN InvoiceNo LIKE 'C%' THEN 'Cancelled' ELSE 'Completed' END
FROM online_retail;

-- 6. Nạp Dim_PriceBand (Nạp dữ liệu tĩnh theo thiết kế)
INSERT INTO Dim_PriceBand (PriceBandName, MinPrice, MaxPrice)
VALUES ('Low', 0, 200), ('Medium', 201, 800), ('High', 801, 99999);

-- Nạp Fact_Sales (Lấy 500 dòng giao dịch để kiểm thử)
INSERT INTO Fact_Sales (DateKey, ProductKey, CustomerKey, Quantity, UnitPrice)
SELECT TOP 500
    CONVERT(INT, CONVERT(VARCHAR(8), CAST(src.InvoiceDate AS DATE), 112)),
    p.ProductKey,
    c.CustomerKey,
    TRY_CAST(src.Quantity AS INT),
    TRY_CAST(src.UnitPrice AS DECIMAL(18,2))
FROM online_retail src
JOIN Dim_Product p ON src.StockCode = p.ProductID
LEFT JOIN Dim_Customer c ON src.CustomerID = c.CustomerID;

-- 8. Nạp Fact_Customer_Activity (Tổng hợp hoạt động)
INSERT INTO Fact_Customer_Activity (CustomerKey, TotalSpent, OrderCount, LastPurchaseDate)
SELECT 
    c.CustomerKey,
    SUM(TRY_CAST(src.Quantity AS INT) * TRY_CAST(src.UnitPrice AS DECIMAL(18,2))),
    COUNT(DISTINCT src.InvoiceNo),
    MAX(CAST(src.InvoiceDate AS DATE))
FROM online_retail src
JOIN Dim_Customer c ON src.CustomerID = c.CustomerID
GROUP BY c.CustomerKey;

--test
SELECT COUNT(*) AS Orphaned_Records 
FROM Fact_Sales f 
LEFT JOIN Dim_Product p ON f.ProductKey = p.ProductKey 
WHERE p.ProductKey IS NULL;


USE Retail_DW;
GO

-- 1. Tạo bảng Category riêng (Snowflake)
CREATE TABLE Dim_Category (
    CategoryKey INT IDENTITY(1,1) PRIMARY KEY,
    CategoryName NVARCHAR(100) NOT NULL
);

-- 2. Thêm khóa ngoại vào Dim_Product để nối với bảng Category
ALTER TABLE Dim_Product ADD CategoryKey INT;
ALTER TABLE Dim_Product ADD CONSTRAINT FK_Product_Category 
FOREIGN KEY (CategoryKey) REFERENCES Dim_Category(CategoryKey);

-- 3. (Tùy chọn) Xóa cột CategoryName cũ trong Dim_Product để hoàn tất chuẩn hóa
-- ALTER TABLE Dim_Product DROP COLUMN CategoryName;


-- ktra data
SELECT COUNT(*) AS [Số dòng trong Fact] FROM Fact_Sales;

SELECT TOP 10 
    f.SalesKey, d.FullDate, p.ProductName, i.InvoiceNo, f.Quantity, f.TotalAmount
FROM Fact_Sales f
LEFT JOIN Dim_Date d ON f.DateKey = d.DateKey
LEFT JOIN Dim_Product p ON f.ProductKey = p.ProductKey
LEFT JOIN Dim_Invoice i ON f.InvoiceKey = i.InvoiceKey;
--
USE Retail_DW;
GO

-- Cập nhật lại InvoiceKey cho những dòng đang bị NULL
UPDATE f
SET f.InvoiceKey = i.InvoiceKey
FROM Fact_Sales f
JOIN online_retail src ON f.SalesKey = f.SalesKey -- Map ngược lại bảng thô
JOIN Dim_Invoice i ON LTRIM(RTRIM(src.InvoiceNo)) = LTRIM(RTRIM(i.InvoiceNo))
WHERE f.InvoiceKey IS NULL;
--- 3 câu truy vấn 
-- câu 1 
USE Retail_DW;
GO

SELECT TOP 10 
    f.SalesKey, 
    d.FullDate AS [Ngày Giao Dịch], 
    p.ProductName AS [Tên Sản Phẩm], 
    i.InvoiceNo AS [Số Hóa Đơn], 
    f.Quantity AS [Số Lượng], 
    f.TotalAmount AS [Thành Tiền]
FROM Fact_Sales f
JOIN Dim_Date d ON f.DateKey = d.DateKey
JOIN Dim_Product p ON f.ProductKey = p.ProductKey
JOIN Dim_Invoice i ON f.InvoiceKey = i.InvoiceKey;
-- cau 2
USE Retail_DW;
GO

SELECT 'Dim_Date' AS [Tên Bảng], COUNT(*) AS [Số Bản Ghi] FROM Dim_Date
UNION ALL SELECT 'Dim_Product', COUNT(*) FROM Dim_Product
UNION ALL SELECT 'Dim_Customer', COUNT(*) FROM Dim_Customer
UNION ALL SELECT 'Dim_Location', COUNT(*) FROM Dim_Location
UNION ALL SELECT 'Dim_Invoice', COUNT(*) FROM Dim_Invoice
UNION ALL SELECT 'Dim_PriceBand', COUNT(*) FROM Dim_PriceBand
UNION ALL SELECT 'Fact_Sales', COUNT(*) FROM Fact_Sales
UNION ALL SELECT 'Fact_Customer_Activity', COUNT(*) FROM Fact_Customer_Activity;
-- cau 3 
SELECT TOP 5 LocationKey FROM Fact_Sales;

USE Retail_DW;
GO

-- Cập nhật lại LocationKey cho bảng Fact
UPDATE f
SET f.LocationKey = l.LocationKey
FROM Fact_Sales f
JOIN online_retail src ON f.SalesKey = f.SalesKey -- Map ngược lại bảng thô
JOIN Dim_Location l ON LTRIM(RTRIM(src.Country)) = LTRIM(RTRIM(l.Country))
WHERE f.LocationKey IS NULL;

--
USE Retail_DW;
GO
SELECT 
    l.Country AS [Quốc Gia], 
    COUNT(f.SalesKey) AS [Số Lượng Giao Dịch],
    SUM(f.Quantity) AS [Tổng Sản Phẩm Đã Bán],
    FORMAT(SUM(f.TotalAmount), 'N2') AS [Tổng Doanh Thu (USD)]
FROM Fact_Sales f
JOIN Dim_Location l ON f.LocationKey = l.LocationKey
GROUP BY l.Country
ORDER BY SUM(f.TotalAmount) DESC;

--ktra 3.1 
SELECT 
    COUNT(*) AS Total_Rows,
    SUM(CASE WHEN CustomerID IS NULL THEN 1 ELSE 0 END) AS Missing_CustomerID,
    SUM(CASE WHEN Description IS NULL THEN 1 ELSE 0 END) AS Missing_Description
FROM online_retail;

SELECT InvoiceNo, StockCode, Description, Quantity, InvoiceDate, UnitPrice, CustomerID, Country, COUNT(*)
FROM online_retail
GROUP BY InvoiceNo, StockCode, Description, Quantity, InvoiceDate, UnitPrice, CustomerID, Country
HAVING COUNT(*) > 1;

SELECT * FROM online_retail 
WHERE TRY_CAST(Quantity AS INT) <= 0 
   OR TRY_CAST(UnitPrice AS DECIMAL(18,2)) <= 0;


--3.2
USE Retail_DW;
GO


-- Nạp một danh mục mặc định để "đón" các sản phẩm
INSERT INTO Dim_Category (CategoryName)
VALUES (N'Chưa phân loại'); 
-- Sau khi chạy dòng này, bảng Dim_Category sẽ có ID (CategoryKey) là 1 (do IDENTITY)
-- 1. Xử lý Trùng lặp & Chuẩn hóa cho Dim_Product
INSERT INTO Dim_Product (ProductID, ProductName, UnitPrice, CategoryKey)
SELECT DISTINCT 
    UPPER(LTRIM(RTRIM(StockCode))), 
    COALESCE(Description, N'Unknown Product'),
    TRY_CAST(UnitPrice AS DECIMAL(18,2)),
    1 -- Bây giờ số 1 này đã hợp lệ vì đã tồn tại trong Dim_Category
FROM online_retail
WHERE StockCode IS NOT NULL;
-- test 
SELECT TOP 10 * FROM Dim_Product;

-- 2. Xử lý Missing Value cho Dim_Customer
INSERT INTO Dim_Customer (CustomerID, CustomerName)
SELECT DISTINCT 
    COALESCE(CustomerID, 'GUEST'), -- Thay NULL bằng 'GUEST'
    'Walk-in Customer'
FROM online_retail;
--test 
SELECT CustomerID, COUNT(*) 
FROM Dim_Customer 
GROUP BY CustomerID 
HAVING COUNT(*) > 1;

-- 3. Tính toán cột phát sinh (Derived Fields) trong Fact_Sales
-- Cột TotalAmount được tính tự động (Computed Column) trong cấu trúc bảng đã tạo
INSERT INTO Fact_Sales (DateKey, ProductKey, CustomerKey, LocationKey, InvoiceKey, PriceBandKey, Quantity, UnitPrice)
SELECT 
    CONVERT(INT, CONVERT(VARCHAR(8), CAST(src.InvoiceDate AS DATE), 112)),
    p.ProductKey, 
    c.CustomerKey, 
    l.LocationKey, 
    i.InvoiceKey,
    pb.PriceBandKey,
    CAST(src.Quantity AS INT),
    CAST(src.UnitPrice AS DECIMAL(18,2))
FROM online_retail src
JOIN Dim_Product p ON LTRIM(RTRIM(src.StockCode)) = p.ProductID
JOIN Dim_Location l ON LTRIM(RTRIM(src.Country)) = l.Country
JOIN Dim_Invoice i ON LTRIM(RTRIM(src.InvoiceNo)) = i.InvoiceNo
LEFT JOIN Dim_Customer c ON LTRIM(RTRIM(src.CustomerID)) = c.CustomerID
JOIN Dim_PriceBand pb ON CAST(src.UnitPrice AS DECIMAL(18,2)) BETWEEN pb.MinPrice AND pb.MaxPrice
WHERE src.Quantity > 0; -- Loại bỏ hàng trả về/lỗi để làm sạch dữ liệu
--test
SELECT TOP 10 * FROM Fact_Sales;
SELECT COUNT(*) AS [Tổng số dòng Fact] FROM Fact_Sales;

-- Kiểm tra xem có bảng nào bị nạp chồng dữ liệu không
SELECT 'Dim_Product' AS TableName, ProductID, COUNT(*) FROM Dim_Product GROUP BY ProductID HAVING COUNT(*) > 1
UNION ALL
SELECT 'Dim_Invoice', InvoiceNo, COUNT(*) FROM Dim_Invoice GROUP BY InvoiceNo HAVING COUNT(*) > 1
UNION ALL
SELECT 'Dim_Customer', CustomerID, COUNT(*) FROM Dim_Customer GROUP BY CustomerID HAVING COUNT(*) > 1;

--fix lỗi 
USE Retail_DW;
GO

-- 1. Xóa sạch bảng con trước (Bắt buộc)
DELETE FROM Fact_Sales;
DELETE FROM Fact_Customer_Activity;

-- 2. Bây giờ bạn có thể xóa các bảng cha mà không bị báo lỗi nữa
DELETE FROM Dim_Product;
DELETE FROM Dim_Customer;
DELETE FROM Dim_Invoice;
DELETE FROM Dim_Location;
GO

--
DBCC CHECKIDENT ('Dim_Product', RESEED, 0);
DBCC CHECKIDENT ('Dim_Customer', RESEED, 0);
DBCC CHECKIDENT ('Dim_Invoice', RESEED, 0);
DBCC CHECKIDENT ('Dim_Location', RESEED, 0);
GO

--
-- Nạp Dim_Product (Mỗi ProductID chỉ xuất hiện 1 lần duy nhất)
INSERT INTO Dim_Product (ProductID, ProductName, UnitPrice, CategoryKey)
SELECT 
    UPPER(LTRIM(RTRIM(StockCode))), 
    MAX(CAST(Description AS NVARCHAR(MAX))), 
    MAX(TRY_CAST(UnitPrice AS DECIMAL(18,2))),
    1
FROM online_retail
WHERE StockCode IS NOT NULL
GROUP BY UPPER(LTRIM(RTRIM(StockCode)));

-- Nạp Dim_Customer (Mỗi CustomerID chỉ xuất hiện 1 lần duy nhất)
INSERT INTO Dim_Customer (CustomerID, CustomerName)
SELECT 
    COALESCE(CustomerID, 'GUEST'), 
    'Walk-in Customer'
FROM online_retail
GROUP BY COALESCE(CustomerID, 'GUEST');

USE Retail_DW;
GO

-- 1. Nạp lại Dim_Location (Cực kỳ quan trọng để Join Fact)
INSERT INTO Dim_Location (Country)
SELECT LTRIM(RTRIM(Country))
FROM online_retail
GROUP BY LTRIM(RTRIM(Country));

-- 2. Nạp lại Dim_Invoice (Nếu nãy chưa nạp)
INSERT INTO Dim_Invoice (InvoiceNo, Status)
SELECT 
    LTRIM(RTRIM(InvoiceNo)), 
    CASE WHEN InvoiceNo LIKE 'C%' THEN N'Cancelled' ELSE N'Completed' END
FROM online_retail
GROUP BY LTRIM(RTRIM(InvoiceNo)), CASE WHEN InvoiceNo LIKE 'C%' THEN N'Cancelled' ELSE N'Completed' END;

SELECT 
    (SELECT COUNT(*) FROM Dim_Product) AS ProductRows,
    (SELECT COUNT(*) FROM Dim_Location) AS LocationRows,
    (SELECT COUNT(*) FROM Dim_Invoice) AS InvoiceRows;

INSERT INTO Fact_Sales (DateKey, ProductKey, CustomerKey, LocationKey, InvoiceKey, PriceBandKey, Quantity, UnitPrice)
SELECT 
    CONVERT(INT, CONVERT(VARCHAR(8), TRY_CAST(src.InvoiceDate AS DATE), 112)),
    p.ProductKey, 
    c.CustomerKey, 
    l.LocationKey, 
    i.InvoiceKey,
    pb.PriceBandKey,
    TRY_CAST(src.Quantity AS INT),
    TRY_CAST(src.UnitPrice AS DECIMAL(18,2))
FROM online_retail src
LEFT JOIN Dim_Product p ON UPPER(LTRIM(RTRIM(src.StockCode))) = p.ProductID
LEFT JOIN Dim_Location l ON LTRIM(RTRIM(src.Country)) = l.Country
LEFT JOIN Dim_Invoice i ON LTRIM(RTRIM(src.InvoiceNo)) = i.InvoiceNo
LEFT JOIN Dim_Customer c ON COALESCE(src.CustomerID, 'GUEST') = c.CustomerID
LEFT JOIN Dim_PriceBand pb ON TRY_CAST(src.UnitPrice AS DECIMAL(18,2)) BETWEEN pb.MinPrice AND pb.MaxPrice
WHERE TRY_CAST(src.Quantity AS INT) > 0;
-- xem còn null hay không
SELECT 
    SUM(CASE WHEN ProductKey IS NULL THEN 1 ELSE 0 END) AS [Số lượng null trong Product],
    SUM(CASE WHEN CustomerKey IS NULL THEN 1 ELSE 0 END) AS [Số lượng null trong Customer],
    SUM(CASE WHEN InvoiceKey IS NULL THEN 1 ELSE 0 END) AS [Số lượng null trong Invoice],
    SUM(CASE WHEN PriceBandKey IS NULL THEN 1 ELSE 0 END) AS [Số lượng null trong PriceBand]
FROM Fact_Sales;

SELECT DISTINCT UnitPrice 
FROM online_retail 
WHERE TRY_CAST(UnitPrice AS DECIMAL(18,2)) > 0 -- Chỉ lấy giá dương
AND NOT EXISTS (
    SELECT 1 FROM Dim_PriceBand pb 
    WHERE TRY_CAST(online_retail.UnitPrice AS DECIMAL(18,2)) BETWEEN pb.MinPrice AND pb.MaxPrice
);

USE Retail_DW;
GO

-- Kiểm tra xem phân khúc cao nhất tên là gì
SELECT * FROM Dim_PriceBand;

-- Giả sử phân khúc cao nhất của bạn tên là 'High', hãy nới nó lên 1 triệu
UPDATE Dim_PriceBand 
SET MaxPrice = 1000000 
WHERE PriceBandName = 'High'; -- Bạn nhớ đổi tên 'High' cho đúng với bảng của bạn nhé!

UPDATE f
SET f.PriceBandKey = pb.PriceBandKey
FROM Fact_Sales f
JOIN Dim_PriceBand pb ON f.UnitPrice BETWEEN pb.MinPrice AND pb.MaxPrice
WHERE f.PriceBandKey IS NULL;

-- Script này kiểm tra: Nếu sản phẩm đã có thì cập nhật giá, nếu chưa có thì thêm mới
MERGE INTO Dim_Product AS target
USING (
    SELECT UPPER(TRIM(StockCode)) as ProductID, MAX(Description) as Name, MAX(UnitPrice) as Price
    FROM online_retail GROUP BY StockCode
) AS source
ON (target.ProductID = source.ProductID)
WHEN MATCHED THEN 
    UPDATE SET target.ProductName = source.Name, target.UnitPrice = source.Price
WHEN NOT MATCHED THEN
    INSERT (ProductID, ProductName, UnitPrice, CategoryKey)
    VALUES (source.ProductID, source.Name, source.Price, 1);

USE Retail_DW;
GO

SELECT TOP 20 
    ProductKey, 
    ProductID, 
    ProductName, 
    UnitPrice, 
    CategoryKey 
FROM Dim_Product
ORDER BY ProductKey DESC; -- Xem những dòng mới nhất/vừa xử lý

--3.3
USE Retail_DW;
GO

CREATE TABLE ETL_LOG (
    RunID INT IDENTITY(1,1) PRIMARY KEY,
    StartTime DATETIME,
    EndTime DATETIME,
    TableName NVARCHAR(100),
    RowsExtracted INT,
    RowsTransformed INT,
    RowsLoaded INT,
    ErrorCount INT,
    Status NVARCHAR(50) -- 'Success' hoặc 'Failed'
);



USE Retail_DW;
-- Không để GO ở giữa các dòng này
DECLARE @Start DATETIME = GETDATE();
DECLARE @CountBefore INT = (SELECT COUNT(*) FROM Fact_Sales);
DECLARE @Extracted INT = (SELECT COUNT(*) FROM online_retail);

-- Thực hiện nạp dữ liệu
INSERT INTO Fact_Sales (DateKey, ProductKey, CustomerKey, LocationKey, InvoiceKey, PriceBandKey, Quantity, UnitPrice)
SELECT 
    CONVERT(INT, CONVERT(VARCHAR(8), TRY_CAST(src.InvoiceDate AS DATE), 112)),
    p.ProductKey, c.CustomerKey, l.LocationKey, i.InvoiceKey, pb.PriceBandKey,
    TRY_CAST(src.Quantity AS INT), TRY_CAST(src.UnitPrice AS DECIMAL(18,2))
FROM online_retail src
LEFT JOIN Dim_Product p ON UPPER(LTRIM(RTRIM(src.StockCode))) = p.ProductID
LEFT JOIN Dim_Location l ON LTRIM(RTRIM(src.Country)) = l.Country
LEFT JOIN Dim_Invoice i ON LTRIM(RTRIM(src.InvoiceNo)) = i.InvoiceNo
LEFT JOIN Dim_Customer c ON COALESCE(src.CustomerID, 'GUEST') = c.CustomerID
LEFT JOIN Dim_PriceBand pb ON TRY_CAST(src.UnitPrice AS DECIMAL(18,2)) BETWEEN pb.MinPrice AND pb.MaxPrice
WHERE TRY_CAST(src.Quantity AS INT) > 0
AND NOT EXISTS (
    SELECT 1 FROM Fact_Sales fs 
    WHERE fs.InvoiceKey = i.InvoiceKey AND fs.ProductKey = p.ProductKey
);

DECLARE @CountAfter INT = (SELECT COUNT(*) FROM Fact_Sales);
DECLARE @Loaded INT = @CountAfter - @CountBefore;

-- Ghi Log Lần 1
INSERT INTO ETL_LOG (StartTime, EndTime, TableName, RowsExtracted, RowsLoaded, Status)
VALUES (@Start, GETDATE(), 'Fact_Sales', @Extracted, @Loaded, 'Success');

-- Hiển thị kết quả Log
SELECT * FROM ETL_LOG;

USE Retail_DW;
GO
TRUNCATE TABLE ETL_LOG; -- Xóa log cũ để bắt đầu từ RunID 1
DELETE FROM Fact_Sales; -- Xóa bảng Fact để nạp lại từ đầu

INSERT INTO online_retail (InvoiceNo, StockCode, Description, Quantity, InvoiceDate, UnitPrice, CustomerID, Country)
VALUES ('999999', '21777', 'NEW ITEM FOR LOG', 1, GETDATE(), 10.0, '12345', 'United Kingdom');

-- Xóa dòng lỗi cũ (nếu nó lỡ nằm trong Staging mà chưa vào được Fact)
-- Sau đó chèn dòng mới với ngày năm 2011
INSERT INTO online_retail (InvoiceNo, StockCode, Description, Quantity, InvoiceDate, UnitPrice, CustomerID, Country)
VALUES ('999999', '21777', 'NEW ITEM FOR LOG', 1, '2011-12-01', 10.0, '12345', 'United Kingdom');

USE Retail_DW;
GO

-- Thêm ngày 01/04/2026 vào bảng Dim_Date
INSERT INTO Dim_Date (DateKey, FullDate, Day, Month, Year, Quarter)
VALUES (20260401, '2026-04-01', 1, 4, 2026, 2);



TRUNCATE TABLE Fact_Sales;

CREATE INDEX IX_DimProduct_ID ON Dim_Product(ProductID);
CREATE INDEX IX_DimCustomer_ID ON Dim_Customer(CustomerID);
CREATE INDEX IX_DimLocation_Country ON Dim_Location(Country);
CREATE INDEX IX_DimInvoice_No ON Dim_Invoice(InvoiceNo);

INSERT INTO Fact_Sales (DateKey, ProductKey, CustomerKey, LocationKey, InvoiceKey, PriceBandKey, Quantity, UnitPrice)
SELECT 
    CONVERT(INT, CONVERT(VARCHAR(8), TRY_CAST(src.InvoiceDate AS DATE), 112)),
    p.ProductKey, 
    c.CustomerKey, 
    l.LocationKey, 
    i.InvoiceKey,
    pb.PriceBandKey,
    TRY_CAST(src.Quantity AS INT),
    TRY_CAST(src.UnitPrice AS DECIMAL(18,2))
FROM online_retail src
-- Dùng JOIN trực tiếp, không dùng hàm LTRIM/RTRIM ở đây để tận dụng Index
INNER JOIN Dim_Product p ON src.StockCode = p.ProductID 
INNER JOIN Dim_Location l ON src.Country = l.Country
INNER JOIN Dim_Invoice i ON src.InvoiceNo = i.InvoiceNo
LEFT JOIN Dim_Customer c ON src.CustomerID = c.CustomerID
INNER JOIN Dim_PriceBand pb ON TRY_CAST(src.UnitPrice AS DECIMAL(18,2)) BETWEEN pb.MinPrice AND pb.MaxPrice
WHERE TRY_CAST(src.Quantity AS INT) > 0;

USE Retail_DW;
GO

