-- Project: Kerala FMCG Sales Analysis 2025
-- Author: Jasna KY
-- Database: MySQL 8.0 | Table: sales (5,000 rows)
-- Sections: KPIs, Brand/District/Channel analysis, Time trends,
--           Window functions, Data quality checks, Views for Power BI

USE kerala_fmcg;

-- Q1: Overall KPIs
-- Expected: 5000 invoices, 60226 units, net_sales = 5752591.73

SELECT
    COUNT(DISTINCT Invoice_ID)                                   AS total_invoices,
    SUM(Units_Sold)                                              AS total_units,
    ROUND(SUM(Gross_Sales_INR), 2)                               AS gross_sales,
    ROUND(SUM(Discount_Amount_INR), 2)                           AS total_discount,
    ROUND(SUM(Net_Sales_INR), 2)                                 AS net_sales,
    ROUND(SUM(Net_Sales_INR) / COUNT(*), 2)                      AS avg_invoice_value,
    ROUND(SUM(Discount_Amount_INR) / SUM(Gross_Sales_INR) * 100, 2) AS discount_pct
FROM sales;

-- Q2: Brand performance with share % and rank
-- Expected: Milma first, 881001.44 (15.31%); 13 rows

SELECT
    Brand,
    COUNT(*)                                                      AS invoices,
    SUM(Units_Sold)                                               AS units_sold,
    ROUND(SUM(Net_Sales_INR), 2)                                  AS net_sales,
    ROUND(SUM(Net_Sales_INR) * 100.0 / SUM(SUM(Net_Sales_INR)) OVER (), 2) AS sales_share_pct,
    ROUND(SUM(Discount_Amount_INR) * 100.0 / SUM(Gross_Sales_INR), 2)      AS discount_pct,
    RANK() OVER (ORDER BY SUM(Net_Sales_INR) DESC)                AS sales_rank
FROM sales
GROUP BY Brand
ORDER BY net_sales DESC;

-- Q3: Monthly net sales, MoM growth % and running total
WITH monthly AS (
    SELECT Month_Num, Month_Name, ROUND(SUM(Net_Sales_INR), 2) AS net_sales
    FROM sales
    GROUP BY Month_Num, Month_Name
)
SELECT
    Month_Name,
    net_sales,
    ROUND((net_sales - LAG(net_sales) OVER (ORDER BY Month_Num))
          * 100.0 / LAG(net_sales) OVER (ORDER BY Month_Num), 2) AS mom_growth_pct,
    ROUND(SUM(net_sales) OVER (ORDER BY Month_Num), 2)           AS running_total
FROM monthly
ORDER BY Month_Num;

-- Q4: District performance with share % and rank
SELECT
    District,
    COUNT(*)                                                      AS invoices,
    SUM(Units_Sold)                                               AS units_sold,
    ROUND(SUM(Net_Sales_INR), 2)                                  AS net_sales,
    ROUND(SUM(Net_Sales_INR) * 100.0 / SUM(SUM(Net_Sales_INR)) OVER (), 2) AS sales_share_pct,
    ROUND(SUM(Discount_Amount_INR) * 100.0 / SUM(Gross_Sales_INR), 2)      AS discount_pct,
    RANK() OVER (ORDER BY SUM(Net_Sales_INR) DESC)                AS sales_rank
FROM sales
GROUP BY District
ORDER BY net_sales DESC;

-- Q5: Top 3 products per brand
WITH product_sales AS (
    SELECT Brand, Product,
           ROUND(SUM(Net_Sales_INR), 2) AS net_sales,
           SUM(Units_Sold)              AS units_sold
    FROM sales
    GROUP BY Brand, Product
),
ranked AS (
    SELECT Brand, Product, net_sales, units_sold,
           ROW_NUMBER() OVER (PARTITION BY Brand ORDER BY net_sales DESC) AS product_rank
    FROM product_sales
)
SELECT Brand, Product, net_sales, units_sold, product_rank
FROM ranked
WHERE product_rank <= 3
ORDER BY Brand, product_rank;

-- Q6: Best-selling brand in each district
WITH brand_district AS (
    SELECT District, Brand, ROUND(SUM(Net_Sales_INR), 2) AS net_sales
    FROM sales
    GROUP BY District, Brand
),
ranked AS (
    SELECT District, Brand, net_sales,
           RANK() OVER (PARTITION BY District ORDER BY net_sales DESC) AS brand_rank
    FROM brand_district
)
SELECT District, Brand AS top_brand, net_sales
FROM ranked
WHERE brand_rank = 1
ORDER BY net_sales DESC;

-- Q7: Channel performance, average invoice value and discount %
SELECT
    Sales_Channel,
    COUNT(*)                                                      AS invoices,
    ROUND(SUM(Net_Sales_INR), 2)                                  AS net_sales,
    ROUND(SUM(Net_Sales_INR) / COUNT(*), 2)                       AS avg_invoice_value,
    ROUND(SUM(Discount_Amount_INR) * 100.0 / SUM(Gross_Sales_INR), 2) AS discount_pct
FROM sales
GROUP BY Sales_Channel
ORDER BY net_sales DESC;

-- Q8: Brands whose discount % is higher than the overall discount %
WITH brand_discount AS (
    SELECT Brand,
           ROUND(SUM(Discount_Amount_INR) * 100.0 / SUM(Gross_Sales_INR), 2) AS discount_pct,
           ROUND(SUM(Net_Sales_INR), 2)                                      AS net_sales
    FROM sales
    GROUP BY Brand
)
SELECT Brand, discount_pct, net_sales
FROM brand_discount
WHERE discount_pct > (SELECT SUM(Discount_Amount_INR) * 100.0 / SUM(Gross_Sales_INR) FROM sales)
ORDER BY discount_pct DESC;

-- Q9: Pareto analysis, cumulative share of net sales by product
WITH product_sales AS (
    SELECT Product, SUM(Net_Sales_INR) AS net_sales
    FROM sales
    GROUP BY Product
)
SELECT
    ROW_NUMBER() OVER (ORDER BY net_sales DESC)                  AS product_rank,
    Product,
    ROUND(net_sales, 2)                                          AS net_sales,
    ROUND(net_sales * 100.0 / SUM(net_sales) OVER (), 2)         AS share_pct,
    ROUND(SUM(net_sales) OVER (ORDER BY net_sales DESC
          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
          * 100.0 / SUM(net_sales) OVER (), 2)                   AS cumulative_share_pct
FROM product_sales
ORDER BY net_sales DESC;

-- Q10: Data quality checks (all results should be 0)
-- Expected: 0, 0, 0, 0

SELECT
    COUNT(*) - COUNT(DISTINCT Invoice_ID)                        AS duplicate_invoices,
    SUM(CASE WHEN Brand IS NULL OR District IS NULL
              OR Net_Sales_INR IS NULL OR Date IS NULL THEN 1 ELSE 0 END) AS rows_with_nulls,
    SUM(CASE WHEN ABS(Units_Sold * Unit_Price_INR - Gross_Sales_INR) > 0.01
             THEN 1 ELSE 0 END)                                  AS gross_sales_errors,
    SUM(CASE WHEN ABS(Gross_Sales_INR - Discount_Amount_INR - Net_Sales_INR) > 0.01
             THEN 1 ELSE 0 END)                                  AS net_sales_errors
FROM sales;

-- View 1: Monthly sales
CREATE OR REPLACE VIEW vw_monthly_sales AS
SELECT
    Month_Num,
    Month_Name,
    ROUND(SUM(Net_Sales_INR), 2)                                  AS net_sales,
    SUM(Units_Sold)                                               AS units_sold,
    COUNT(*)                                                      AS invoices,
    ROUND(SUM(Discount_Amount_INR) * 100.0 / SUM(Gross_Sales_INR), 2) AS discount_pct
FROM sales
GROUP BY Month_Num, Month_Name;

-- View 2: Brand summary
CREATE OR REPLACE VIEW vw_brand_summary AS
SELECT
    Brand,
    COUNT(*)                                                      AS invoices,
    SUM(Units_Sold)                                               AS units_sold,
    ROUND(SUM(Gross_Sales_INR), 2)                                AS gross_sales,
    ROUND(SUM(Discount_Amount_INR), 2)                            AS total_discount,
    ROUND(SUM(Net_Sales_INR), 2)                                  AS net_sales,
    ROUND(SUM(Net_Sales_INR) * 100.0 / SUM(SUM(Net_Sales_INR)) OVER (), 2) AS sales_share_pct,
    ROUND(SUM(Discount_Amount_INR) * 100.0 / SUM(Gross_Sales_INR), 2)      AS discount_pct
FROM sales
GROUP BY Brand;

-- View 3: District summary
CREATE OR REPLACE VIEW vw_district_summary AS
SELECT
    District,
    COUNT(*)                                                      AS invoices,
    SUM(Units_Sold)                                               AS units_sold,
    ROUND(SUM(Net_Sales_INR), 2)                                  AS net_sales,
    ROUND(SUM(Net_Sales_INR) * 100.0 / SUM(SUM(Net_Sales_INR)) OVER (), 2) AS sales_share_pct,
    ROUND(SUM(Discount_Amount_INR) * 100.0 / SUM(Gross_Sales_INR), 2)      AS discount_pct
FROM sales
GROUP BY District;

-- View 4: Sales channel summary
CREATE OR REPLACE VIEW vw_channel_summary AS
SELECT
    Sales_Channel,
    COUNT(*)                                                      AS invoices,
    ROUND(SUM(Net_Sales_INR), 2)                                  AS net_sales,
    ROUND(SUM(Net_Sales_INR) / COUNT(*), 2)                       AS avg_invoice_value,
    ROUND(SUM(Discount_Amount_INR) * 100.0 / SUM(Gross_Sales_INR), 2) AS discount_pct
FROM sales
GROUP BY Sales_Channel;
