-- create a helper table which contain sold quantity & forecast quantity
CREATE TABLE fact_act_est(
	SELECT 
		s.date AS date,s.fiscal_year AS fiscal_year,
		s.product_code AS product_code,s.customer_code AS customer_code,
		s.sold_quantity AS sold_quantity,f.forecast_quantity AS forecast_quantity
	FROM fact_sales_monthly s
		LEFT JOIN fact_forecast_monthly f 
        	USING (date, customer_code, product_code)
	)
	UNION
	(
	SELECT 
		f.date AS date,f.fiscal_year AS fiscal_year,
		f.product_code AS product_code,f.customer_code AS customer_code,
		s.sold_quantity AS sold_quantity,f.forecast_quantity AS forecast_quantity
	FROM fact_forecast_monthly  f
		LEFT JOIN fact_sales_monthly s 
        	USING (date, customer_code, product_code)
	);

UPDATE fact_act_est
	SET sold_quantity = 0
WHERE sold_quantity IS NULL;

UPDATE fact_act_est
	SET forecast_quantity = 0
WHERE forecast_quantity IS NULL;

-- used for update
SET SQL_SAFE_UPDATES = 0;

-- create triggers for sold quantity & forecast quantity auto updating
SHOW TRIGGERS;

-- create events
SHOW EVENTS;
SHOW VARIABLES LIKE "%event%"

delimiter |
	CREATE EVENT e_daily_log_purge
    	ON SCHEDULE
      	EVERY 5 SECOND
    	COMMENT 'Purge logs that are more than 5 days old'
    	DO
		BEGIN
        	delete from random_tables.session_logs 
        	where DATE(ts) < DATE("2022-10-22") - interval 5 day;
		END |
delimiter ;

-- Forecast accuracy for all customers for a given fiscal year
	WITH forecast_err_table AS (
		SELECT
			s.customer_code AS customer_code,
			c.customer AS customer_name,
			c.market AS market,
			SUM(s.sold_quantity) AS total_sold_qty,
			SUM(s.forecast_quantity) AS total_forecast_qty,
			SUM(s.forecast_quantity - s.sold_quantity) AS net_error,
			ROUND(SUM(s.forecast_quantity - s.sold_quantity)*100/sum(s.forecast_quantity),1) AS net_error_pct,
			SUM(ABS(s.forecast_quantity - s.sold_quantity)) as abs_error,
			ROUND(SUM(ABS(s.forecast_quantity-sold_quantity))*100/sum(s.forecast_quantity),2) AS abs_error_pct
		FROM fact_act_est s
			JOIN dim_customer c
				ON s.customer_code = c.customer_code
		WHERE s.fiscal_year = 2021
		GROUP BY customer_code
              	)
	SELECT 
            *,
            IF (abs_error_pct > 100, 0, 100.0 - abs_error_pct) AS forecast_accuracy
	FROM forecast_err_table
	ORDER BY forecast_accuracy DESC;           
-- convert above code to SP

-- Customer’s whose forecast accuracy has dropped from 2020 to 2021
		# step 1: Get forecast accuracy of FY 2021 and store that in a temporary table
		drop table if exists forecast_accuracy_2021;
CREATE TEMPORARY TABLE forecast_accuracy_2021
WITH forecast_err_table AS (
	SELECT
		s.customer_code AS customer_code,
		c.customer AS customer_name,
		c.market AS market,
		SUM(s.sold_quantity) AS total_sold_qty,
		SUM(s.forecast_quantity) AS total_forecast_qty,
		SUM(s.forecast_quantity-s.sold_quantity) AS net_error,
		ROUND(SUM(s.forecast_quantity-s.sold_quantity)*100/SUM(s.forecast_quantity),1) AS net_error_pct,
		SUM(ABS(s.forecast_quantity-s.sold_quantity)) AS abs_error,
		ROUND(SUM(ABS(s.forecast_quantity-sold_quantity))*100/SUM(s.forecast_quantity),2) AS abs_error_pct
	FROM fact_act_est s
		JOIN dim_customer c
			ON s.customer_code = c.customer_code
	WHERE s.fiscal_year=2021
	GROUP BY customer_code
)
SELECT 
	*,
    IF (abs_error_pct > 100, 0, 100.0 - abs_error_pct) AS forecast_accuracy
FROM forecast_err_table
ORDER BY forecast_accuracy DESC;

		# step 2: Get forecast accuracy of FY 2020 and store that also in a temporary table
		drop table if exists forecast_accuracy_2020;

CREATE TEMPORARY TABLE forecast_accuracy_2020
WITH forecast_err_table AS (
        SELECT
                s.customer_code AS customer_code,
                c.customer AS customer_name,
                c.market AS market,
                SUM(s.sold_quantity) AS total_sold_qty,
                SUM(s.forecast_quantity) AS total_forecast_qty,
                SUM(s.forecast_quantity-s.sold_quantity) AS net_error,
                ROUND(SUM(s.forecast_quantity-s.sold_quantity)*100/SUM(s.forecast_quantity),1) AS net_error_pct,
                SUM(ABS(s.forecast_quantity-s.sold_quantity)) AS abs_error,
                ROUND(SUM(ABS(s.forecast_quantity-sold_quantity))*100/SUM(s.forecast_quantity),2) AS abs_error_pct
        FROM fact_act_est s
			JOIN dim_customer c
				ON s.customer_code = c.customer_code
        WHERE s.fiscal_year=2020
        GROUP BY customer_code
)
select 
	*,
	IF (abs_error_pct > 100, 0, 100.0 - abs_error_pct) AS forecast_accuracy
FROM forecast_err_table
ORDER BY forecast_accuracy DESC;

		# step 3: Join forecast accuracy tables for 2020 and 2021 using a customer_code

SELECT 
	f_2020.customer_code,f_2020.customer_name,f_2020.market,
	f_2020.forecast_accuracy AS forecast_acc_2020,
	f_2021.forecast_accuracy AS forecast_acc_2021
FROM forecast_accuracy_2020 f_2020
	JOIN forecast_accuracy_2021 f_2021
		ON f_2020.customer_code = f_2021.customer_code 
WHERE f_2021.forecast_accuracy < f_2020.forecast_accuracy
ORDER BY forecast_acc_2020 DESC;
