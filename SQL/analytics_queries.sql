CREATE DATABASE IF NOT EXISTS Ecommerce_Analytics;
USE Ecommerce_Analytics;
SHOW COLUMNS FROM ecommercedata;
DROP TABLE IF EXISTS fact_sales;
CREATE TABLE fact_sales AS
SELECT 
Invoice,
StockCode,
Description,
Quantity,
STR_TO_DATE(InvoiceDate, '%m/%d/%Y %H:%i') AS OrderDateTime,
Price,
ROUND(Quantity * Price, 2) AS TotalRevenue,
    CASE 
        WHEN `Customer ID` IS NULL OR `Customer ID` = '' OR `Customer ID` = '107927.0' THEN 'Guest Customer'
        ELSE REPLACE(`Customer ID`, '.0', '') 
    END AS CustomerID,
    Country,
    CASE 
        WHEN Invoice LIKE 'C%' OR Quantity < 0 THEN 'Cancelled'
        ELSE 'Completed'
    END AS OrderStatus
FROM ecommercedata
WHERE Price > 0;
WITH MonthlySales AS (
    SELECT 
        DATE_FORMAT(OrderDateTime, '%Y-%m') AS YearMonth,
        ROUND(SUM(TotalRevenue), 2) AS MonthlyRevenue
    FROM fact_sales
    WHERE OrderStatus = 'Completed'
    GROUP BY DATE_FORMAT(OrderDateTime, '%Y-%m')
)
SELECT 
    YearMonth,
    MonthlyRevenue,
    LAG(MonthlyRevenue, 1) OVER (ORDER BY YearMonth) AS PreviousMonthRevenue,
    ROUND(
        ((MonthlyRevenue - LAG(MonthlyRevenue, 1) OVER (ORDER BY YearMonth)) 
        / LAG(MonthlyRevenue, 1) OVER (ORDER BY YearMonth)) * 100, 2
    ) AS MoM_Growth_Percentage
FROM MonthlySales;
WITH CustomerSpend AS (
    SELECT 
        Country,
        CustomerID,
        ROUND(SUM(TotalRevenue), 2) AS TotalSpent,
        DENSE_RANK() OVER (PARTITION BY Country ORDER BY SUM(TotalRevenue) DESC) AS SpendRank
    FROM fact_sales
    WHERE OrderStatus = 'Completed' AND CustomerID <> 'Guest Customer'
    GROUP BY Country, CustomerID
)
SELECT Country, SpendRank, CustomerID, TotalSpent
FROM CustomerSpend
WHERE SpendRank <= 3
ORDER BY Country, SpendRank;
WITH CustomerOrders AS (
    SELECT 
        CustomerID,
        COUNT(DISTINCT Invoice) AS TotalOrders
    FROM fact_sales
    WHERE OrderStatus = 'Completed' AND CustomerID <> 'Guest Customer'
    GROUP BY CustomerID
)
SELECT 
    CASE 
        WHEN TotalOrders = 1 THEN 'One-Time Customer'
        ELSE 'Repeat Customer'
    END AS CustomerType,
    COUNT(*) AS TotalCustomers
FROM CustomerOrders
GROUP BY CustomerType;
SELECT 
    DATE_FORMAT(OrderDateTime, '%Y-%m') AS YearMonth,
    ROUND(SUM(TotalRevenue), 2) AS MonthlyRevenue
FROM fact_sales
WHERE OrderStatus = 'Completed'
GROUP BY DATE_FORMAT(OrderDateTime, '%Y-%m')
ORDER BY YearMonth;
SELECT 
    DATE(OrderDateTime) AS SalesDate,
    ROUND(SUM(TotalRevenue), 2) AS DailyRevenue
FROM fact_sales
WHERE OrderStatus = 'Completed'
GROUP BY DATE(OrderDateTime)
ORDER BY SalesDate;
SELECT 
    Description,
    SUM(Quantity) AS TotalQuantity,
    ROUND(SUM(TotalRevenue), 2) AS TotalRevenue
FROM fact_sales
WHERE OrderStatus = 'Completed' 
  AND Description IS NOT NULL 
  AND Description <> ''
GROUP BY Description
ORDER BY TotalRevenue DESC
LIMIT 10;
select *
from fact_sales