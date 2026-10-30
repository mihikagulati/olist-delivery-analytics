# Olist E-commerce Delivery Performance & Customer Experience Analytics

## Project Overview

Analyzed historical Brazilian e-commerce transactions to understand delivery performance, its relationship with customer satisfaction, and seller-level operational differences.

Tools: MySQL, Python (Pandas, SQLAlchemy), Tableau

Dataset: Brazilian E-Commerce Public Dataset by Olist (Kaggle)

## Business Questions

1. What percentage of delivered orders arrive late?
2. How does delivery performance change over time?
3. How are delivery delays associated with customer review scores?
4. Which sellers have high late-delivery rates and significant order volumes?

## Key Findings

| Metric | Result |
|---|---|
| Valid delivered orders | 96,470 |
| Late deliveries | 7,826 |
| Overall late-delivery rate | 8.11% |
| Average delay among late orders | 9.53 days |
| Average review score — on time | 4.29 / 5 |
| Average review score — late | 2.57 / 5 |
| Low-review rate — on time | 9.19% |
| Low-review rate — late | 53.99% |

### Business Insights

1. Delivery performance varies substantially by month.

March 2018 recorded a late-delivery rate of approximately 21.36%, compared with 8.11% overall.

2. Late delivery is strongly associated with lower customer satisfaction.

Late orders received substantially lower review scores. This is an observed association, not proof that delays caused the lower scores.

3. Delay severity matters.

Customer review scores generally decline as delivery delays become longer.

4. Seller performance varies.

The late-delivery benchmark for single-seller orders was 8.20%. Some high-volume sellers exceeded this rate, highlighting opportunities for further operational investigation.

## Methodology

- Validated source-table row counts and order uniqueness.
- Excluded delivered orders with missing delivery timestamps.
- Defined late delivery using actual versus estimated delivery timestamps.
- Aggregated reviews to one record per order to avoid duplication.
- Aggregated seller relationships at order level.
- Restricted seller comparisons to single-seller orders.
- Created a validated, order-level SQL view for Tableau.
- Developed an interactive dashboard showing delivery KPIs, monthly trends, review-score patterns, and seller benchmarking.

## Recommendations

1. Investigate high-delay months and potential operational disruptions.
2. Prioritize high-volume, above-benchmark sellers for deeper review.
3. Monitor severely delayed orders as a customer-experience risk.
4. Examine geography, carrier performance, and product characteristics before attributing delays to sellers.

## Limitations

- Historical data from 2016–2018 may not represent current operations.
- Correlation does not establish causation.
- Seller associations do not prove seller responsibility for delays.
- Review scores are averaged when multiple review records exist for an order.
- Very low-volume months can produce unstable rates.

## Tableau Dashboard

Interactive dashboard: [View on Tableau Public](https://public.tableau.com/app/profile/mihika.gulati/viz/OlistDeliveryPerformanceandCustomerExperience/OlistDeliveryPerformanceCustomerExperience?publish=yes)

## Data Source

[Olist Brazilian E-Commerce Public Dataset — Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)