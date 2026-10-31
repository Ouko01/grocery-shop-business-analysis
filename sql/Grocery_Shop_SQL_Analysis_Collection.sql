/*
PROJECT: Real-world Grocery Shop Transaction & Business Performance Analysis
DATABASE: grocery_shop_full_analysis
TABLE: grocery_transactions_full

HOW TO USE
1. Open MySQL Workbench and connect to your MySQL server.
2. Open this .sql file or paste its contents into a new SQL tab.
3. Select the database with USE below.
4. Run each section separately and review the result before moving on.
5. Save your own copy in MySQL Workbench (File > Save Script As).

NOTES
- This script is reconstructed from the analyses and results retained in our project context;
  it may not reproduce every original unsaved query word-for-word.
- The source date field is text in MM/DD/YYYY format, so queries parse it with STR_TO_DATE.
- Most queries are read-only. The final section creates/replaces a SQL VIEW, not the source table.
-- REQUIREMENT: MySQL 8.0 or later.
*/

USE grocery_shop_full_analysis;

/* ================================================================
   SECTION 1 — BASIC DATASET PROFILE AND VALIDATION
   ================================================================ */

-- 1.1 Confirm the source table record count
SELECT
    COUNT(*) AS total_records
FROM grocery_transactions_full;

-- 1.2 Overall record count, date range, category count, and monetary totals
-- Note: Net difference represents the difference between
-- recorded money in and money out. It is not business profit.
SELECT
    COUNT(*) AS total_records,
    MIN(STR_TO_DATE(`Transaction Date`, '%m/%d/%Y')) AS first_transaction_date,
    MAX(STR_TO_DATE(`Transaction Date`, '%m/%d/%Y')) AS last_transaction_date,
    COUNT(DISTINCT `Transaction Category`) AS number_of_categories,
    SUM(`Paid In (KES)`) AS total_paid_in,
    SUM(`Withdrawn (KES)`) AS total_withdrawn,
    SUM(`Paid In (KES)`) - SUM(`Withdrawn (KES)`) AS net_difference
FROM grocery_transactions_full;

-- 1.3 Counts and money totals by category
SELECT
    `Transaction Category` AS transaction_category,
    COUNT(*) AS number_of_transactions,
    SUM(`Paid In (KES)`) AS total_paid_in,
    SUM(`Withdrawn (KES)`) AS total_withdrawn
FROM grocery_transactions_full
GROUP BY `Transaction Category`
ORDER BY number_of_transactions DESC;

-- 1.4 Distinct description count by category
SELECT
    `Transaction Category` AS transaction_category,
    COUNT(DISTINCT `Details`) AS unique_descriptions,
    COUNT(*) AS total_records
FROM grocery_transactions_full
GROUP BY `Transaction Category`
ORDER BY transaction_category;


/* ================================================================
   SECTION 2 — BASIC CUSTOMER-SALES KPIs
   ================================================================ */

-- 2.1 Total customer-sale transactions and sales value
SELECT
    COUNT(*) AS customer_sale_transactions,
    SUM(`Paid In (KES)`) AS total_customer_sales,
    AVG(`Paid In (KES)`) AS average_customer_sale_value,
    MIN(STR_TO_DATE(`Transaction Date`, '%m/%d/%Y')) AS first_sale_date,
    MAX(STR_TO_DATE(`Transaction Date`, '%m/%d/%Y')) AS last_sale_date
FROM grocery_transactions_full
WHERE `Transaction Category` = 'Customer Sale';

-- 2.2 Monthly customer sales
SELECT
    YEAR(STR_TO_DATE(`Transaction Date`, '%m/%d/%Y')) AS year,
    MONTH(STR_TO_DATE(`Transaction Date`, '%m/%d/%Y')) AS month,
    DATE_FORMAT(STR_TO_DATE(`Transaction Date`, '%m/%d/%Y'), '%Y-%m') AS year_month,
    COUNT(*) AS number_of_transactions,
    SUM(`Paid In (KES)`) AS customer_sales,
    ROUND(AVG(`Paid In (KES)`), 2) AS average_transaction_value
FROM grocery_transactions_full
WHERE `Transaction Category` = 'Customer Sale'
GROUP BY
    YEAR(STR_TO_DATE(`Transaction Date`, '%m/%d/%Y')),
    MONTH(STR_TO_DATE(`Transaction Date`, '%m/%d/%Y')),
    DATE_FORMAT(STR_TO_DATE(`Transaction Date`, '%m/%d/%Y'), '%Y-%m')
ORDER BY year, month;

-- 2.3 Yearly customer sales, transaction volume, and average transaction value
SELECT
    YEAR(STR_TO_DATE(`Transaction Date`, '%m/%d/%Y')) AS year,
    COUNT(*) AS number_of_transactions,
    SUM(`Paid In (KES)`) AS customer_sales,
    ROUND(AVG(`Paid In (KES)`), 2) AS average_transaction_value
FROM grocery_transactions_full
WHERE `Transaction Category` = 'Customer Sale'
GROUP BY YEAR(STR_TO_DATE(`Transaction Date`, '%m/%d/%Y'))
ORDER BY year;

-- 2.4 Monthly sales average across the observed months
/*
ANALYTICAL NOTE:
The original calculation included 37 observed months,
including partial August 2023 and August 2026.

The revised calculation excludes these two boundary
months and uses 35 complete calendar months.

Average monthly customer sales across complete months:
KES 18,600.97.
-- Limitation: Months with no Customer Sale records would not
-- appear in monthly_data and would therefore be excluded
-- from this average.
*/
WITH parsed_transactions AS (
    SELECT
        STR_TO_DATE(`Transaction Date`, '%m/%d/%Y') AS transaction_date,
        `Paid In (KES)` AS paid_in,
        `Transaction Category` AS transaction_category
    FROM grocery_transactions_full
),

source_coverage AS (
    SELECT
        MIN(transaction_date) AS first_date,
        MAX(transaction_date) AS last_date
    FROM parsed_transactions
),

monthly_data AS (
    SELECT
        CAST(DATE_FORMAT(transaction_date, '%Y-%m-01') AS DATE) AS month_start,
        SUM(paid_in) AS customer_sales
    FROM parsed_transactions
    WHERE transaction_category = 'Customer Sale'
    GROUP BY CAST(DATE_FORMAT(transaction_date, '%Y-%m-01') AS DATE)
),

complete_months AS (
    SELECT
        m.month_start,
        m.customer_sales
    FROM monthly_data m
    CROSS JOIN source_coverage s
    WHERE
        m.month_start > CAST(DATE_FORMAT(s.first_date, '%Y-%m-01') AS DATE)
        AND
        m.month_start < CAST(DATE_FORMAT(s.last_date, '%Y-%m-01') AS DATE)
)

SELECT
    ROUND(AVG(customer_sales), 2) AS average_monthly_customer_sales,
    COUNT(*) AS complete_months
FROM complete_months;

/* ================================================================
   SECTION 3 — MONTHLY RANKING AND PERFORMANCE COMPARISONS
   ================================================================ */

-- 3.1 Top 3 sales months in each year (ROW_NUMBER)
WITH monthly_data AS (
    SELECT
        YEAR(STR_TO_DATE(`Transaction Date`, '%m/%d/%Y')) AS year,
        MONTH(STR_TO_DATE(`Transaction Date`, '%m/%d/%Y')) AS month,
        SUM(`Paid In (KES)`) AS customer_sales
    FROM grocery_transactions_full
    WHERE `Transaction Category` = 'Customer Sale'
    GROUP BY
        YEAR(STR_TO_DATE(`Transaction Date`, '%m/%d/%Y')),
        MONTH(STR_TO_DATE(`Transaction Date`, '%m/%d/%Y'))
),
ranked_data AS (
    SELECT
        year,
        month,
        customer_sales,
        ROW_NUMBER() OVER (
            PARTITION BY year
            ORDER BY customer_sales DESC
        ) AS ranked_month
    FROM monthly_data
)
SELECT year, month, customer_sales, ranked_month
FROM ranked_data
WHERE ranked_month <= 3
ORDER BY year, ranked_month;

-- 3.2 Rank all months within each year (RANK preserves ties)
WITH monthly_data AS (
    SELECT
        YEAR(STR_TO_DATE(`Transaction Date`, '%m/%d/%Y')) AS year,
        MONTH(STR_TO_DATE(`Transaction Date`, '%m/%d/%Y')) AS month,
        SUM(`Paid In (KES)`) AS customer_sales
    FROM grocery_transactions_full
    WHERE `Transaction Category` = 'Customer Sale'
    GROUP BY
        YEAR(STR_TO_DATE(`Transaction Date`, '%m/%d/%Y')),
        MONTH(STR_TO_DATE(`Transaction Date`, '%m/%d/%Y'))
)
SELECT
    year,
    month,
    customer_sales,
    RANK() OVER (
        PARTITION BY year
        ORDER BY customer_sales DESC
    ) AS sales_rank
FROM monthly_data
ORDER BY year, sales_rank;

-- 3.3 Compare each month with the previous month within the same year (LAG)
-- The first observed month in each year has no previous-month comparison.
WITH monthly_data AS (
    SELECT
        YEAR(STR_TO_DATE(`Transaction Date`, '%m/%d/%Y')) AS year,
        MONTH(STR_TO_DATE(`Transaction Date`, '%m/%d/%Y')) AS month,
        SUM(`Paid In (KES)`) AS customer_sales
    FROM grocery_transactions_full
    WHERE `Transaction Category` = 'Customer Sale'
    GROUP BY
        YEAR(STR_TO_DATE(`Transaction Date`, '%m/%d/%Y')),
        MONTH(STR_TO_DATE(`Transaction Date`, '%m/%d/%Y'))
),
monthly_change AS (
    SELECT
        year,
        month,
        customer_sales,
        LAG(customer_sales) OVER (
            PARTITION BY year
            ORDER BY month
        ) AS previous_month_sales
    FROM monthly_data
)
SELECT
    year,
    month,
    customer_sales,
    previous_month_sales,
    customer_sales - previous_month_sales AS absolute_change,
    ROUND(
        100.0 * (customer_sales - previous_month_sales) / NULLIF(previous_month_sales, 0),
        2
    ) AS percentage_change
FROM monthly_change
ORDER BY year, month;

-- 3.4 Largest increase and largest decrease in monthly sales by year
-- Uses month-to-month comparisons within each year.
WITH monthly_data AS (
    SELECT
        YEAR(STR_TO_DATE(`Transaction Date`, '%m/%d/%Y')) AS year,
        MONTH(STR_TO_DATE(`Transaction Date`, '%m/%d/%Y')) AS month,
        SUM(`Paid In (KES)`) AS customer_sales
    FROM grocery_transactions_full
    WHERE `Transaction Category` = 'Customer Sale'
    GROUP BY
        YEAR(STR_TO_DATE(`Transaction Date`, '%m/%d/%Y')),
        MONTH(STR_TO_DATE(`Transaction Date`, '%m/%d/%Y'))
),
monthly_change AS (
    SELECT
        year,
        month,
        customer_sales,
        LAG(customer_sales) OVER (PARTITION BY year ORDER BY month) AS previous_month_sales
    FROM monthly_data
),
changes AS (
    SELECT
        year,
        month,
        customer_sales,
        previous_month_sales,
        customer_sales - previous_month_sales AS absolute_change
    FROM monthly_change
    WHERE previous_month_sales IS NOT NULL
)
SELECT
    year,
    ROUND(AVG(ABS(absolute_change)), 2) AS average_absolute_monthly_change,
    MAX(absolute_change) AS largest_increase,
    MIN(absolute_change) AS largest_decrease
FROM changes
GROUP BY year
ORDER BY year;

-- 3.5 Compare each complete month's sales with that year's average monthly sales
-- Partial boundary months are excluded.

WITH parsed_transactions AS (
    SELECT
        STR_TO_DATE(`Transaction Date`, '%m/%d/%Y') AS transaction_date,
        `Paid In (KES)` AS paid_in,
        `Transaction Category` AS transaction_category
    FROM grocery_transactions_full
),
source_coverage AS (
    SELECT
        MIN(transaction_date) AS first_date,
        MAX(transaction_date) AS last_date
    FROM parsed_transactions
),
monthly_data AS (
    SELECT
        YEAR(transaction_date) AS year,
        MONTH(transaction_date) AS month,
        SUM(
            CASE
                WHEN transaction_category = 'Customer Sale'
                    THEN paid_in
                ELSE 0
            END
        ) AS customer_sales,
        CAST(DATE_FORMAT(transaction_date, '%Y-%m-01') AS DATE) AS month_start
    FROM parsed_transactions
    GROUP BY
        YEAR(transaction_date),
        MONTH(transaction_date),
        CAST(DATE_FORMAT(transaction_date, '%Y-%m-01') AS DATE)
),
complete_months AS (
    SELECT m.*
    FROM monthly_data m
    CROSS JOIN source_coverage s
    WHERE m.month_start > CAST(DATE_FORMAT(s.first_date, '%Y-%m-01') AS DATE)
      AND m.month_start < CAST(DATE_FORMAT(s.last_date, '%Y-%m-01') AS DATE)
),
average_data AS (
    SELECT
        year,
        month,
        customer_sales,
        AVG(customer_sales) OVER (PARTITION BY year) AS yearly_average_sales
    FROM complete_months
)
SELECT
    year,
    month,
    customer_sales,
    ROUND(yearly_average_sales, 2) AS yearly_average_sales,
    CASE
        WHEN customer_sales > yearly_average_sales THEN 1
        ELSE 0
    END AS above_average
FROM average_data
ORDER BY year, month;


-- 3.6 Average monthly sales and population standard deviation by year
-- Uses complete calendar months only.

WITH parsed_transactions AS (
    SELECT
        STR_TO_DATE(`Transaction Date`, '%m/%d/%Y') AS transaction_date,
        `Paid In (KES)` AS paid_in,
        `Transaction Category` AS transaction_category
    FROM grocery_transactions_full
),
source_coverage AS (
    SELECT
        MIN(transaction_date) AS first_date,
        MAX(transaction_date) AS last_date
    FROM parsed_transactions
),
monthly_data AS (
    SELECT
        YEAR(transaction_date) AS year,
        CAST(DATE_FORMAT(transaction_date, '%Y-%m-01') AS DATE) AS month_start,
        SUM(
            CASE
                WHEN transaction_category = 'Customer Sale'
                    THEN paid_in
                ELSE 0
            END
        ) AS customer_sales
    FROM parsed_transactions
    GROUP BY
        YEAR(transaction_date),
        CAST(DATE_FORMAT(transaction_date, '%Y-%m-01') AS DATE)
),
complete_months AS (
    SELECT m.*
    FROM monthly_data m
    CROSS JOIN source_coverage s
    WHERE m.month_start > CAST(DATE_FORMAT(s.first_date, '%Y-%m-01') AS DATE)
      AND m.month_start < CAST(DATE_FORMAT(s.last_date, '%Y-%m-01') AS DATE)
)
SELECT
    year,
    ROUND(AVG(customer_sales), 2) AS avg_monthly_sales,
    ROUND(STDDEV_POP(customer_sales), 2) AS population_std_dev,
    COUNT(*) AS complete_months
FROM complete_months
GROUP BY year
ORDER BY year;

-- 3.7 Each month's share of that year's customer sales
WITH monthly_data AS (
    SELECT
        YEAR(STR_TO_DATE(`Transaction Date`, '%m/%d/%Y')) AS year,
        MONTH(STR_TO_DATE(`Transaction Date`, '%m/%d/%Y')) AS month,
        SUM(`Paid In (KES)`) AS monthly_sales
    FROM grocery_transactions_full
    WHERE `Transaction Category` = 'Customer Sale'
    GROUP BY
        YEAR(STR_TO_DATE(`Transaction Date`, '%m/%d/%Y')),
        MONTH(STR_TO_DATE(`Transaction Date`, '%m/%d/%Y'))
),
yearly_share AS (
    SELECT
        year,
        month,
        monthly_sales,
        SUM(monthly_sales) OVER (PARTITION BY year) AS yearly_sales
    FROM monthly_data
)
SELECT
    year,
    month,
    monthly_sales,
    yearly_sales,
    ROUND(100.0 * monthly_sales / NULLIF(yearly_sales, 0), 2) AS percentage_of_yearly_sales
FROM yearly_share
ORDER BY year, month;

-- 3.8 Yearly customer-sales contribution to all years in the dataset
WITH yearly_data AS (
    SELECT
        YEAR(STR_TO_DATE(`Transaction Date`, '%m/%d/%Y')) AS year,
        SUM(`Paid In (KES)`) AS yearly_customer_sales
    FROM grocery_transactions_full
    WHERE `Transaction Category` = 'Customer Sale'
    GROUP BY YEAR(STR_TO_DATE(`Transaction Date`, '%m/%d/%Y'))
)
SELECT
    year,
    yearly_customer_sales,
    ROUND(
        100.0 * yearly_customer_sales / SUM(yearly_customer_sales) OVER (),
        2
    ) AS contribution_percentage
FROM yearly_data
ORDER BY year;

-- 3.9 Year-over-year customer-sales growth
-- For this dataset, calculate year-over-year growth only
-- for the comparable full calendar years 2024 and 2025.
-- Partial years are excluded from the growth calculation.

WITH yearly_sales AS (
    SELECT
        YEAR(STR_TO_DATE(`Transaction Date`, '%m/%d/%Y')) AS sales_year,
        SUM(`Paid In (KES)`) AS yearly_customer_sales
    FROM grocery_transactions_full
    WHERE `Transaction Category` = 'Customer Sale'
    GROUP BY YEAR(STR_TO_DATE(`Transaction Date`, '%m/%d/%Y'))
),

yearly_comparison AS (
    SELECT
        sales_year,
        yearly_customer_sales,
        LAG(yearly_customer_sales) OVER (
            ORDER BY sales_year
        ) AS previous_year_sales
    FROM yearly_sales
)

SELECT
    sales_year,
    yearly_customer_sales,
    previous_year_sales,

    CASE
        WHEN sales_year = 2025
        THEN yearly_customer_sales - previous_year_sales
        ELSE NULL
    END AS absolute_growth_kes,

    CASE
        WHEN sales_year = 2025
             AND previous_year_sales IS NOT NULL
             AND previous_year_sales <> 0
        THEN ROUND(
            ((yearly_customer_sales - previous_year_sales)
            / previous_year_sales) * 100, 2
        )
        ELSE NULL
    END AS percentage_growth,

    CASE
        WHEN sales_year = 2025
        THEN 'Comparable full-year comparison'
        WHEN sales_year = 2024
        THEN 'Previous year is incomplete'
        WHEN sales_year = 2026
        THEN 'Current year is incomplete'
        ELSE 'Partial year - not comparable'
    END AS comparison_status

FROM yearly_comparison
ORDER BY sales_year;

/* ================================================================
   SECTION 4 — DATA QUALITY CHECKS
   ================================================================ */

-- 4.1 Missing or blank values in key fields
SELECT
    SUM(CASE WHEN `Receipt No.` IS NULL OR TRIM(`Receipt No.`) = '' THEN 1 ELSE 0 END) AS missing_receipt_no,
    SUM(CASE WHEN `Transaction Date` IS NULL OR TRIM(`Transaction Date`) = '' THEN 1 ELSE 0 END) AS missing_transaction_date,
    SUM(CASE WHEN `Paid In (KES)` IS NULL THEN 1 ELSE 0 END) AS missing_paid_in,
    SUM(CASE WHEN `Withdrawn (KES)` IS NULL THEN 1 ELSE 0 END) AS missing_withdrawn,
    SUM(CASE WHEN `Transaction Category` IS NULL OR TRIM(`Transaction Category`) = '' THEN 1 ELSE 0 END) AS missing_category,
    SUM(CASE WHEN `Details` IS NULL OR TRIM(`Details`) = '' THEN 1 ELSE 0 END) AS missing_details
FROM grocery_transactions_full;

-- 4.2 Negative monetary amounts
SELECT
    SUM(CASE WHEN `Paid In (KES)` < 0 THEN 1 ELSE 0 END) AS negative_paid_in_records,
    SUM(CASE WHEN `Withdrawn (KES)` < 0 THEN 1 ELSE 0 END) AS negative_withdrawn_records
FROM grocery_transactions_full;

-- 4.3 Count records with zero values in both monetary fields
-- Aggregate results only; no individual transaction details exposed.

SELECT
    `Transaction Category` AS transaction_category,
    COUNT(*) AS both_zero_records
FROM grocery_transactions_full
WHERE `Paid In (KES)` = 0
  AND `Withdrawn (KES)` = 0
GROUP BY `Transaction Category`
ORDER BY both_zero_records DESC;

-- 4.4 Counts of zero amounts
SELECT
    SUM(CASE WHEN `Paid In (KES)` = 0 THEN 1 ELSE 0 END) AS zero_paid_in_records,
    SUM(CASE WHEN `Withdrawn (KES)` = 0 THEN 1 ELSE 0 END) AS zero_withdrawn_records,
    SUM(CASE WHEN `Paid In (KES)` = 0 AND `Withdrawn (KES)` = 0 THEN 1 ELSE 0 END) AS both_zero_records
FROM grocery_transactions_full;

-- 4.5 Count repeated receipt numbers
-- A repeated receipt number is not automatically a duplicate.

SELECT
    COUNT(*) AS repeated_receipt_groups,
    SUM(number_of_rows) AS records_in_repeated_groups
FROM (
    SELECT
        `Receipt No.`,
        COUNT(*) AS number_of_rows
    FROM grocery_transactions_full
    GROUP BY `Receipt No.`
    HAVING COUNT(*) > 1
) AS repeated_receipts;


-- 4.6 Count exact repeated combinations of receipt, details,
-- amounts, and category without exposing transaction details.

SELECT
    COUNT(*) AS duplicated_combinations,
    COALESCE(SUM(repeated_count), 0) AS records_in_duplicated_combinations
FROM (
    SELECT
        COUNT(*) AS repeated_count
    FROM grocery_transactions_full
    GROUP BY
        `Receipt No.`,
        `Details`,
        `Paid In (KES)`,
        `Withdrawn (KES)`,
        `Transaction Category`
    HAVING COUNT(*) > 1
) AS duplicate_groups;

-- 4.7 Check date parsing failures
SELECT
    COUNT(*) AS rows_with_unparsed_dates
FROM grocery_transactions_full
WHERE `Transaction Date` IS NOT NULL
  AND TRIM(`Transaction Date`) <> ''
  AND STR_TO_DATE(`Transaction Date`, '%m/%d/%Y') IS NULL;


/* ================================================================
   SECTION 5 — CATEGORY-SPECIFIC VALIDATION
   ================================================================ */

-- 5.1 Supplier / Business Payment: totals and missing descriptions
SELECT
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT `Details`) AS unique_descriptions,
    SUM(`Withdrawn (KES)`) AS total_withdrawn,
    SUM(CASE WHEN `Details` IS NULL OR TRIM(`Details`) = '' THEN 1 ELSE 0 END) AS missing_details
FROM grocery_transactions_full
WHERE `Transaction Category` = 'Supplier / Business Payment';

-- 5.2 Supplier / Business Payment summary by description availability

SELECT
    CASE
        WHEN `Details` IS NULL OR TRIM(`Details`) = ''
            THEN 'Missing description'
        ELSE 'Description present'
    END AS description_status,
    COUNT(*) AS number_of_transactions,
    SUM(`Withdrawn (KES)`) AS total_withdrawn
FROM grocery_transactions_full
WHERE `Transaction Category` = 'Supplier / Business Payment'
GROUP BY description_status
ORDER BY number_of_transactions DESC;

-- 5.3 Financing: totals and missing descriptions
SELECT
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT `Details`) AS unique_descriptions,
    SUM(`Paid In (KES)`) AS total_paid_in,
    SUM(`Withdrawn (KES)`) AS total_withdrawn,
    SUM(CASE WHEN `Details` IS NULL OR TRIM(`Details`) = '' THEN 1 ELSE 0 END) AS missing_details
FROM grocery_transactions_full
WHERE `Transaction Category` = 'Financing';

-- 5.4 Financing analysis by direction of money movement

SELECT
    CASE
        WHEN `Paid In (KES)` > 0 AND `Withdrawn (KES)` > 0
            THEN 'Both paid in and withdrawn'
        WHEN `Paid In (KES)` > 0
            THEN 'Paid in'
        WHEN `Withdrawn (KES)` > 0
            THEN 'Withdrawn'
        ELSE 'No monetary movement'
    END AS financing_flow,
    COUNT(*) AS number_of_transactions,
    SUM(`Paid In (KES)`) AS total_paid_in,
    SUM(`Withdrawn (KES)`) AS total_withdrawn
FROM grocery_transactions_full
WHERE `Transaction Category` = 'Financing'
GROUP BY financing_flow
ORDER BY number_of_transactions DESC;


-- 5.5 Owner Withdrawal summary

SELECT
    COUNT(*) AS total_transactions,
    SUM(`Withdrawn (KES)`) AS total_withdrawn
FROM grocery_transactions_full
WHERE `Transaction Category` = 'Owner Withdrawal';

-- 5.6 Charges / Fees analysis by transaction value

SELECT
    CASE
        WHEN `Paid In (KES)` = 0 AND `Withdrawn (KES)` = 0
            THEN 'Zero-value records'
        ELSE 'Records with monetary value'
    END AS fee_record_type,
    COUNT(*) AS number_of_transactions,
    SUM(`Paid In (KES)`) AS total_paid_in,
    SUM(`Withdrawn (KES)`) AS total_withdrawn
FROM grocery_transactions_full
WHERE `Transaction Category` = 'Charges / Fees'
GROUP BY fee_record_type
ORDER BY number_of_transactions DESC;

-- 5.7 Identify zero-value fee records and check
-- whether their receipt numbers occur in Customer Sale records.
/*
FINDING:
The investigation identified 13 zero-value Charges / Fees
records.

All 13 records have matching Customer Sale receipt numbers.

The EXISTS approach was used to avoid JOIN fan-out
when checking receipt-number matches.

The actual fee amounts could not be verified from
the available transaction records. Zero values were
therefore retained without adjustment.
*/
SELECT
    COUNT(*) AS zero_value_fee_records,
    SUM(
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM grocery_transactions_full AS sale
                WHERE sale.`Receipt No.` = fee.`Receipt No.`
                  AND sale.`Transaction Category` = 'Customer Sale'
            )
            THEN 1
            ELSE 0
        END
    ) AS fee_records_matching_customer_sale
FROM grocery_transactions_full AS fee
WHERE fee.`Transaction Category` = 'Charges / Fees'
  AND fee.`Paid In (KES)` = 0
  AND fee.`Withdrawn (KES)` = 0;

-- 5.8 Customer Sale: overall validation
SELECT
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT `Details`) AS unique_descriptions,
    SUM(`Paid In (KES)`) AS total_paid_in,
    SUM(`Withdrawn (KES)`) AS total_withdrawn,
    SUM(CASE WHEN `Details` IS NULL OR TRIM(`Details`) = '' THEN 1 ELSE 0 END) AS missing_details,
    SUM(CASE WHEN `Paid In (KES)` = 0 AND `Withdrawn (KES)` = 0 THEN 1 ELSE 0 END) AS both_zero_transactions
FROM grocery_transactions_full
WHERE `Transaction Category` = 'Customer Sale';

-- 5.9 Customer Sale summary

SELECT
    COUNT(*) AS total_customer_transactions,
    SUM(`Paid In (KES)`) AS total_customer_sales,
    COUNT(DISTINCT `Details`) AS unique_description_count
FROM grocery_transactions_full
WHERE `Transaction Category` = 'Customer Sale';

-- 5.10 Customer Sale description patterns
SELECT
    CASE
        WHEN `Details` LIKE 'Merchant Payment from%' THEN 'Merchant Payment from'
        WHEN `Details` LIKE 'Merchant Payment Online from%' THEN 'Merchant Payment Online from'
        ELSE 'Other description pattern'
    END AS description_pattern,
    COUNT(*) AS number_of_transactions,
    SUM(`Paid In (KES)`) AS total_paid_in
FROM grocery_transactions_full
WHERE `Transaction Category` = 'Customer Sale'
GROUP BY description_pattern
ORDER BY number_of_transactions DESC;

-- 5.11 Customer Sale description availability check

SELECT
    CASE
        WHEN `Details` IS NULL OR TRIM(`Details`) = ''
            THEN 'Missing description'
        ELSE 'Description present'
    END AS description_status,
    COUNT(*) AS number_of_transactions,
    SUM(`Paid In (KES)`) AS total_customer_sales
FROM grocery_transactions_full
WHERE `Transaction Category` = 'Customer Sale'
GROUP BY description_status
ORDER BY number_of_transactions DESC;

-- 5.12 Classify remaining Customer Sale description patterns
SELECT
    CASE
        WHEN `Details` LIKE 'Small Business Pay Merchant from%' THEN 'Small Business Pay Merchant from'
        WHEN `Details` LIKE 'FSI Merchant Interoperability%' THEN 'FSI Merchant Interoperability'
        WHEN `Details` LIKE 'Merchant Payment received from%' THEN 'Merchant Payment received from'
        ELSE 'Other'
    END AS description_pattern,
    COUNT(*) AS number_of_transactions,
    SUM(`Paid In (KES)`) AS total_paid_in
FROM grocery_transactions_full
WHERE `Transaction Category` = 'Customer Sale'
  AND `Details` NOT LIKE 'Merchant Payment from%'
  AND `Details` NOT LIKE 'Merchant Payment Online from%'
GROUP BY description_pattern
ORDER BY number_of_transactions DESC;

-- 5.13 Summary of unusual Customer Sale records
-- Individual transaction identifiers and descriptions are excluded
-- from this public version to protect privacy.
/*
VALIDATION FINDING:
The revised query returned the same three unusual
Customer Sale records as the original query.

Combined Paid In: KES 30
Combined Withdrawn: KES 0

A separate NULL check confirmed zero missing
Customer Sale descriptions.

The transactions were retained in Customer Sale
pending further business evidence.
*/

SELECT
    COUNT(*) AS unusual_transaction_count,
    SUM(`Paid In (KES)`) AS total_paid_in
FROM grocery_transactions_full
WHERE `Transaction Category` = 'Customer Sale'
  AND `Details` LIKE 'Business Buy Goods by%'
  AND `Paid In (KES)` = 10;

-- 5.14 FSI interoperability transaction summary
-- Individual transaction descriptions are excluded for privacy.

SELECT
    COUNT(*) AS transaction_count,
    SUM(`Paid In (KES)`) AS total_paid_in,
    SUM(`Withdrawn (KES)`) AS total_withdrawn
FROM grocery_transactions_full
WHERE `Details` LIKE '%FSI%';

-- 5.15 Specific merchant reference investigation
-- Excluded from the public analysis script because the original
-- investigation relied on a potentially identifying merchant reference.
-- Identifying business references have been omitted to protect privacy.

-- 5.16 Owner-associated Customer Sale comparison
-- Excluded from the public analysis script because the original
-- classification relied on personal names and phone numbers.
-- Personal identifiers have been omitted to protect privacy.

/* ================================================================
   SECTION 6 — FINAL CATEGORY AND TABLE RECONCILIATION
   ================================================================ */

-- 6.1 Reconciliation by category (expected total: 18,101 rows)
-- GROUPING() identifies the grand-total row separately from NULL categories.

SELECT
    CASE
        WHEN GROUPING(`Transaction Category`) = 1
            THEN 'GRAND TOTAL'
        WHEN `Transaction Category` IS NULL
            THEN 'NULL CATEGORY'
        ELSE `Transaction Category`
    END AS transaction_category,
    COUNT(*) AS number_of_transactions,
    SUM(`Paid In (KES)`) AS total_paid_in,
    SUM(`Withdrawn (KES)`) AS total_withdrawn
FROM grocery_transactions_full
GROUP BY `Transaction Category`
WITH ROLLUP;

/* ================================================================
   SECTION 7 — CREATE A CLEAN VIEW FOR POWER BI
   Run this section when ready. It creates/replaces a VIEW only.
   ================================================================ */

CREATE OR REPLACE VIEW vw_grocery_transactions AS
SELECT
    `Receipt No.` AS receipt_no,
    STR_TO_DATE(`Transaction Date`, '%m/%d/%Y') AS transaction_date,
    `Time` AS transaction_time,
    `Details` AS transaction_details,
    `Paid In (KES)` AS paid_in_kes,
    `Withdrawn (KES)` AS withdrawn_kes,
    `Balance (KES)` AS balance_kes,
    `Statement Period` AS statement_period,
    `Transaction Category` AS transaction_category
FROM grocery_transactions_full;

-- 7.1 Validate Power BI View record count

SELECT
    COUNT(*) AS total_records,
    SUM(paid_in_kes) AS total_paid_in,
    SUM(withdrawn_kes) AS total_withdrawn
FROM vw_grocery_transactions;

-- 7.2 Validate the Power BI view against the original table
SELECT
    'Original Table' AS data_source,
    COUNT(*) AS total_records,
    SUM(`Paid In (KES)`) AS total_paid_in,
    SUM(`Withdrawn (KES)`) AS total_withdrawn
FROM grocery_transactions_full
UNION ALL
SELECT
    'Power BI View' AS data_source,
    COUNT(*) AS total_records,
    SUM(paid_in_kes) AS total_paid_in,
    SUM(withdrawn_kes) AS total_withdrawn
FROM vw_grocery_transactions;

/* END OF COLLECTION
   Save this file and keep it as the master SQL script for your portfolio project.
*/
