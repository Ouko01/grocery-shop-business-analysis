# Real-World Grocery Shop Transaction & Business Performance Analysis

## Project Overview

This project analyzes real-world M-PESA transaction records from a local grocery shop to understand recorded customer sales performance, transaction patterns, and financial activity.

The objective was to transform raw transaction data into meaningful business insights that could support performance monitoring, informed decision-making, and improved business operations.

The project demonstrates an end-to-end data analytics workflow using Microsoft Excel, MySQL, and Power BI, from data preparation and SQL analysis to interactive visualization and business recommendations.

## Business Objectives

- Analyze customer sales performance across reporting periods.
- Identify monthly and annual sales trends.
- Examine transaction volumes and average transaction values.
- Understand the movement of money across transaction categories.
- Investigate data-quality issues and validate analytical results.
- Translate findings into practical business recommendations.

## Tools and Technologies

- **Microsoft Excel 2019:** Data cleaning, transformation, and preparation using Power Query.
- **MySQL:** Data querying, aggregation, performance analysis, data-quality investigation, and validation.
- **Microsoft Power BI:** Interactive dashboards, key performance indicators, and business reporting.

## Project Workflow

1. **Data preparation:** Combined and cleaned transaction records using Excel Power Query.
2. **SQL analysis:** Queried transaction data, calculated performance metrics, examined trends, and investigated data-quality exceptions.
3. **Validation:** Reconciled transaction counts and financial totals between the SQL analysis table and the Power BI reporting view.
4. **Visualization:** Developed a Power BI dashboard with a Business Overview page and a Detailed Analysis page.
5. **Business interpretation:** Identified sales patterns, documented limitations, and developed recommendations.

## Dataset Overview

- **Total transaction records:** 18,101
- **Reporting period:** 29 August 2023 – 29 August 2026
- **Total recorded incoming payments:** KES 687,683
- **Total recorded outgoing payments:** KES 685,610
- **Recorded customer sales:** KES 681,132

The dataset includes transaction dates, descriptions, receipt references, incoming and outgoing amounts, balances, and transaction categories.

## Key Findings

### 1. Annual Customer Sales Performance

Recorded customer sales increased from KES 81,577 in 2024 to KES 336,292 in 2025, representing growth of approximately **312.2%**.

Customer-sale transaction volume also increased, reaching 8,394 transactions in 2025.

### 2. Monthly Sales Performance

August 2025 recorded the highest monthly customer sales in the analyzed period, at KES 36,498. July 2025 followed with KES 36,310, while October 2025 recorded KES 33,613.

These patterns provide a basis for investigating changes in sales activity and potential operational factors.

### 3. Transaction Analysis

The analysis examined incoming and outgoing payments across categories including Customer Sale, Supplier / Business Payment, Financing, Charges/Fees, and Owner Withdrawal.

This classification helped distinguish recorded customer receipts from other financial movements through the M-PESA account.

### 4. Data Quality and Validation

Data-quality checks examined missing values in key fields, negative amounts, repeated receipt numbers, zero-value transactions, and transaction classifications.

The SQL analysis table and Power BI reporting view were reconciled to confirm consistency in transaction counts and incoming and outgoing totals.

Exceptions were documented rather than changed without sufficient supporting evidence.

## Business Recommendations

- Monitor monthly customer sales to identify unusually high or low periods.
- Investigate sales patterns alongside stock availability, purchasing records, and other operational information.
- Use sales and transaction-volume trends to support inventory and cash-flow planning.
- Maintain consistent transaction categorization and investigate unresolved exceptions.
- Combine transaction records with product costs, inventory data, and operating expenses to support a more complete assessment of business performance.

## Limitations

M-PESA transaction records show money received and paid through the recorded account, but they do not establish the shop's overall profitability.

The analysis does not include all the information required to calculate profit, such as cost of goods sold, inventory changes, operating expenses, or transactions through other accounts and payment channels.

The reporting period also begins and ends partway through a calendar year, so comparisons involving 2023 and 2026 should be interpreted cautiously.

## Project Deliverables

- [Business Analysis Report](Report/)
- [SQL Analysis Scripts](SQL/)
- [Power BI Dashboard](Dashboard/)
- Data preparation and data-quality investigation.

## Conclusion

This project demonstrates how Excel, SQL, and Power BI can be combined to transform real-world transaction data into structured analysis and actionable business insights.

It highlights practical skills in data preparation, querying, validation, dashboard development, and business interpretation while recognizing the limitations of the available data.

**Author:** Billy Ouko  
**Focus:** Data Analytics | Excel | MySQL | Power BI
