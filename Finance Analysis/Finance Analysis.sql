-- To know customer code of chroma
SELECT * FROM dim_customer WHERE customer like "%croma%" AND market = "India";
-- customer code of chroma is 90002002

-- created get_fiscal_year function
-- created get_fiscal_quarter function

-- To know croma 2021 all transactions
SELECT 
	s.date, s.product_code, p.product, p.variant, s.sold_quantity, g.gross_price,
	ROUND((g.gross_price * s.sold_quantity),2) AS gross_price_total
FROM fact_sales_monthly s
	JOIN dim_product p 
		ON p.product_code = s.product_code
	JOIN fact_gross_price g
		ON g.product_code = s.product_code 
        AND g.fiscal_year = get_fiscal_year(s.date)
WHERE customer_code = 90002002 AND get_fiscal_year(date) = 2021
ORDER BY date
LIMIT 1000000;

-- Gross monthly total sales report for Croma India 
SELECT 
	s.date, 
    ROUND(SUM(g.gross_price * s.sold_quantity),2) AS gross_price_total
FROM fact_sales_monthly s
	JOIN fact_gross_price g 
		ON g.product_code = s.product_code 
		AND g.fiscal_year = get_fiscal_year(s.date)
WHERE customer_code = 90002002
GROUP BY s.date
ORDER BY s.date;

-- Gross yearly total sales report for Croma India 
SELECT
	get_fiscal_year(date) AS fiscal_year,
	ROUND(SUM(g.gross_price * s.sold_quantity),2) AS yearly_sales
FROM fact_sales_monthly s
	JOIN fact_gross_price g
		ON g.fiscal_year = get_fiscal_year(s.date) 
        AND g.product_code = s.product_code
WHERE customer_code = 90002002
GROUP BY get_fiscal_year(date)
ORDER BY fiscal_year;

-- Stored procedure for gross yearly total sales report

-- Stored procedure for market badge 

