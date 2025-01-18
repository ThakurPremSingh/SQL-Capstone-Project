-- get required columns
EXPLAIN ANALYZE
SELECT 
	s.date, s.product_code, p.product, p.variant, s.sold_quantity, g.gross_price,
	ROUND((g.gross_price * s.sold_quantity),2) AS gross_price_total,
    pre.pre_invoice_discount_pct
FROM fact_sales_monthly s
	JOIN dim_product p 
		ON p.product_code = s.product_code
	JOIN fact_gross_price g
		ON g.product_code = s.product_code 
        AND g.fiscal_year = get_fiscal_year(s.date)
	JOIN fact_pre_invoice_deductions pre
		ON pre.customer_code = s.customer_code 
        AND pre.fiscal_year = get_fiscal_year(s.date)
WHERE get_fiscal_year(date) = 2021
ORDER BY date
LIMIT 1000000;

-- create dim_date table for performance improvement (avoid using get_fiscal_year)
EXPLAIN ANALYZE
SELECT 
	s.date, s.product_code, p.product, p.variant, s.sold_quantity, g.gross_price,
	ROUND((g.gross_price * s.sold_quantity),2) AS gross_price_total,
    pre.pre_invoice_discount_pct
FROM fact_sales_monthly s
	JOIN dim_product p 
		ON p.product_code = s.product_code
	JOIN dim_date dt
		ON dt.calendar_date = s.date
	JOIN fact_gross_price g
		ON g.product_code = s.product_code 
        AND g.fiscal_year = dt.fiscal_year
	JOIN fact_pre_invoice_deductions pre
		ON pre.customer_code = s.customer_code 
        AND pre.fiscal_year = dt.fiscal_year
WHERE dt.fiscal_year = 2021
ORDER BY date
LIMIT 1000000;

-- create fiscal_year column in fact_sales_monthly table for performance improvement 

SELECT 
	s.date, s.product_code, p.product, p.variant, s.sold_quantity, g.gross_price,
	ROUND((g.gross_price * s.sold_quantity),2) AS gross_price_total,
    pre.pre_invoice_discount_pct
FROM fact_sales_monthly s
	JOIN dim_product p 
		ON p.product_code = s.product_code
	JOIN fact_gross_price g
		ON g.product_code = s.product_code 
        AND g.fiscal_year = s.fiscal_year
	JOIN fact_pre_invoice_deductions pre
		ON pre.customer_code = s.customer_code 
        AND pre.fiscal_year = s.fiscal_year
WHERE s.fiscal_year = 2021
ORDER BY date
LIMIT 1000000;

-- adding columns
WITH cte1 AS(
SELECT 
	s.date, s.product_code, p.product, p.variant, s.sold_quantity, g.gross_price,
	ROUND((g.gross_price * s.sold_quantity),2) AS gross_price_total,
    pre.pre_invoice_discount_pct
FROM fact_sales_monthly s
	JOIN dim_product p 
		ON p.product_code = s.product_code
	JOIN fact_gross_price g
		ON g.product_code = s.product_code 
        AND g.fiscal_year = s.fiscal_year
	JOIN fact_pre_invoice_deductions pre
		ON pre.customer_code = s.customer_code 
        AND pre.fiscal_year = s.fiscal_year
WHERE s.fiscal_year = 2021
ORDER BY date
LIMIT 1000000)
SELECT *, (gross_price_total - gross_price_total*pre_invoice_discount_pct) AS net_invoice
FROM cte1;

-- create view (virtual table) with above code named sales_preinv_discount
SELECT *, (gross_price_total - gross_price_total*pre_invoice_discount_pct) AS net_invoice
FROM sales_preinv_discount;

-- create view for sales_postinv_discount 
SELECT *, (1 - post_invoice_discount_pct) * net_invoice_sales AS net_sales
FROM sales_postinv_discount;

-- create view for net_sales

-- create view for gross_sales

-- Top / Bottom markets
SELECT 
	market, 
    ROUND(SUM(net_sales)/1000000,2) AS net_sales_mln
FROM net_sales
WHERE fiscal_year = 2021
GROUP BY market
ORDER By net_sales_mln DESC
LIMIT 5;
-- Top / Bottom markets convert it to SP(get_top_n_markets_ny_net_sales)

-- Top / Bottom customers
SELECT 
	c.customer, 
    ROUND(SUM(net_sales)/1000000,2) AS net_sales_mln
FROM net_sales n
	JOIN dim_customer c
		ON n.customer_code = c.customer_code
WHERE fiscal_year = 2021
GROUP BY customer
ORDER By net_sales_mln DESC;

-- Top / Bottom products (convert it to SP)

SELECT
		product,
		ROUND(SUM(net_sales)/1000000,2) AS net_sales_mln
FROM net_sales
WHERE fiscal_year = 2021
GROUP BY product
ORDER BY net_sales_mln DESC;

-- customers net sales % share in global market
WITH cte1 AS(
 SELECT 
	c.customer, 
    ROUND(SUM(net_sales)/1000000,2) AS net_sales_mln
FROM net_sales s
	JOIN dim_customer c
		ON s.customer_code = c.customer_code
WHERE fiscal_year = 2021
GROUP BY customer
)
SELECT 
	*, 
    net_sales_mln * 100 / SUM(net_sales_mln) OVER() AS pct_net_sales
FROM cte1
ORDER By net_sales_mln DESC;


-- region wise net sales % share in global market
WITH cte1 AS(
 SELECT 
	c.customer, c.region,
    ROUND(SUM(net_sales)/1000000,2) AS net_sales_mln
FROM net_sales s
	JOIN dim_customer c
		ON s.customer_code = c.customer_code
WHERE fiscal_year = 2021
GROUP BY c.customer, c.region
)
SELECT 
	*, 
    net_sales_mln * 100 / SUM(net_sales_mln) OVER(PARTITION BY region) AS pct_share_region
FROM cte1
ORDER By region,net_sales_mln DESC;

-- Top n products in each division based on sold quantity
WITH cte1 AS (
	SELECT
		p.division,p.product,SUM(sold_quantity) AS total_qty
	FROM fact_sales_monthly s
		JOIN dim_product p
			ON p.product_code=s.product_code
	WHERE fiscal_year = 2021
	GROUP BY p.product,p.division
    ),
	cte2 AS (
    SELECT 
		*,
		DENSE_RANK() OVER (PARTITION BY division ORDER BY total_qty DESC) AS drnk
	FROM cte1)
SELECT 
	* 
FROM cte2 
where drnk<=3;

-- top n markets in every region by their gross sales amount

WITH cte1 AS (
	SELECT
		c.market,c.region,
		ROUND(SUM(gross_price_total)/1000000,2) AS gross_sales_mln
	FROM gross_sales s
	JOIN dim_customer c
		ON c.customer_code=s.customer_code
	WHERE fiscal_year = 2021
	GROUP BY market, region
	ORDER BY gross_sales_mln DESC
),
cte2 AS (
	SELECT 
		*,
		DENSE_RANK() OVER(PARTITION BY region ORDER BY gross_sales_mln DESC) AS drnk
	FROM cte1
)
SELECT 
	* 
FROM cte2 
WHERE drnk <= 2;