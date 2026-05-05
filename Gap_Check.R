# Gap_Check.R
# Produces Gap_Check.xlsx — 4 sheets:
#   1. SOP vs DB   : weight comparison by category + issues summary
#   2. Bone Issues  : all bone gaps in one table (Issue Type column)
#   3. Farm Issues  : all farm gaps combined
#   4. VA Issues    : VA missing price
#
# Run AFTER Financial Calculating.qmd has been rendered.

library(dplyr)
library(openxlsx)
library(stringr)

gap_wb <- createWorkbook()

OFFAL_TYPES <- c("INEDIBLE", "OFFALS", "BACON CUTS")

# ─── Base frames (standardised) ─────────────────────────────────────────────

bone_base <- volume_bone_raw %>%
  mutate(
    `Item Code`    = str_trim(`Item Code`),
    Run            = toupper(Run),
    Type           = toupper(Type),
    Storage        = toupper(Storage),
    Abattoir       = toupper(Abattoir),
    Month          = toupper(Month),
    Tab            = toupper(Tab),
    `Total Weight` = as.numeric(`Total Weight`)
  )

va_base <- volume_va_raw %>%
  mutate(
    Price          = as.numeric(Price),
    Abattoir       = toupper(Abattoir),
    Month          = toupper(Month),
    Tab            = toupper(Tab),
    `Total Weight` = as.numeric(`Total Weight`)
  )

# ─── Issue data (shared across Sheet 1 and detail sheets) ───────────────────

bone_cols <- c("Month", "Abattoir", "Tab", "Item Code", "Item Description",
               "Run", "Storage", "Type", "Group", "Total Weight")

# Bone: no price
bone_no_price <- bone_base %>%
  anti_join(item_price_data %>% mutate(`Item Key` = str_trim(`Item Key`)),
            by = c("Item Code" = "Item Key")) %>%
  filter(!is.na(`Item Code`), `Item Code` != "",
         !is.na(`Total Weight`), `Total Weight` != 0) %>%
  select(all_of(bone_cols)) %>%
  arrange(Abattoir, Month, `Item Code`)

# Bone: no category match
bone_no_category <- bone_base %>%
  mutate(Category = case_when(
    Run == "TOTAL KILL" & Type %in% OFFAL_TYPES ~ "Offal",
    Run == "6 WAY"                              ~ "6 Way",
    Run == "SOW BONE"                           ~ "Sow",
    Run == "COMMODITY BONE"                     ~ "Commodity",
    TRUE                                        ~ NA_character_
  )) %>%
  filter(is.na(Category),
         !is.na(`Total Weight`), `Total Weight` != 0) %>%
  select(all_of(bone_cols)) %>%
  arrange(Abattoir, Month, Run, Type)

# Bone: commodity missing storage
bone_missing_storage <- bone_base %>%
  filter(Run == "COMMODITY BONE",
         is.na(Storage) | Storage == "" | !Storage %in% c("CHILLED", "FROZEN"),
         !is.na(`Total Weight`), `Total Weight` != 0) %>%
  select(all_of(bone_cols)) %>%
  arrange(Abattoir, Month, `Item Code`)

# Farm: check the actual pipeline output for missing prices.
# Starting from all_revenue_farm_calculated avoids reconstructing the join logic
# (including the FCOROWAWoolworths special case and the customer-template filter)
# and gives exactly what the pipeline could not price.
farm_no_price_all <- all_revenue_farm_calculated %>%
  filter(Tab %in% c("FARM", "BONE", "KILL"), is.na(Value),
         !is.na(`Total Weight`), `Total Weight` != 0) %>%
  select(Month, Abattoir, Tab, `SOP Unicode`, `Customer name`, Units, `Total Weight`) %>%
  arrange(Tab, Abattoir, Month, `SOP Unicode`)

farm_no_carcass  <- farm_no_price_all %>% filter(Tab == "FARM")
farm_no_bone_fee <- farm_no_price_all %>% filter(Tab == "BONE")
farm_no_kill_fee <- farm_no_price_all %>% filter(Tab == "KILL")

va_missing_price <- va_base %>%
  anti_join(item_price_data %>% mutate(`Item Key` = str_trim(`Item Key`)),
            by = c("Item Code" = "Item Key")) %>%
  filter(!is.na(`Item Code`), `Item Code` != "",
         !is.na(`Total Weight`), `Total Weight` != 0) %>%
  select(Month, Abattoir, Tab, `Item Code`, `Item Description`,
         `Customer name`, `Total Weight`) %>%
  arrange(Abattoir, Month, `Item Code`)

# VA: Item Codes in VA Sales with no brand mapping in VA_brand_data
va_no_brand <- volume_VA_price_calculated %>%
  anti_join(VA_brand_data %>% distinct(`Item Code`), by = "Item Code") %>%
  filter(!is.na(`Total Weight`), `Total Weight` > 0) %>%
  select(Month, Abattoir, Tab, `Item Code`, `Item Description`,
         `Customer name`, `Total Weight`) %>%
  arrange(Abattoir, Month, `Item Code`)

# Farm: same Unicode mapped to multiple Item Codes
farm_multi_item_code <- volume_farm_raw %>%
  mutate(
    Unicode        = toupper(Unicode),
    Abattoir       = toupper(Abattoir),
    Month          = toupper(Month),
    Tab            = toupper(Tab),
    Units          = as.numeric(Units),
    `Total Weight` = as.numeric(`Total Weight`)
  ) %>%
  group_by(Unicode, Abattoir, Month, Tab) %>%
  filter(n_distinct(`Item Code`) > 1) %>%
  ungroup() %>%
  filter(!is.na(`Total Weight`), `Total Weight` != 0) %>%
  rename(`SOP Unicode` = Unicode) %>%
  select(Month, Abattoir, Tab, `SOP Unicode`, `Item Code`, `Item Description`,
         Units, `Total Weight`) %>%
  arrange(Abattoir, Month, `SOP Unicode`)

# Commodity 400028: VA procurement Item Codes with no matching bone entry in Corowa
commodity_va_not_in_bone <- anti_join(
  volume_commodity_corowa_400028 %>% mutate(`Item Code` = str_trim(`Item Code`)),
  volume_commodity_corowa        %>% mutate(`Item Code` = str_trim(`Item Code`)) %>%
    distinct(`Item Code`),
  by = "Item Code"
) %>%
  filter(!is.na(`Total Weight`), `Total Weight` != 0) %>%
  mutate(across(any_of(c("Units", "Avg Weight", "Total Weight")), as.numeric)) %>%
  arrange(`Item Code`)

# Expense: helper to check missing packaging / pallet prices
check_packaging <- function(data, price_col) {
  data %>%
    left_join(
      packaging_price_data %>%
        filter(VARIANT == 4) %>%
        select(BOM, all_of(price_col)) %>%
        mutate(BOM = as.character(BOM)),
      by = c("Item Code" = "BOM")
    ) %>%
    filter(`Total Weight` > 0,
           is.na(.data[[price_col]]) | .data[[price_col]] == 0) %>%
    group_by(`Item Code`, `Item Description`) %>%
    summarise(`Total Weight` = sum(`Total Weight`, na.rm = TRUE), .groups = "drop") %>%
    arrange(`Item Code`)
}

expense_va_packaging               <- volume_expense_VA_sales_packaging_calculated %>%
  filter(`Total Weight` > 0, is.na(Price) | Price == 0) %>%
  group_by(`Item Code`, `Item Description`) %>%
  summarise(`Total Weight` = sum(`Total Weight`, na.rm = TRUE), .groups = "drop") %>%
  arrange(`Item Code`)

expense_lav_edible_offal_packaging <- check_packaging(laverton_edible_offal_volume_data, "PACKAGING")
expense_lav_edible_offal_pallet    <- check_packaging(laverton_edible_offal_volume_data, "PALLETS")
expense_lav_6way_packaging         <- check_packaging(laverton_volume_6way_data,         "PACKAGING")
expense_lav_sow_packaging          <- check_packaging(laverton_volume_sow_data,           "PACKAGING")
expense_lav_commodity_packaging    <- check_packaging(laverton_volume_commodity_data,     "PACKAGING")

# ─── Sheet 1: SOP vs DB ──────────────────────────────────────────────────────

sop_wt <- function(df) sum(as.numeric(df$`Total Weight`), na.rm = TRUE)
db_wt  <- function(...) {
  bind_rows(...) %>%
    summarise(w = sum(as.numeric(`Total Weight`), na.rm = TRUE)) %>%
    pull(w)
}

comparison_tbl <- tibble(
  Category = c(
    "Corowa – Offal (Inedible + Edible)",
    "Laverton – Offal (Inedible + Edible)",
    "Corowa – 6 Way",
    "Laverton – 6 Way",
    "Laverton – Sow",
    "Corowa – Commodity (400000 + 400028)",
    "Laverton – Commodity CHILLED",
    "Laverton – Commodity FROZEN",
    "Meat Trade – 6 Way (Laverton → Corowa)",
    "Meat Trade – Commodity FROZEN (Laverton → Corowa)",
    "Meat Trade – Edible Offal (Laverton → Corowa)",
    "VA / Meat Sales"
  ),
  `SOP Raw Weight (kg)` = c(
    sop_wt(bone_base %>% filter(Abattoir == "COROWA",   Run == "TOTAL KILL",    Type %in% OFFAL_TYPES)),
    sop_wt(bone_base %>% filter(Abattoir == "LAVERTON", Run == "TOTAL KILL",    Type %in% OFFAL_TYPES)),
    sop_wt(bone_base %>% filter(Abattoir == "COROWA",   Run == "6 WAY")),
    sop_wt(bone_base %>% filter(Abattoir == "LAVERTON", Run == "6 WAY")),
    sop_wt(bone_base %>% filter(Abattoir == "LAVERTON", Run == "SOW BONE")),
    sop_wt(bone_base %>% filter(Abattoir == "COROWA",   Run == "COMMODITY BONE")),
    sop_wt(bone_base %>% filter(Abattoir == "LAVERTON", Run == "COMMODITY BONE", Storage == "CHILLED")),
    sop_wt(bone_base %>% filter(Abattoir == "LAVERTON", Run == "COMMODITY BONE", Storage == "FROZEN")),
    sop_wt(bone_base %>% filter(Abattoir == "LAVERTON", Run == "6 WAY")),           # same rows as Laverton 6 Way
    sop_wt(bone_base %>% filter(Abattoir == "LAVERTON", Run == "COMMODITY BONE", Storage == "FROZEN")),  # same as Laverton FRZ
    sop_wt(bone_base %>% filter(Abattoir == "LAVERTON", Run == "TOTAL KILL",    Type %in% c("OFFALS", "BACON CUTS"))),
    sop_wt(va_base %>% filter(Service == "VA Sales"))
  ),
  `DB Weight (kg)` = c(
    db_wt(volume_offal_corowa),
    db_wt(volume_offal_laverton),
    db_wt(volume_6way_sow_corowa  %>% filter(`Customer Group` == "6 Way")),
    db_wt(volume_6way_sow_laverton %>% filter(`Customer Group` == "6 Way")),
    db_wt(volume_6way_sow_laverton %>% filter(`Customer Group` == "Sow")),
    db_wt(volume_commodity_corowa_400000_grouped, volume_commodity_corowa_400028_grouped),
    db_wt(volume_commodity_laverton_chil),
    db_wt(volume_commodity_laverton_frz),
    db_wt(volume_meat_trade_6way),
    db_wt(volume_meat_trade_commodity),
    db_wt(volume_meat_trade_edible_offal),
    db_wt(volume_VA_price_calculated)
  ),
)

issues_summary_tbl <- tibble(
  Category = c(rep("Revenue", 10), rep("Expense", 6)),
  Issue = c(
    "Bone – Item Code not in BM PRice sheet",
    "Bone – Run/Type not matched to any category",
    "Bone – Commodity: missing/invalid Storage",
    "Farm – FARM tab: no Carcass Price match",
    "Farm – BONE tab: no Bone Fee match",
    "Farm – KILL tab: no Kill Fee match",
    "VA – Item Code not in BM Price sheet",
    "VA – Item Code not in Brand Mapping",
    "Farm – Same Unicode has multiple Item Codes",
    "Commodity – VA Procurement Item not in Bone",
    "Expense – VA Sales: Missing Packaging Price",
    "Expense – Laverton Edible Offal: Missing Packaging Price",
    "Expense – Laverton Edible Offal: Missing Pallet Price",
    "Expense – Laverton 6 Way: Missing Packaging Price",
    "Expense – Laverton Sow: Missing Packaging Price",
    "Expense – Laverton Commodity: Missing Packaging Price"
  ),
  `Rows Affected` = c(
    nrow(bone_no_price), nrow(bone_no_category), nrow(bone_missing_storage),
    nrow(farm_no_carcass), nrow(farm_no_bone_fee), nrow(farm_no_kill_fee),
    nrow(va_missing_price), nrow(va_no_brand),
    nrow(farm_multi_item_code), nrow(commodity_va_not_in_bone),
    nrow(expense_va_packaging), nrow(expense_lav_edible_offal_packaging),
    nrow(expense_lav_edible_offal_pallet), nrow(expense_lav_6way_packaging),
    nrow(expense_lav_sow_packaging), nrow(expense_lav_commodity_packaging)
  ),
  `Weight Affected (kg)` = c(
    sum(bone_no_price$`Total Weight`,                  na.rm = TRUE),
    sum(bone_no_category$`Total Weight`,               na.rm = TRUE),
    sum(bone_missing_storage$`Total Weight`,           na.rm = TRUE),
    sum(farm_no_carcass$`Total Weight`,                na.rm = TRUE),
    sum(farm_no_bone_fee$`Total Weight`,               na.rm = TRUE),
    sum(farm_no_kill_fee$`Total Weight`,               na.rm = TRUE),
    sum(va_missing_price$`Total Weight`,               na.rm = TRUE),
    sum(va_no_brand$`Total Weight`,                    na.rm = TRUE),
    sum(farm_multi_item_code$`Total Weight`,           na.rm = TRUE),
    sum(commodity_va_not_in_bone$`Total Weight`,       na.rm = TRUE),
    sum(expense_va_packaging$`Total Weight`,               na.rm = TRUE),
    sum(expense_lav_edible_offal_packaging$`Total Weight`, na.rm = TRUE),
    sum(expense_lav_edible_offal_pallet$`Total Weight`,    na.rm = TRUE),
    sum(expense_lav_6way_packaging$`Total Weight`,         na.rm = TRUE),
    sum(expense_lav_sow_packaging$`Total Weight`,          na.rm = TRUE),
    sum(expense_lav_commodity_packaging$`Total Weight`,    na.rm = TRUE)
  ),
  `Detail in Sheet` = rep("All Issues", 16),
  Fix = c(
    "Add Item Code to BM PRice sheet (Prices.xlsb)",
    "Update Run or Type in SOP Volumes, or add a new category rule",
    "Fill in Storage (CHILLED / FROZEN) in SOP Volumes",
    "Add Unicode + Abattoir + Period to Carcass Price sheet",
    "Add Unicode + Abattoir + Period to Bone Fee sheet",
    "Add Unicode + Abattoir + Period to Kill Fee sheet",
    "Add Item Code to BM Price sheet (Prices.xlsb)",
    "Add Item Code to VA Brand mapping (Master Data – VA sheet)",
    "Fix Unicode or Item Code mapping in SOP Volumes (Farm tab)",
    "Add Item Code to bone commodity tab in SOP Volumes",
    "Add Item Code to packaging price data",
    "Add Item Code to packaging price data",
    "Add Item Code to pallet price data",
    "Add Item Code to packaging price data",
    "Add Item Code to packaging price data",
    "Add Item Code to packaging price data"
  )
)

# Write Sheet 1 with two sections separated by a blank row gap
addWorksheet(gap_wb, "SOP vs DB")
writeData(gap_wb, "SOP vs DB",
          data.frame(x = "=== SOP Volume vs Database — Weight Comparison (kg) ==="),
          startRow = 1, colNames = FALSE)
writeData(gap_wb, "SOP vs DB", comparison_tbl, startRow = 2)

sec2_start <- nrow(comparison_tbl) + 5   # 2 header + nrows + 2 blank gap rows + 1
writeData(gap_wb, "SOP vs DB",
          data.frame(x = "=== Issues Found: SOP Rows That Did Not Make It Into the Database ==="),
          startRow = sec2_start, colNames = FALSE)
writeData(gap_wb, "SOP vs DB", issues_summary_tbl, startRow = sec2_start + 1)

# ─── Sheet 2: All Issues (Bone + Farm + VA combined) ─────────────────────────

all_issues <- bind_rows(
  # Revenue issues
  bone_no_price        %>% mutate(`Revenue Related Issue` = "No Price in BM PRice Sheet"),
  bone_no_category     %>% mutate(`Revenue Related Issue` = "Run/Type Not Matched to Any Category"),
  bone_missing_storage %>% mutate(`Revenue Related Issue` = "Commodity: Missing / Invalid Storage"),
  farm_no_price_all    %>% mutate(`Revenue Related Issue` = case_when(
    Tab == "FARM" ~ "No Carcass Price (FARM tab)",
    Tab == "BONE" ~ "No Bone Fee (BONE tab)",
    Tab == "KILL" ~ "No Kill Fee (KILL tab)",
    TRUE          ~ NA_character_
  )),
  va_missing_price          %>% mutate(`Revenue Related Issue` = "VA: Item Code Not in BM Price Sheet"),
  va_no_brand               %>% mutate(`Revenue Related Issue` = "VA: Item Code Not in Brand Mapping"),
  farm_multi_item_code      %>% mutate(`Revenue Related Issue` = "Farm: Same Unicode Has Multiple Item Codes"),
  commodity_va_not_in_bone  %>% mutate(`Revenue Related Issue` = "Commodity: VA Procurement Item Not in Commodity Data"),
  # Expense issues
  expense_va_packaging               %>% mutate(`Expense Related Issue` = "Missing Packaging Price – VA Sales"),
  expense_lav_edible_offal_packaging %>% mutate(`Expense Related Issue` = "Missing Packaging Price – Laverton Edible Offal"),
  expense_lav_edible_offal_pallet    %>% mutate(`Expense Related Issue` = "Missing Pallet Price – Laverton Edible Offal"),
  expense_lav_6way_packaging         %>% mutate(`Expense Related Issue` = "Missing Packaging Price – Laverton 6 Way"),
  expense_lav_sow_packaging          %>% mutate(`Expense Related Issue` = "Missing Packaging Price – Laverton Sow"),
  expense_lav_commodity_packaging    %>% mutate(`Expense Related Issue` = "Missing Packaging Price – Laverton Commodity")
) %>%
  mutate(Units = as.numeric(Units)) %>%
  group_by(`Revenue Related Issue`, `Expense Related Issue`, Abattoir, Tab,
           `Item Code`, `Item Description`, Run, Storage, Type, Group,
           `SOP Unicode`, `Customer name`) %>%
  summarise(
    Units          = sum(as.numeric(Units), na.rm = TRUE),
    `Total Weight` = sum(`Total Weight`,    na.rm = TRUE),
    .groups = "drop"
  ) %>%
  select(`Revenue Related Issue`, `Expense Related Issue`, Abattoir, Tab,
         `Item Code`, `Item Description`, Run, Storage, Type, Group,
         `SOP Unicode`, `Customer name`, Units, `Total Weight`) %>%
  arrange(`Revenue Related Issue`, `Expense Related Issue`, Abattoir, `Item Code`)

addWorksheet(gap_wb, "All Issues")
writeData(gap_wb, "All Issues", all_issues)

saveWorkbook(gap_wb, "Gap_Check.xlsx", overwrite = TRUE)
