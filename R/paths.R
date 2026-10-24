# Data locations (read only; bloaterTS owns the master copies)
BLOATERTS_RAW <- "D:/pyprojects/bloaterTS/data/raw"
TRAWL_DIR     <- file.path(BLOATERTS_RAW, "trawl")
TOW_LIST_LM   <- file.path(BLOATERTS_RAW, "LM_tow_list_2005_2024.csv")
TOW_LIST_LH   <- file.path(BLOATERTS_RAW, "LH_tow_list_2004_2018.csv")
# Huron 2019-2024 (bloaterTS, obtained 2026-10; same fields as the USGS release, NULL = missing; user 2026-10-24)
HU_RECENT_OP    <- file.path(TRAWL_DIR, "OP_TR.OP_OP_target_huron.csv")
HU_RECENT_CATCH <- file.path(TRAWL_DIR, "TR_catch_Huron.csv")
OUTPUT_DIR    <- "D:/pyprojects/trawlcomp/output"
