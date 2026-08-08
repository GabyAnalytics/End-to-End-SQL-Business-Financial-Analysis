SELECT *
FROM customers
;

USE financial_retail_analytics;

SHOW tables;

DESCRIBE order_items;

SELECT *
FROM order_items;

SELECT *
FROM orders;

SELECT *
FROM payments;

SELECT *
FROM products;

SELECT *
FROM `returns`;

SELECT 
	SUM(oi.quantity * p.unit_price) total_revenue
FROM order_items oi
JOIN products p
	ON oi.product_id = p.product_id
JOIN orders o
	ON oi.order_id = o.order_id
WHERE o.order_status = 'Completed';

SELECT 
	YEAR(o.order_date) `year`,
    MONTH(o.order_date) `month`,
	SUM(oi.quantity * p.unit_price) revenue
FROM order_items oi
JOIN products p
	ON oi.product_id = p.product_id
JOIN orders o
	ON oi.order_id = o.order_id
WHERE o.order_status = 'Completed'
GROUP BY 
	year(o.order_date),
    MONTH(o.order_date)
ORDER BY
	year,
    month;

SELECT 
	c.customer_segment,
    SUM(oi.quantity * p.unit_price) AS revenue
FROM customers c
JOIN orders o
	ON c.customer_id = o.customer_id
JOIN order_items oi
	ON o.order_id = oi.order_id
JOIN products p
	ON oi.product_id = p.product_id
WHERE o.order_status = 'Completed'
GROUP BY
	c.customer_segment
ORDER BY
	revenue DESC;


SELECT
	TRIM(LEFT(p.product_name, LENGTH(p.product_name) - 4)) AS product_name,
    SUM(oi.quantity * p.unit_price) AS revenue
FROM products p
JOIN order_items oi
	ON oi.product_id = p.product_id
GROUP BY 
	TRIM(LEFT(p.product_name, LENGTH(p.product_name) - 4))
ORDER BY
	revenue DESC;

CREATE TABLE products_backup AS
SELECT *
FROM products;

SELECT *
FROM products_backup;

SELECT 
	product_name as old_product_name,
    TRIM(LEFT(product_name, LENGTH(product_name) - 4)) AS new_product
FROM products;

UPDATE products
SET product_name = TRIM(LEFT(product_name, LENGTH(product_name) - 4))
;

SELECT DISTINCT product_name
FROM products;

SELECT
	p.product_name,
    SUM(oi.quantity * p.unit_price) revenue
FROM products p
JOIN order_items oi
	ON p.product_id = oi.product_id
JOIN orders o
	ON oi.order_id = o.order_id
WHERE o.order_status = 'Completed'
GROUP BY 
	p.product_name
ORDER BY
	revenue DESC;


SELECT 
	c.customer_name,
    SUM(oi.quantity * p.unit_price) revenue
FROM customers c
JOIN orders o
	ON c.customer_id = o.customer_id
JOIN order_items oi
	ON oi.order_id = o.order_id
JOIN products p
	ON p.product_id = oi.product_id
WHERE o.order_status = 'Completed'
GROUP BY
	c.customer_id,
	c.customer_name,
    c.customer_segment
ORDER BY
	revenue DESC
LIMIT 5;


WITH customer_revenue AS (
	SELECT
		c.customer_id,
        c.customer_name,
        c.customer_segment,
        SUM(oi.quantity * p.unit_price) AS revenue
	FROM customers c
    JOIN orders o
		ON c.customer_id = o.customer_id
	JOIN order_items oi
		ON o.order_id = oi.order_id
	JOIN products p
		ON oi.product_id = p.product_id
	WHERE o.order_status = 'Completed'
    GROUP BY 
		c.customer_id,
        c.customer_name,
        c.customer_segment
)
SELECT
	customer_id,
    customer_name,
    ROUND(revenue, 2) AS revenue
FROM customer_revenue
WHERE revenue > (
	SELECT AVG(revenue)
    FROM customer_revenue
)
ORDER BY 
	revenue DESC;
        


SELECT
	c.customer_id,
    c.customer_name,
    COUNT(DISTINCT o.order_id) AS total_orders
FROM customers c
JOIN orders o
	ON c.customer_id = o.customer_id
WHERE order_status = 'completed'
GROUP BY 
	c.customer_id,
    c.customer_name
ORDER BY 
	total_orders DESC;


SELECT 
	ROUND(AVG(total_orders), 2) AS avg_orders_per_customer
FROM (
	SELECT
		customer_id,
        COUNT(DISTINCT order_id) AS total_orders
	FROM orders
    WHERE order_status = 'completed'
    GROUP BY customer_id
) x;



SELECT
	COUNT(CASE WHEN order_count > 1 THEN 1 END) AS repeat_customers,
    COUNT(*) AS total_customers,
    ROUND(
		COUNT(CASE WHEN order_count > 1 THEN 1 END)
        * 100.0 / COUNT(*),
        2
	) AS repeat_purchase_percentage
FROM (
	SELECT
		customer_id,
        COUNT(DISTINCT order_id) AS order_count
	FROM orders
    WHERE order_status = 'Completed'
    GROUP BY customer_id
) x;



WITH sold AS (
    SELECT
        product_id,
        SUM(quantity) AS quantity_sold
    FROM order_items
    GROUP BY product_id
),
returned AS (
    SELECT
        product_id,
        SUM(quantity_returned) AS quantity_returned
    FROM returns
    GROUP BY product_id
)

SELECT
    p.product_id,
    p.product_name,
    s.quantity_sold,
    COALESCE(r.quantity_returned, 0) AS quantity_returned,
    ROUND(
        COALESCE(r.quantity_returned, 0) * 100.0
        / NULLIF(s.quantity_sold, 0),
        2
    ) AS return_rate_percentage
FROM products p
JOIN sold s
    ON p.product_id = s.product_id
LEFT JOIN returned r
    ON p.product_id = r.product_id
ORDER BY return_rate_percentage DESC;



SELECT
    p.category,
    SUM(r.quantity_returned * p.unit_price) AS returned_value
FROM returns r
JOIN products p
    ON r.product_id = p.product_id
GROUP BY p.category
ORDER BY returned_value DESC;



SELECT
    SUM(r.quantity_returned * p.unit_price) AS potential_revenue_lost
FROM returns r
JOIN products p
    ON r.product_id = p.product_id;




WITH sales AS (
    SELECT
        p.product_id,
        p.product_name,
        SUM(oi.quantity * p.unit_price) AS total_revenue
    FROM products p
    JOIN order_items oi
        ON p.product_id = oi.product_id
    JOIN orders o
        ON oi.order_id = o.order_id
    WHERE o.order_status = 'Completed'
    GROUP BY
        p.product_id,
        p.product_name
),

sold AS (
    SELECT
        product_id,
        SUM(quantity) AS quantity_sold
    FROM order_items
    GROUP BY product_id
),

returned AS (
    SELECT
        product_id,
        SUM(quantity_returned) AS quantity_returned
    FROM returns
    GROUP BY product_id
),

product_returns AS (
    SELECT
        s.product_id,
        s.quantity_sold,
        COALESCE(r.quantity_returned, 0) AS quantity_returned,
        COALESCE(r.quantity_returned, 0) * 100.0
        / NULLIF(s.quantity_sold, 0) AS return_rate
    FROM sold s
    LEFT JOIN returned r
        ON s.product_id = r.product_id
)

SELECT
    s.product_id,
    s.product_name,
    ROUND(s.total_revenue, 2) AS total_revenue,
    ROUND(pr.return_rate, 2) AS return_rate_percentage
FROM sales s
JOIN product_returns pr
    ON s.product_id = pr.product_id
WHERE s.total_revenue > (
    SELECT AVG(total_revenue)
    FROM sales
)
AND pr.return_rate > (
    SELECT AVG(return_rate)
    FROM product_returns
)
ORDER BY
    s.total_revenue DESC,
    pr.return_rate DESC;
    
    
    
SELECT
	payment_method,
    COUNT(*) AS number_of_payments,
    ROUND(
		COUNT(*) * 100.0 / (SELECT COUNT(*) FROM payments),
        2
    ) AS percentage_of_payments,
    ROUND(SUM(amount), 2) AS total_payment_value
FROM payments
GROUP BY payment_method
ORDER BY number_of_payments DESC;



SELECT
    payment_status,
    COUNT(*) AS number_of_transactions,
    ROUND(SUM(amount), 2) AS total_amount,
    ROUND(
        COUNT(*) * 100.0 / (SELECT COUNT(*) FROM payments),
        2
    ) AS percentage_of_transactions
FROM payments
GROUP BY payment_status
ORDER BY number_of_transactions DESC;


SELECT
    o.order_id,
    o.customer_id,
    o.order_date,
    p.payment_method,
    p.amount,
    p.payment_status
FROM orders o
JOIN payments p
    ON o.order_id = p.order_id
WHERE o.order_status = 'Completed'
AND p.payment_status = 'Pending'
ORDER BY p.amount DESC;


WITH product_performance AS (
    SELECT
        p.product_id,
        p.product_name,
        SUM(oi.quantity * p.unit_price) AS total_revenue,
        SUM(oi.quantity * (p.unit_price - p.unit_cost)) AS total_profit
    FROM products p
    JOIN order_items oi
        ON p.product_id = oi.product_id
    JOIN orders o
        ON oi.order_id = o.order_id
    WHERE o.order_status = 'Completed'
    GROUP BY
        p.product_id,
        p.product_name
)


SELECT
    product_id,
    product_name,
    ROUND(total_revenue, 2) AS total_revenue,
    ROUND(total_profit, 2) AS total_profit,
    ROUND(
        total_profit * 100.0 / NULLIF(total_revenue, 0),
        2
    ) AS profit_margin_percentage
FROM product_performance
WHERE total_revenue > (
    SELECT AVG(total_revenue)
    FROM product_performance
)
AND total_profit > (
    SELECT AVG(total_profit)
    FROM product_performance
)
ORDER BY total_profit DESC;




WITH sales AS (
    SELECT
        p.category,
        SUM(oi.quantity * p.unit_price) AS total_revenue,
        SUM(
            oi.quantity * (p.unit_price - p.unit_cost)
        ) AS total_profit
    FROM products p
    JOIN order_items oi
        ON p.product_id = oi.product_id
    JOIN orders o
        ON oi.order_id = o.order_id
    WHERE o.order_status = 'Completed'
    GROUP BY p.category
),

returns AS (
    SELECT
        p.category,
        SUM(r.quantity_returned * p.unit_price) AS returned_value
    FROM returns r
    JOIN products p
        ON r.product_id = p.product_id
    GROUP BY p.category
)

SELECT
    s.category,
    ROUND(s.total_revenue, 2) AS total_revenue,
    ROUND(s.total_profit, 2) AS total_profit,
    ROUND(
        s.total_profit * 100.0 / NULLIF(s.total_revenue, 0),
        2
    ) AS profit_margin_percentage,
    ROUND(COALESCE(r.returned_value, 0), 2) AS returned_value
FROM sales s
LEFT JOIN returns r
    ON s.category = r.category
ORDER BY returned_value DESC;



WITH customer_performance AS (
    SELECT
        c.customer_id,
        c.customer_name,
        c.customer_segment,
        SUM(oi.quantity * p.unit_price) AS total_revenue,
        COUNT(DISTINCT o.order_id) AS total_orders,
        MAX(o.order_date) AS last_order_date
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    JOIN products p
        ON oi.product_id = p.product_id
    WHERE o.order_status = 'Completed'
    GROUP BY
        c.customer_id,
        c.customer_name,
        c.customer_segment
)

SELECT
    customer_id,
    customer_name,
    customer_segment,
    ROUND(total_revenue, 2) AS total_revenue,
    total_orders,
    last_order_date,
    DATEDIFF(
        (SELECT MAX(order_date)
         FROM orders
         WHERE order_status = 'Completed'),
        last_order_date
    ) AS days_since_last_purchase
FROM customer_performance
WHERE total_revenue > (
    SELECT AVG(total_revenue)
    FROM customer_performance
)
AND DATEDIFF(
    (SELECT MAX(order_date)
     FROM orders
     WHERE order_status = 'Completed'),
    last_order_date
) > 60
ORDER BY total_revenue DESC;



SELECT
    'Revenue' AS opportunity_area,
    'Focus on high-revenue products and categories' AS finding

UNION ALL

SELECT
    'Returns',
    CONCAT(
        'Returned product value = $',
        ROUND(SUM(r.quantity_returned * p.unit_price), 2)
    )
FROM returns r
JOIN products p
    ON r.product_id = p.product_id

UNION ALL

SELECT
    'Payments',
    CONCAT(
        'Pending payment value = $',
        ROUND(SUM(amount), 2)
    )
FROM payments
WHERE payment_status = 'Pending'

UNION ALL

SELECT
    'Customers',
    'Retain high-value customers who have not purchased recently'

UNION ALL

SELECT
    'Profitability',
    'Prioritize products with strong revenue and profit contribution';


-- END--












































