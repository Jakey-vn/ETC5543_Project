# Forecast Project - Financial Calculating

## Overview
This project processes SOP volume, customer, and pricing data to calculate forecast revenue values across business units (Farm, Corowa Meat Processing, Laverton Processing, and Meat Sales).

The main output is `GL_DB Template.csv`, structured for GL database input.

## Files
- `Financial Calculating.qmd` - Main Quarto script containing all data processing and calculation logic
- `GL_DB Template.csv` - Output file generated after running the script

## Data Sources (not included in repo)
| File | Description |
|------|-------------|
| `SOP Volumes.xlsx` | Volume data (Farm, Bone, VA types) |
| `Prices.xlsb` | Carcass Price, Bone Fee, Kill Fee by period |
| `Master Data..xlsx` | GL & CC account mappings and customer data |

> **Note on excluded files:** All raw data files and output files (including `GL_DB Template.csv`) are intentionally excluded from this repository. This project is developed within the Finance Team and these files contain sensitive and confidential company financial data. Publishing them is strictly prohibited. Only the code and logic are shared here.

## How to Run
1. Open `Financial Calculating.qmd` in RStudio
2. Ensure all data source files are placed in the correct path
3. Run all chunks sequentially - the final chunk writes `GL_DB Template.csv`

## Key Logic
- **400000** = External Sales | **400028** = Intercompany Sales
- **Farm Tab**: Value = Total Weight × Carcass Price
- **Bone/Kill Tab**: Value = Units × Fee
- Volume data is split into three types (Farm, Bone, VA) based on column identifiers

## Requirements
### Please install these library beforehand in order to use the code
library(readxl); library(dplyr); library(tidyr)
library(lubridate); library(openxlsx2); library(stringr)
