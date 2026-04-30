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
  filter(is.na(Price) | Price == 0,
         !is.na(`Total Weight`), `Total Weight` != 0) %>%
  select(Month, Abattoir, Tab, `Item Code`, `Item Description`,
         `Customer name`, `Total Weight`, Price) %>%
  arrange(Abattoir, Month, `Item Code`)

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
  Note = c(
    "", "", "", "", "", "", "", "",
    "Intercompany: same physical rows as 'Laverton – 6 Way'",
    "Intercompany: same physical rows as 'Laverton – Commodity FROZEN'",
    "Intercompany: subset of 'Laverton – Offal' (edible only)",
    ""
  )
) %>%
  mutate(
    `Difference (SOP - DB)` = `SOP Raw Weight (kg)` - `DB Weight (kg)`,
    Status = if_else(`Difference (SOP - DB)` == 0, "OK", "GAP")
  )

issues_summary_tbl <- tibble(
  Issue = c(
    "Bone – Item Code not in BM PRice sheet",
    "Bone – Run/Type not matched to any category",
    "Bone – Commodity: missing/invalid Storage",
    "Farm – FARM tab: no Carcass Price match",
    "Farm – BONE tab: no Bone Fee match",
    "Farm – KILL tab: no Kill Fee match",
    "VA – Missing or zero Price"
  ),
  `Rows Affected` = c(
    nrow(bone_no_price), nrow(bone_no_category), nrow(bone_missing_storage),
    nrow(farm_no_carcass), nrow(farm_no_bone_fee), nrow(farm_no_kill_fee),
    nrow(va_missing_price)
  ),
  `Weight Affected (kg)` = c(
    sum(bone_no_price$`Total Weight`,        na.rm = TRUE),
    sum(bone_no_category$`Total Weight`,     na.rm = TRUE),
    sum(bone_missing_storage$`Total Weight`, na.rm = TRUE),
    sum(farm_no_carcass$`Total Weight`,      na.rm = TRUE),
    sum(farm_no_bone_fee$`Total Weight`,     na.rm = TRUE),
    sum(farm_no_kill_fee$`Total Weight`,     na.rm = TRUE),
    sum(va_missing_price$`Total Weight`,     na.rm = TRUE)
  ),
  `Detail in Sheet` = rep("All Issues", 7),
  Fix = c(
    "Add Item Code to BM PRice sheet (Prices.xlsb)",
    "Update Run or Type in SOP Volumes, or add a new category rule",
    "Fill in Storage (CHILLED / FROZEN) in SOP Volumes",
    "Add Unicode + Abattoir + Period to Carcass Price sheet",
    "Add Unicode + Abattoir + Period to Bone Fee sheet",
    "Add Unicode + Abattoir + Period to Kill Fee sheet",
    "Fill in Price column in SOP Volumes (3.Meat Sales tab)"
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
  bone_no_price        %>% mutate(`Issue Type` = "No Price in BM PRice Sheet"),
  bone_no_category     %>% mutate(`Issue Type` = "Run/Type Not Matched to Any Category"),
  bone_missing_storage %>% mutate(`Issue Type` = "Commodity: Missing / Invalid Storage"),
  farm_no_price_all    %>% mutate(`Issue Type` = case_when(
    Tab == "FARM" ~ "No Carcass Price (FARM tab)",
    Tab == "BONE" ~ "No Bone Fee (BONE tab)",
    Tab == "KILL" ~ "No Kill Fee (KILL tab)",
    TRUE          ~ NA_character_
  )),
  va_missing_price     %>% mutate(`Issue Type` = "VA: Missing or Zero Price")
) %>%
  group_by(`Issue Type`, Abattoir, Tab,
           `Item Code`, `Item Description`, Run, Storage, Type, Group,
           `SOP Unicode`, `Customer name`, Price) %>%
  summarise(
    Units          = sum(as.numeric(Units), na.rm = TRUE),
    `Total Weight` = sum(`Total Weight`,    na.rm = TRUE),
    .groups = "drop"
  ) %>%
  select(`Issue Type`, Abattoir, Tab, `Item Code`, `Item Description`,
         Run, Storage, Type, Group, `SOP Unicode`, `Customer name`,
         Units, `Total Weight`, Price) %>%
  arrange(`Issue Type`, Abattoir, `Item Code`)

addWorksheet(gap_wb, "All Issues")
writeData(gap_wb, "All Issues", all_issues)

# ─── Sheet 3: Corowa Commodity Split Check (400000 + 400028 vs Combined) ─────

commodity_split_check <- volume_commodity_corowa %>%
  mutate(`Item Code` = str_trim(`Item Code`)) %>%
  group_by(`Item Code`) %>%
  summarise(Weight_Combined = sum(`Total Weight`, na.rm = TRUE), .groups = "drop") %>%
  full_join(
    volume_commodity_corowa_400028 %>%
      group_by(`Item Code`) %>%
      summarise(Weight_400028 = sum(`Total Weight`, na.rm = TRUE), .groups = "drop"),
    by = "Item Code"
  ) %>%
  full_join(
    volume_commodity_corowa_400000 %>%
      mutate(`Item Code` = str_trim(`Item Code`)) %>%
      group_by(`Item Code`) %>%
      summarise(Weight_400000 = sum(`Total Weight`, na.rm = TRUE), .groups = "drop"),
    by = "Item Code"
  ) %>%
  mutate(
    Weight_Combined = coalesce(Weight_Combined, 0),
    Weight_400028   = coalesce(Weight_400028,   0),
    Weight_400000   = coalesce(Weight_400000,   0),
    Difference      = Weight_Combined - (Weight_400000 + Weight_400028),
    Status          = if_else(abs(Difference) < 0.01, "OK", "MISMATCH")
  ) %>%
  arrange(desc(abs(Difference)))

addWorksheet(gap_wb, "Commodity Split")
writeData(gap_wb, "Commodity Split", commodity_split_check)

saveWorkbook(gap_wb, "Gap_Check.xlsx", overwrite = TRUE)
