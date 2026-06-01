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
- `Debug Code.qmd` - Standalone validation and debugging checks. Run these chunks after the main script to verify data integrity. See the [Debug Checks](#debug-checks) section for details.
- `Gap_Check.R` - Gap analysis script that produces `Gap_Check.xlsx`. Run after `Financial Calculating.qmd` in the same R session (it references variables created there). See the [Gap Check](#gap-check) section for details.
- `GL_DB Template.csv` - Output file generated after running the script (not included due to data privacy)
- `Gap_Check.xlsx` - Output file generated after running `Gap_Check.R` (not included due to data privacy)
- `Data Template.xlsx` - A sample template to help readers understand the structure of the data used to build the database. Note that due to the complexity of the data, various conditions and filtering rules are applied throughout the project code - the raw data alone does not reflect all the logic involved.

## Data Sources (not included in repo)
| File | Sheet(s) | Description |
|------|----------|-------------|
| `SOP Volumes.xlsx` | Sheet1 | Volume data - split into Farm, Bone, and VA types based on row identifiers |
| `Prices.xlsb` | Carcass Price | Carcass price per SOP Unicode and Abattoir by period |
| `Prices.xlsb` | Bone Fee | Boning fee per SOP Unicode and Abattoir by period |
| `Prices.xlsb` | Kill Fee | Kill fee per SOP Unicode and Abattoir by period |
| `Prices.xlsb` | BM PRice | Item-level unit prices used for Boxed Meat, Offal, and Commodity value calculations |
| `Prices.xlsb` | Packaging VA | Packaging and pallet rates per BOM item and variant, used for all packaging/pallet expense calculations |
| `Master Data..xlsx` | GL & CC | GL account and cost centre mappings by BU |
| `Master Data..xlsx` | Customer | Customer list with SOP Unicode, BU, Tab, Floor, and Customer Group |
| `Master Data..xlsx` | VA | VA brand data - maps Item Code to Brand name, used to assign customer names in Meat Sales output |
| `Trade Allowance.xlsx` | Sheet1 | Trade allowance rates (% of revenue and fixed $ value) per Brand and Period for 3.Meat Sales |
| `Rates and Allocation.xlsx` | Sheet1 | VA freight allocation - $/kg rate and % split by Brand and State (Domestic/Export) |
| `Rates and Allocation.xlsx` | Sheet2 | Other freight allocation - $/kg rate and proportion split by Customer type (Offal, 6 way, Commodity) and freight type |

> **Note on excluded files:** All raw data files and output files (including `GL_DB Template.csv`) are intentionally excluded from this repository. This project is developed within the Finance Team and these files contain sensitive and confidential company financial data. Publishing them is strictly prohibited. Only the code and logic are shared here.

## How to Run
1. Open `Financial Calculating.qmd` in RStudio
2. Ensure all data source files are placed in the correct OneDrive path
3. Run all chunks sequentially - the final chunk writes `GL_DB Template.csv`
4. Optionally, open `Debug Code.qmd` and run its chunks to validate data integrity (requires the main script to have been run first in the same R session)
5. Optionally, run `Gap_Check.R` to produce `Gap_Check.xlsx` — a weight reconciliation and data quality audit across all categories (also requires the main script to have been run first in the same R session)

## Key Logic

### GL Account Codes
- **400000** = External Sales (sales to external customers)
- **400028** = Intercompany Sales (internal transfers between business units)
- **400350** = Gross Sales - V&V sell and buy-back (Farming Operations)
- **450050** = Trade Allowance Expense (3.Meat Sales and 6.Laverton Processing)
- **500031** = External Meat Purchase Cost of Sales (3.Meat Sales)
- **500192** = Freight Out / Domestic Freight Expense
- **500609** = Freight Ocean / Export Freight Expense
- **510157** = Cost of Sales - V&V sell and buy-back (Farming Operations)
- **510167** = Expense - Intercompany pig purchases / meat trade cost of sales
- **650301** = Packaging Expense
- **650303** = Pallet Expense
- **650311** = Packaging and Margin Expense (special contracts: Woolworths, DRJ, Meat Sales)
- **730010** = Storage / Frozen Stock Holding Expense

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
| Meat Sales (VA) | Total Weight × Price | `Price` column in `SOP Volumes.xlsx` (not BM PRice) |
| Meat Trade | Total Weight × Item Price | `BM PRice` sheet in `Prices.xlsb` (sourced from Laverton bone data) |

### Special Conditions
- **Laverton Edible Offal - $0.51/kg discount**: Laverton ships edible offal to Lineage, which charges a storage/handling fee. This discount is subtracted from the calculated value. This is the main reason Corowa and Laverton offal are calculated separately.
- **Laverton Edible Offal - Intercompany (400028)**: Laverton consolidates its edible offal with Corowa and sells under Corowa's name. As a result, Laverton edible offal is recorded as an intercompany transfer (400028) rather than an external sale (400000).
- **Laverton 6Way - $0.51/kg discount**: Same Lineage handling fee applies to Laverton 6Way products.
- **Laverton Commodity Frozen - $0.51/kg discount**: The same Lineage handling fee also applies to Laverton Commodity Frozen (400028-10501854). Laverton Commodity Chilled (400000-10501854) is not discounted.
- **Corowa Commodity 400000 vs 400028**: The 400028 volume comes from internal VA sales (Procurement rows in Meat Sales tab). The 400000 volume is the remainder: Total Commodity Bone minus the 400028 internal portion.
- **FCOROWAWoolworths inherits price from FEXTERNALBig River Pork - Coles**: A special price inheritance rule applied during the Farm carcass price join.
- **Laverton Kill - 6Way/Commodity customers temporarily excluded**: A temporary filter removes rows where Abattoir is Laverton, Tab is Kill, and the customer name contains "6WAY" or "COMMODITY".
- **Laverton Export Packaging - $12.30/unit fee**: Laverton charges a fixed $12.30 per head for carcass export packaging (Singapore and Malaysia). Volume source is Kill service rows from `volume_farm_raw`, grouped by SOP Unicode and Month.
- **Laverton Sow Packaging - temporary fixed fee of $0.095/kg**: Sow packaging price is currently missing from the `Packaging VA` sheet (VARIANT == 4), so a hardcoded rate of $0.095/kg is unconditionally applied as a temporary fix until the data is updated.
- **Packaging price fallback (variant 3 → 4)**: For edible offal packaging/pallet (Corowa and Laverton), prices are first looked up from VARIANT == 3. If an item has no price there (NA or zero weight), it falls back to VARIANT == 4.
- **Packaging VARIANT by product type**: Edible offal uses VARIANT 3 with fallback to 4. 6 Way and Commodity packaging/pallet use VARIANT 4 directly (no fallback). VA / 3.Meat Sales packaging and pallet use VARIANT 2.
- **Woolworths special contract parameters**: Packaging fee = $0.137/kg, margin = 45.26%. Both are applied to bone-out weight adjusted by hot-to-cold (90.9%) and cold-to-meat (88%) yield factors. Packaging (650301) is recorded as a positive cost; margin (650311) is negated.
- **DRJ special contract parameters**: Packaging fee = $0.15/kg, margin = 10%. Same yield adjustments as Woolworths apply. Packaging (650301) is positive; margin (650311) is negated.

### Account Structure by Business Unit and Floor
| Business Unit | Floor | GL Account | Cost Centre |
|--------------|-------|-----------|-------------|
| 1. Farming Operations | Farm | 400000 / 400028 | 10001812 |
| 1. Farming Operations | V&V Gross Sales | 400350 | 10001812 |
| 1. Farming Operations | V&V Cost of Sales | 510157 | 10001812 |
| 1. Farming Operations | Freight In *(not yet implemented)* | 500195 | 10001812 |
| 2. Meat Processing | Kill Floor | 400000 / 400028 | 10201816 |
| 2. Meat Processing | Boning Room | 400000 / 400028 | 11901816 |
| 2. Meat Processing | Boxed Meat | 400000 / 400028 | 10501816 |
| 2. Meat Processing | Meat Trade (from Laverton) | 400000 | 10501816 |
| 2. Meat Processing | Edible Offal | 400000 | 10001816 |
| 2. Meat Processing | Inedible Offal | 400000 | 10801816 |
| 2. Meat Processing | Pig from Farm (Expense) | 510167 | 10501816 |
| 2. Meat Processing | Meat Trade Cost of Sales | 510167 | 10501816 |
| 2. Meat Processing | Freight In *(not yet implemented)* | 500195 | 10001816 |
| 2. Meat Processing | Edible Offal Packaging | 650301 | 10001816 |
| 2. Meat Processing | Edible Offal Pallet | 650303 | 10001816 |
| 2. Meat Processing | 6 Way FRZ Packaging | 650301 | 10501816 |
| 2. Meat Processing | 6 Way FRZ Pallet | 650303 | 10501816 |
| 2. Meat Processing | Commodity FRZ Packaging | 650301 | 10501816 |
| 2. Meat Processing | Commodity FRZ Pallet | 650303 | 10501816 |
| 2. Meat Processing | Woolworths Packaging (special contract) | 650301 | 11901816 |
| 2. Meat Processing | Woolworths Margin (special contract) | 650311 | 11901816 |
| 2. Meat Processing | DRJ Packaging (special contract) | 650301 | 11901816 |
| 2. Meat Processing | DRJ Margin (special contract) | 650311 | 11901816 |
| 2. Meat Processing | Edible Offal Storage Cost | 730010 | 10001816 |
| 2. Meat Processing | Commodity FRZ Storage Cost | 730010 | 10501816 |
| 2. Meat Processing | 6 Way FRZ Storage Cost | 730010 | 10501816 |
| 2. Meat Processing | Meat Trade Storage Cost | 730010 | 10501816 |
| 2. Meat Processing | Stock On Hand Cost | 730010 | 10501816 |
| 2. Meat Processing | Edible Offal Freight Domestic | 500192 | 10001816 |
| 2. Meat Processing | Edible Offal Freight Ocean | 500609 | 10001816 |
| 2. Meat Processing | 6 Way Freight Domestic | 500192 | 10501816 |
| 2. Meat Processing | 6 Way Freight Ocean | 500609 | 10501816 |
| 2. Meat Processing | Commodity Freight Domestic | 500192 | 10501816 |
| 2. Meat Processing | Commodity Freight Export | 500609 | 10501816 |
| 2. Meat Processing | Meat Trade Freight Domestic | 500192 | 10501816 |
| 2. Meat Processing | Meat Trade Freight Ocean | 500609 | 10501816 |
| 3. Meat Sales | VA | 400000 | 10001814 |
| 3. Meat Sales | Meat Purchase - Internal | 510167 | 10001814 |
| 3. Meat Sales | Meat Purchase - External | 500031 | 10001814 |
| 3. Meat Sales | Packaging | 650311 | 10001814 |
| 3. Meat Sales | Pallet | 650303 | 10001814 |
| 3. Meat Sales | Trade Allowance | 450050 | 10001814 |
| 3. Meat Sales | Freight Out | 500192 | 10001814 |
| 3. Meat Sales | Storage Cost | 730010 | 10001814 |
| 3. Meat Sales | Stock On Hand Cost | 730010 | 10001814 |
| 6. Laverton Processing | Kill Floor | 400000 / 400028 | 10201854 |
| 6. Laverton Processing | Boning Room | 400000 / 400028 | 11901854 |
| 6. Laverton Processing | Boxed Meat (6Way FRZ, Commodity FRZ) | 400028 | 10501854 |
| 6. Laverton Processing | Boxed Meat (Commodity Chilled) | 400000 | 10501854 |
| 6. Laverton Processing | Sow | 400000 | 10501854 |
| 6. Laverton Processing | Edible Offal | 400028 | 10001854 |
| 6. Laverton Processing | Inedible Offal | 400000 | 10801854 |
| 6. Laverton Processing | Pig from Farm (Expense) | 510167 | 10501854 |
| 6. Laverton Processing | Freight In *(not yet implemented)* | 500195 | 10501854 |
| 6. Laverton Processing | Edible Offal Packaging | 650301 | 10001854 |
| 6. Laverton Processing | Edible Offal Pallet | 650303 | 10001854 |
| 6. Laverton Processing | 6 Way FRZ Packaging | 650301 | 10501854 |
| 6. Laverton Processing | 6 Way FRZ Pallet | 650303 | 10501854 |
| 6. Laverton Processing | Commodity FRZ Packaging | 650301 | 10501854 |
| 6. Laverton Processing | Commodity FRZ Pallet | 650303 | 10501854 |
| 6. Laverton Processing | Sow FRZ Packaging | 650301 | 10501854 |
| 6. Laverton Processing | Sow FRZ Pallet | 650303 | 10501854 |
| 6. Laverton Processing | Export Carcass Packaging | 650301 | 10201854 |
| 6. Laverton Processing | Trade Allowance | 450050 | 10201854 |
| 6. Laverton Processing | Sow FRZ Storage Cost | 730010 | 10501854 |
| 6. Laverton Processing | Stock On Hand Cost | 730010 | 10501854 |

### Meat Trade Logic (Laverton → Corowa)
Corowa's Boxed Meat section includes a **Meat Trade** category that consolidates Laverton products sold through Corowa. The volume source is Laverton bone data, remapped to Corowa as the selling entity (`Abattoir = COROWA`, `GL Account = 400000`, `Cc Key = 10501816`). Three product types are included:

| Meat Trade Type | Laverton Source Filter |
|----------------|----------------------|
| 6 Way | `Run == "6 WAY"` (Laverton) |
| Commodity | `Run == "COMMODITY BONE"` + `Storage == "FROZEN"` (Laverton) |
| Edible Offal | `Type IN ("OFFALS", "BACON CUTS")` + `Run == "TOTAL KILL"` (Laverton) |

The join key to the customer account table is `Service` (values: `6 Way`, `Commodity`, `Edible Offal`). Note that the $0.51 Lineage discount is **not** applied here - it is already applied in the separate Laverton Edible Offal / 6Way / Commodity Frozen accounts.

### Expense Account Logic

**V&V Sell and Buy-Back (FLAVERTONNew Team)**
- Filters the `FLAVERTONNew Team` unicode from customer data
- Calculates value from external VA procurement rows (External vendor, Procurement service) joined to carcass price ("Other Transactions" row)
- Creates two paired accounts per period: Gross Sales (400350, negated) and Cost of Sales (510157), both under 10001812

**Intercompany Pig Purchase from Farm - Corowa and Laverton (510167)**
- Filters internal (non-External) farm volume rows for Corowa 6Way/Commodity unicodes and Laverton 6Way/Commodity unicodes respectively
- **Corowa** produces three expense row types per customer per period:
  - Buy: `Total Weight × Carcass Price` (Farm tab)
  - Kill: `Units × Kill Fee` (Kill tab, averaged across COROWA6WAY and COROWACOMMODITY unicodes)
  - Bone: `Units × Bone Fee` (Bone tab, averaged across COROWA6WAY and COROWACOMMODITY unicodes)
- **Laverton** produces one expense row type: `Total Weight × Carcass Price` (Farm tab only)
- Produces separate expense rows for Corowa (510167-10501816) and Laverton (510167-10501854)
- Note: There is a known mismatch between customer data and GL & CC account for this section - still under investigation

**Meat Trade Cost of Sales (510167-10501816)**
- Filters Customer Group == "Meat Trade" from 2.Meat Processing customer data
- Records the intercompany cost of sales for Laverton products transferred to Corowa as Meat Trade

**Meat Sales Cost of Sales - Internal and External (3.Meat Sales)**
- Both rows filter Customer Group == "Meat Purchase" from 3.Meat Sales customer data
- Internal purchases: 510167-10001814
- External purchases: 500031-10001814

**Packaging and Pallet Expenses**

Packaging (650301) and Pallet (650303) accounts are created per BU and product group, mirroring the same customer filters used in their corresponding revenue accounts. Prices come from the `Packaging VA` sheet in `Prices.xlsb` (keyed by BOM item code and VARIANT number). VARIANT used by product type:
- Edible Offal (Corowa and Laverton): VARIANT 3, falling back to VARIANT 4 if price is missing
- 6 Way and Commodity (Corowa and Laverton): VARIANT 4 directly
- VA / 3.Meat Sales: VARIANT 2

Note: Woolworths and DRJ use a **margin** account (650311) instead of a standard pallet account (650303) due to their special contract pricing arrangements. These two also filter by Tab == "Bone" and Floor == "Bone" (Boning Room), not Boxed Meat. Their values are calculated using fixed per-kg packaging fees and margin percentages applied to bone-out weight (adjusted by hot-to-cold and cold-to-meat yield factors). See [Special Conditions](#special-conditions) for the specific fee parameters.

**Freight In (500195)**
- Filters Customer name == "Freight In" from each BU's customer data
- Covers: 1.Farming Operations (500195-10001812), 2.Meat Processing (500195-10001816), 6.Laverton Processing (500195-10501854)
- **Note: Currently not implemented in the pipeline** — these accounts are not present in the final output. Freight In customers in `customer_data` are included in the farm revenue path but are not yet broken out as separate 500195 rows.

**Trade Allowance (450050)**
- **3.Meat Sales (450050-10001814)**: Joins VA revenue data with `Trade Allowance.xlsx` on Brand and Period. Calculates allowance as `Trade Spend % × Revenue Value` plus a fixed `Trade Spend Value`, summed by customer. Result is negated (expense).
- **6.Laverton Processing (450050-10201854)**: Applies a fixed rebate of $5.80/head to BE Campbells Bacon and B.E. Campbell customers based on Kill volume from `volume_farm_raw`. Result is negated (expense).

**Storage Expense (730010)**

Storage costs are calculated for frozen stock held at Lineage and other cold stores. Each account is split into two cost rows per period:
- **Cost In**: `Total Weight × $0.14/kg`
- **Cost Out**: `Total Weight × $0.08/kg` (Total Weight shown as 0 in output)

Accounts covered:
- Corowa Edible Offal FRZ (730010-10001816) - frozen offal only (filtered by `Storage == "FROZEN"`)
- Corowa Commodity FRZ (730010-10501816)
- Corowa 6 Way FRZ (730010-10501816)
- Corowa Meat Trade (730010-10501816) - uses the same combined Laverton volume as the Meat Trade revenue account
- Laverton Sow FRZ (730010-10501854)
- Value Add / 3.Meat Sales (730010-10001814) - currently set to $0 as a temporary adjustment

In addition, three **Stock On Hand** rows use a fixed monthly hold volume multiplied by a hold rate of $0.01/kg:
- Corowa Stock On Hand (730010-10501816): 1,100,000 kg
- Laverton Stock On Hand (730010-10501854): 200,000 kg
- Value Add Stock On Hand (730010-10001814): 60,000 kg

All storage values are negated (expense).

**Freight Out / Export Freight (500192 and 500609)**

Freight costs are split into Domestic (500192) and Ocean/Export (500609) for each product group, using allocation rates from `Rates and Allocation.xlsx`:

- **3.Meat Sales Freight Out (500192-10001814)**: Uses `Rates and Allocation.xlsx` Sheet1 (VA allocation) - $/kg rate and % weight split by Brand and State. Volume source is VA sales revenue data.
- **Corowa Edible Offal**: Domestic (500192-10001816) and Ocean (500609-10001816) - uses `Sheet2` Offal allocation (Proportion and $/kg by freight type).
- **Corowa 6 Way**: Domestic (500192-10501816) and Ocean (500609-10501816) - uses `Sheet2` 6 way allocation.
- **Corowa Commodity**: Domestic (500192-10501816) and Export (500609-10501816) - uses `Sheet2` Commodity allocation.
- **Corowa Meat Trade**: Domestic (500192-10501816) and Ocean (500609-10501816) - uses `Sheet2` allocation mapped by Service (Edible Offal, Commodity, 6 Way).

All freight values are negated (expense).

**Export Carcass Packaging (650301-10201854)**
- Covers Laverton export customers (Floor == "Export Carcass", Customer Group == "Export")
- Value = `Units × $12.30` (fixed per-head export packaging fee)
- Volume source: Kill service rows from `volume_farm_raw`, grouped by SOP Unicode and Month
- Result is negated (expense)

## Debug Checks

`Debug Code.qmd` contains validation chunks that must be run **after** `Financial Calculating.qmd` in the same R session (they reference variables created there).

| Check | Variable | Expected Result |
|-------|----------|----------------|
| Units × Avg Weight = Total Weight | `check_1` | All `TRUE` or `NA` |
| No item has multiple Item Codes | `check_2` | 0 rows returned |
| All customers captured in output | `check_3` | 0 rows returned (ideally) |
| Corowa commodity 400000 + 400028 = total | `check_4` | `difference` = 0 |
| No negative Total Weight in commodity 400000 | `check_5` | 0 observations |
| No VA procurement items missing from commodity data | *(inline anti_join)* | 0 rows returned |
| No `.x`/`.y` column conflicts across datasets | *(inline lapply)* | All empty character vectors |

The offal data print chunks (`Corowa_edible_check` and `Laverton_edible_check`) write intermediate CSVs to disk for manual inspection and are not strict pass/fail checks.

## Gap Check

`Gap_Check.R` must be run **after** `Financial Calculating.qmd` in the same R session (it references variables created there). It writes `Gap_Check.xlsx` with the following sheets:

### Sheet 1: SOP vs DB
Two sections in a single sheet:

**Weight Comparison** — side-by-side SOP raw weight vs DB weight for every category:

| Category | SOP Raw Weight (kg) | DB Weight (kg) |
|----------|-------------------|----------------|
| Corowa - Offal (Inedible + Edible) | … | … |
| Laverton - Offal (Inedible + Edible) | … | … |
| Corowa - 6 Way | … | … |
| Laverton - 6 Way | … | … |
| Laverton - Sow | … | … |
| Corowa - Commodity (400000 + 400028) | … | … |
| Laverton - Commodity CHILLED | … | … |
| Laverton - Commodity FROZEN | … | … |
| Meat Trade - 6 Way (Laverton → Corowa) | … | … |
| Meat Trade - Commodity FROZEN (Laverton → Corowa) | … | … |
| Meat Trade - Edible Offal (Laverton → Corowa) | … | … |
| VA / Meat Sales | … | … |

**Issues Summary** — one row per issue type showing rows affected, weight affected (kg), and suggested fix:

| Category | Issue | Rows Affected | Weight Affected (kg) | Fix |
|----------|-------|---------------|---------------------|-----|
| Revenue | Bone - Item Code not in BM PRice sheet | … | … | Add Item Code to BM PRice sheet |
| Revenue | Bone - Commodity: missing/invalid Storage | … | … | Fill in Storage (CHILLED / FROZEN) in SOP Volumes |
| Revenue | Farm - FARM tab: no Carcass Price match | … | … | Add Unicode + Abattoir + Period to Carcass Price sheet |
| Revenue | Farm - BONE tab: no Bone Fee match | … | … | Add Unicode + Abattoir + Period to Bone Fee sheet |
| Revenue | Farm - KILL tab: no Kill Fee match | … | … | Add Unicode + Abattoir + Period to Kill Fee sheet |
| Revenue | VA - Missing or zero price in SOP data | … | … | Fill in Price column in SOP Volumes (VA tab) |
| Revenue | VA - Item Code not in Brand Mapping | … | … | Add Item Code to VA Brand mapping (Master Data - VA sheet) |
| Revenue | Farm - Same Unicode has multiple Item Codes | … | … | Fix Unicode or Item Code mapping in SOP Volumes |
| Revenue | Commodity - VA Procurement Item not in Bone | … | … | Add Item Code to bone commodity tab in SOP Volumes |
| Expense | Expense - VA Sales: Missing Packaging Price | … | … | Add Item Code to packaging price data |
| Expense | Expense - Laverton Edible Offal: Missing Packaging Price | … | … | Add Item Code to packaging price data |
| Expense | Expense - Laverton Edible Offal: Missing Pallet Price | … | … | Add Item Code to pallet price data |
| Expense | Expense - Laverton 6 Way: Missing Packaging Price | … | … | Add Item Code to packaging price data |
| Expense | Expense - Laverton Sow: Missing Packaging Price | … | … | Add Item Code to packaging price data |
| Expense | Expense - Laverton Commodity: Missing Packaging Price | … | … | Add Item Code to packaging price data |

### Sheet 2: All Issues
All issue rows from every check combined into a single table with `Revenue Related Issue` and `Expense Related Issue` columns, plus Abattoir, Tab, Item Code, Item Description, Run, Storage, Type, Group, SOP Unicode, Customer name, Units, and Total Weight.

## Requirements
### Please install these libraries beforehand in order to use the code
```r
library(readxl); library(readr); library(dplyr); library(tidyr)
library(lubridate); library(openxlsx); library(openxlsx2); library(stringr)
```
