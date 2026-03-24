# Forecast Project - Financial Calculating

## Overview
This project processes SOP volume, customer, and pricing data to calculate forecast revenue values across four business units:
- **1. Farming Operations**
- **2. Meat Processing (Corowa)**
- **3. Meat Sales**
- **6. Laverton Processing**

The main output is `GL_DB Template.csv`, structured for GL database input.

## Files
- `Financial Calculating.qmd` - Main Quarto script containing all data processing and calculation logic
- `GL_DB Template.csv` - Output file generated after running the script (not included due to data privacy)
- `Data Template.xlsx` - A sample template to help readers understand the structure of the data used to build the database. Note that due to the complexity of the data, various conditions and filtering rules are applied throughout the project code - the raw data alone does not reflect all the logic involved.

## Data Sources (not included in repo)
| File | Sheet(s) | Description |
|------|----------|-------------|
| `SOP Volumes.xlsx` | Sheet1 | Volume data - split into Farm, Bone, and VA types based on row identifiers |
| `Prices.xlsb` | Carcass Price | Carcass price per SOP Unicode and Abattoir by period |
| `Prices.xlsb` | Bone Fee | Boning fee per SOP Unicode and Abattoir by period |
| `Prices.xlsb` | Kill Fee | Kill fee per SOP Unicode and Abattoir by period |
| `Prices.xlsb` | BM PRice | Item-level unit prices used for Boxed Meat, Offal, and Commodity value calculations |
| `Master Data..xlsx` | GL & CC | GL account and cost centre mappings by BU |
| `Master Data..xlsx` | Customer | Customer list with SOP Unicode, BU, Tab, Floor, and Customer Group |

> **Note on excluded files:** All raw data files and output files (including `GL_DB Template.csv`) are intentionally excluded from this repository. This project is developed within the Finance Team and these files contain sensitive and confidential company financial data. Publishing them is strictly prohibited. Only the code and logic are shared here.

## How to Run
1. Open `Financial Calculating.qmd` in RStudio
2. Ensure all data source files are placed in the correct OneDrive path
3. Run all chunks sequentially - the final chunk writes `GL_DB Template.csv`

## Key Logic

### GL Account Codes
- **400000** = External Sales (sales to external customers)
- **400028** = Intercompany Sales (internal transfers between business units)

### Volume Data Split
Volume data from `SOP Volumes.xlsx` is split into three datasets based on the `Tab` column:
- **Farm data** - rows where Tab is `Farm`, `Kill`, or `Bone` (used for Farm/Kill/Bone floor revenue)
- **Bone data** - rows where Tab is `2.Meat Processing` or `6.Laverton Processing` (used for item-level pricing: Offal, 6Way, Commodity)
- **VA data** - rows where Tab is `3.Meat Sales` (used for Meat Sales and Corowa commodity volume source)

### Calculation Methods by Floor
| Floor | Value Formula | Price Source |
|-------|--------------|--------------|
| Farm | Total Weight × Carcass Price | `Carcass Price` sheet in `Prices.xlsb` |
| Kill | Units × Kill Fee | `Kill Fee` sheet in `Prices.xlsb` |
| Bone | Units × Bone Fee | `Bone Fee` sheet in `Prices.xlsb` |
| Boxed Meat | Total Weight × Item Price | `BM PRice` sheet in `Prices.xlsb` |
| Offal (Edible/Inedible) | Total Weight × Item Price | `BM PRice` sheet in `Prices.xlsb` |
| Commodity | Total Weight × Item Price | `BM PRice` sheet in `Prices.xlsb` |

### Special Conditions
- **Laverton Edible Offal - $0.51/kg discount**: Laverton ships edible offal to Lineage, which charges a storage/handling fee. This discount is subtracted from the calculated value. This is the main reason Corowa and Laverton offal are calculated separately.
- **Laverton Edible Offal - Intercompany (400028)**: Laverton consolidates its edible offal with Corowa and sells under Corowa's name. As a result, Laverton edible offal is recorded as an intercompany transfer (400028) rather than an external sale (400000).
- **Laverton 6Way - $0.51/kg discount**: Same Lineage handling fee applies to Laverton 6Way products.
- **Corowa Commodity 400000 vs 400028**: The 400028 volume comes from internal VA sales (Procurement rows in Meat Sales tab). The 400000 volume is the remainder: Total Commodity Bone minus the 400028 internal portion.
- **FCOROWAWoolworths inherits price from FEXTERNALBig River Pork - Coles**: A special price inheritance rule applied during the Farm carcass price join.
- **Laverton Kill - 6Way/Commodity customers temporarily excluded**: A temporary filter removes rows where Abattoir is Laverton, Tab is Kill, and the customer name contains "6WAY" or "COMMODITY".

### Account Structure by Business Unit and Floor
| Business Unit | Floor | GL Account | Cost Centre |
|--------------|-------|-----------|-------------|
| 1. Farming Operations | Farm | 400000 / 400028 | 10001812 |
| 2. Meat Processing | Kill Floor | 400000 / 400028 | 10201816 |
| 2. Meat Processing | Boning Room | 400000 / 400028 | 11901816 |
| 2. Meat Processing | Boxed Meat | 400000 / 400028 | 10501816 |
| 2. Meat Processing | Edible Offal | 400000 | 10001816 |
| 2. Meat Processing | Inedible Offal | 400000 | 10801816 |
| 3. Meat Sales | VA | 400000 | 10001814 |
| 6. Laverton Processing | Kill Floor | 400000 / 400028 | 10201854 |
| 6. Laverton Processing | Boning Room | 400000 / 400028 | 11901854 |
| 6. Laverton Processing | Boxed Meat | 400000 / 400028 | 10501854 |
| 6. Laverton Processing | Edible Offal | 400028 | 10001854 |
| 6. Laverton Processing | Inedible Offal | 400000 | 10801854 |

## Requirements
### Please install these libraries beforehand in order to use the code
```r
library(readxl); library(readr); library(dplyr); library(tidyr)
library(lubridate); library(openxlsx); library(openxlsx2); library(stringr)
```
