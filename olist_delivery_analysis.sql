CREATE DATABASE IF NOT EXISTS olist_analytics;

USE olist_analytics;

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS unique_orders,
    SUM(order_id IS NULL) AS missing_order_ids,
    SUM(order_delivered_customer_date IS NULL) AS missing_delivery_dates
FROM olist_orders_dataset;

SELECT
    order_status,
    COUNT(*) AS total_orders,
    SUM(order_delivered_customer_date = '') AS blank_delivery_dates
FROM olist_orders_dataset
GROUP BY order_status
ORDER BY total_orders DESC;

SELECT
    COUNT(*) AS delivered_orders,

    SUM(
        order_delivered_customer_date >
        order_estimated_delivery_date
    ) AS late_orders,

    ROUND(
        100.0 * SUM(
            order_delivered_customer_date >
            order_estimated_delivery_date
        ) / COUNT(*),
        2
    ) AS late_delivery_rate_pct,

    ROUND(
        AVG(
            CASE
                WHEN order_delivered_customer_date >
                     order_estimated_delivery_date
                THEN TIMESTAMPDIFF(
                    HOUR,
                    order_estimated_delivery_date,
                    order_delivered_customer_date
                ) / 24.0
            END
        ),
        2
    ) AS avg_days_late

FROM olist_orders_dataset

WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_delivered_customer_date <> ''
  AND order_estimated_delivery_date IS NOT NULL
  AND order_estimated_delivery_date <> '';
 
 
-- Business question: Is late delivery performance improving or deteriorating?
-- Analytical skill: Trend analysis

  WITH monthly_delivery AS (
    SELECT
        DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS purchase_month,
        COUNT(*) AS delivered_orders,
        SUM(
            order_delivered_customer_date >
            order_estimated_delivery_date
        ) AS late_orders
    FROM olist_orders_dataset
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date <> ''
      AND order_estimated_delivery_date <> ''
    GROUP BY DATE_FORMAT(order_purchase_timestamp, '%Y-%m')
)
SELECT
    purchase_month,
    delivered_orders,
    late_orders,
    ROUND(100.0 * late_orders / delivered_orders, 2)
        AS late_delivery_rate_pct
FROM monthly_delivery
ORDER BY purchase_month;
  
  SHOW TABLES FROM olist_analytics;
  
  SELECT
    COUNT(*) AS total_reviews,
    COUNT(DISTINCT order_id) AS unique_reviewed_orders,
    MIN(review_score) AS lowest_score,
    MAX(review_score) AS highest_score
FROM olist_order_reviews_dataset;

SHOW CREATE TABLE olist_order_reviews_dataset;
SELECT
    COUNT(*) AS total_reviews,
    COUNT(DISTINCT order_id) AS unique_reviewed_orders
FROM olist_order_reviews_dataset;

-- Business question:
-- Are late deliveries associated with lower customer satisfaction?

WITH reviews_per_order AS (
    SELECT
        order_id,
        AVG(review_score) AS avg_review_score
    FROM olist_order_reviews_dataset
    GROUP BY order_id
),

delivery_reviews AS (
    SELECT
        o.order_id,
        CASE
            WHEN o.order_delivered_customer_date >
                 o.order_estimated_delivery_date
            THEN 'Late'
            ELSE 'On Time'
        END AS delivery_status,
        r.avg_review_score

    FROM olist_orders_dataset o

    INNER JOIN reviews_per_order r
        ON o.order_id = r.order_id

    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date <> ''
      AND o.order_estimated_delivery_date <> ''
)

SELECT
    delivery_status,
    COUNT(*) AS reviewed_orders,
    ROUND(AVG(avg_review_score), 2) AS avg_review_score,
    ROUND(
        100.0 * AVG(avg_review_score <= 2),
        2
    ) AS low_review_rate_pct
FROM delivery_reviews
GROUP BY delivery_status;

-- Business question:
-- How does the length of a delivery delay relate to review scores?
-- Analytical skill: Segmentation and severity analysis

WITH reviews_per_order AS (
    SELECT
        order_id,
        AVG(review_score) AS avg_review_score
    FROM olist_order_reviews_dataset
    GROUP BY order_id
),

delivery_analysis AS (
    SELECT
        o.order_id,
        DATEDIFF(
            o.order_delivered_customer_date,
            o.order_estimated_delivery_date
        ) AS days_after_estimate,
        r.avg_review_score
    FROM olist_orders_dataset o
    INNER JOIN reviews_per_order r
        ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date <> ''
      AND o.order_estimated_delivery_date <> ''
)

SELECT
    CASE
        WHEN days_after_estimate <= 0 THEN 'On time / early'
        WHEN days_after_estimate BETWEEN 1 AND 3 THEN '1–3 days late'
        WHEN days_after_estimate BETWEEN 4 AND 7 THEN '4–7 days late'
        WHEN days_after_estimate BETWEEN 8 AND 14 THEN '8–14 days late'
        ELSE '15+ days late'
    END AS delay_group,

    COUNT(*) AS reviewed_orders,
    ROUND(AVG(avg_review_score), 2) AS avg_review_score,
    ROUND(100.0 * AVG(avg_review_score <= 2), 2)
        AS low_review_rate_pct

FROM delivery_analysis
GROUP BY delay_group
ORDER BY
    CASE delay_group
        WHEN 'On time / early' THEN 1
        WHEN '1–3 days late' THEN 2
        WHEN '4–7 days late' THEN 3
        WHEN '8–14 days late' THEN 4
        ELSE 5
    END;
    
    SELECT
    COUNT(*) AS total_items,
    COUNT(DISTINCT order_id) AS unique_orders,
    COUNT(DISTINCT seller_id) AS unique_sellers
FROM olist_order_items_dataset;

-- Business question:
-- Which sellers should operations investigate first?
-- Analytical skill: Seller benchmarking and window functions

WITH order_sellers AS (
    -- One row per order, identifying single-seller orders
    SELECT
        order_id,
        MIN(seller_id) AS seller_id,
        COUNT(DISTINCT seller_id) AS seller_count
    FROM olist_order_items_dataset
    GROUP BY order_id
),

seller_performance AS (
    SELECT
        os.seller_id,
        COUNT(*) AS delivered_orders,
        SUM(
            o.order_delivered_customer_date >
            o.order_estimated_delivery_date
        ) AS late_orders
    FROM olist_orders_dataset o
    INNER JOIN order_sellers os
        ON o.order_id = os.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date <> ''
      AND o.order_estimated_delivery_date <> ''
      AND os.seller_count = 1
    GROUP BY os.seller_id
),

seller_metrics AS (
    SELECT
        seller_id,
        delivered_orders,
        late_orders,
        ROUND(
            100.0 * late_orders / delivered_orders,
            2
        ) AS late_delivery_rate_pct
    FROM seller_performance
    WHERE delivered_orders >= 30
)

SELECT
    seller_id,
    delivered_orders,
    late_orders,
    late_delivery_rate_pct,

    RANK() OVER (
        ORDER BY late_delivery_rate_pct DESC
    ) AS late_rate_rank,

    RANK() OVER (
        ORDER BY late_orders DESC
    ) AS late_volume_rank

FROM seller_metrics
ORDER BY late_orders DESC
LIMIT 10;

-- Business question:
-- Which high-volume sellers perform worse than the relevant benchmark?
-- Analytical skill: Benchmarking and window functions

WITH order_sellers AS (
    SELECT
        order_id,
        MIN(seller_id) AS seller_id,
        COUNT(DISTINCT seller_id) AS seller_count
    FROM olist_order_items_dataset
    GROUP BY order_id
),

seller_performance AS (
    SELECT
        os.seller_id,
        COUNT(*) AS delivered_orders,
        SUM(
            o.order_delivered_customer_date >
            o.order_estimated_delivery_date
        ) AS late_orders
    FROM olist_orders_dataset o
    INNER JOIN order_sellers os
        ON o.order_id = os.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date <> ''
      AND o.order_estimated_delivery_date <> ''
      AND os.seller_count = 1
    GROUP BY os.seller_id
),

seller_benchmarks AS (
    SELECT
        seller_id,
        delivered_orders,
        late_orders,

        ROUND(
            100.0 * late_orders / delivered_orders, 2
        ) AS seller_late_rate_pct,

        ROUND(
            100.0 * SUM(late_orders) OVER ()
            / SUM(delivered_orders) OVER (), 2
        ) AS overall_late_rate_pct

    FROM seller_performance
)

SELECT
    seller_id,
    delivered_orders,
    late_orders,
    seller_late_rate_pct,
    overall_late_rate_pct,

    ROUND(
        seller_late_rate_pct - overall_late_rate_pct, 2
    ) AS gap_vs_benchmark_pp

FROM seller_benchmarks
WHERE delivered_orders >= 100
ORDER BY late_orders DESC
LIMIT 10;

-- Business question:
-- Are seller performance findings robust to sample-size thresholds?
-- Analytical skill: Sensitivity analysis

WITH order_sellers AS (
    SELECT
        order_id,
        MIN(seller_id) AS seller_id,
        COUNT(DISTINCT seller_id) AS seller_count
    FROM olist_order_items_dataset
    GROUP BY order_id
),

seller_performance AS (
    SELECT
        os.seller_id,
        COUNT(*) AS delivered_orders,
        SUM(
            o.order_delivered_customer_date >
            o.order_estimated_delivery_date
        ) AS late_orders
    FROM olist_orders_dataset o
    INNER JOIN order_sellers os
        ON o.order_id = os.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date <> ''
      AND o.order_estimated_delivery_date <> ''
      AND os.seller_count = 1
    GROUP BY os.seller_id
),

ranked_sellers AS (
    SELECT
        seller_id,
        delivered_orders,
        late_orders,
        ROUND(100.0 * late_orders / delivered_orders, 2)
            AS late_rate_pct
    FROM seller_performance
)

SELECT
    CASE
        WHEN delivered_orders >= 300 THEN '300+ orders'
        WHEN delivered_orders >= 100 THEN '100–299 orders'
        WHEN delivered_orders >= 30 THEN '30–99 orders'
        ELSE 'Under 30 orders'
    END AS seller_volume_group,

    COUNT(*) AS seller_count,
    SUM(delivered_orders) AS delivered_orders,
    SUM(late_orders) AS late_orders,

    ROUND(
        100.0 * SUM(late_orders) / SUM(delivered_orders),
        2
    ) AS late_rate_pct

FROM ranked_sellers
GROUP BY seller_volume_group
ORDER BY
    CASE seller_volume_group
        WHEN '300+ orders' THEN 1
        WHEN '100–299 orders' THEN 2
        WHEN '30–99 orders' THEN 3
        ELSE 4
    END;
    
    -- Business question:
-- Do our delivery KPIs reconcile across the analysis?
-- Analytical skill: Metric validation

WITH valid_deliveries AS (
    SELECT
        order_id,
        CASE
            WHEN order_delivered_customer_date >
                 order_estimated_delivery_date
            THEN 1
            ELSE 0
        END AS is_late
    FROM olist_orders_dataset
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date <> ''
      AND order_estimated_delivery_date <> ''
)

SELECT
    COUNT(*) AS valid_delivered_orders,
    SUM(is_late) AS late_orders,
    COUNT(*) - SUM(is_late) AS on_time_orders,
    ROUND(100.0 * AVG(is_late), 2) AS late_rate_pct
FROM valid_deliveries;
-- Create an order-level dataset for Tableau
-- Analytical skill: Data modelling and dashboard preparation

CREATE OR REPLACE VIEW olist_tableau_delivery AS

WITH reviews_per_order AS (
    SELECT
        order_id,
        AVG(review_score) AS avg_review_score
    FROM olist_order_reviews_dataset
    GROUP BY order_id
),

order_sellers AS (
    SELECT
        order_id,
        MIN(seller_id) AS seller_id,
        COUNT(DISTINCT seller_id) AS seller_count
    FROM olist_order_items_dataset
    GROUP BY order_id
)

SELECT
    o.order_id,
    o.order_purchase_timestamp,
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS purchase_month,
    o.order_estimated_delivery_date,
    o.order_delivered_customer_date,

    CASE
        WHEN o.order_delivered_customer_date >
             o.order_estimated_delivery_date
        THEN 1 ELSE 0
    END AS is_late,

    CASE
        WHEN o.order_delivered_customer_date >
             o.order_estimated_delivery_date
        THEN 'Late'
        ELSE 'On Time'
    END AS delivery_status,

    TIMESTAMPDIFF(
        HOUR,
        o.order_estimated_delivery_date,
        o.order_delivered_customer_date
    ) / 24.0 AS days_vs_estimate,

    CASE
        WHEN o.order_delivered_customer_date <=
             o.order_estimated_delivery_date
        THEN 'On time / early'
        WHEN TIMESTAMPDIFF(
            HOUR,
            o.order_estimated_delivery_date,
            o.order_delivered_customer_date
        ) <= 72 THEN '1–3 days late'
        WHEN TIMESTAMPDIFF(
            HOUR,
            o.order_estimated_delivery_date,
            o.order_delivered_customer_date
        ) <= 168 THEN '4–7 days late'
        WHEN TIMESTAMPDIFF(
            HOUR,
            o.order_estimated_delivery_date,
            o.order_delivered_customer_date
        ) <= 336 THEN '8–14 days late'
        ELSE '15+ days late'
    END AS delay_group,

    r.avg_review_score,
    os.seller_id,
    os.seller_count

FROM olist_orders_dataset o

LEFT JOIN reviews_per_order r
    ON o.order_id = r.order_id

LEFT JOIN order_sellers os
    ON o.order_id = os.order_id

WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date <> ''
  AND o.order_estimated_delivery_date <> '';
  
  SELECT
    COUNT(*) AS total_orders,
    COUNT(DISTINCT order_id) AS unique_orders,
    SUM(is_late) AS late_orders,
    ROUND(100.0 * AVG(is_late), 2) AS late_rate_pct,
    SUM(avg_review_score IS NOT NULL) AS orders_with_reviews
FROM olist_tableau_delivery;

SELECT *
FROM olist_tableau_delivery;