-- =====================================================================
-- SCHEMA CONVERSION: EPS.DW_DATA_EXTRACT_TIMESTAMP (Oracle → Azure SQL)
-- Conversion Date: 2026-05-28
-- Source: Oracle Table EPS.DW_DATA_EXTRACT_TIMESTAMP
-- Target: Azure SQL Table [EPS].[DW_DATA_EXTRACT_TIMESTAMP]
-- Status: COMPLETE
-- =====================================================================

/*
CONVERSION NOTES:
================================================================================

SOURCE CHARACTERISTICS (Oracle):
- Table: EPS.DW_DATA_EXTRACT_TIMESTAMP
- Columns: 2 (data warehouse extraction timestamps)
- Partitioning: None (non-partitioned)
- Storage: PCTFREE 10, PCTUSED 40, INITRANS 1, MAXTRANS 255, NO COMPRESSION
- Constraints: None (configuration table)
- Supplemental Logging: ALL COLUMNS
- Tablespace: USERS
- Special Features: SEGMENT CREATION DEFERRED

CONVERSION STRATEGY:
- 2 columns converted with precision mapping
- No partitioning to handle
- No constraints
- Storage parameters removed (Azure-managed)
- TIMESTAMP(9) precision preserved

KEY CONVERSION MAPPINGS:
- Oracle TIMESTAMP(9) → Azure DATETIME2(7) (7-digit fractional second precision - Azure max scale)

CONVERSION NOTES:
- This is a simple configuration/state table with no PK
- Contains extract timestamp boundaries for ETL synchronization
- Rarely updated; typically has 1 row or minimal data

POST-DEPLOYMENT ACTIONS:
1. Verify initial data load
2. Add data access control if needed
3. Monitor for application updates during ETL runs

================================================================================
*/

CREATE TABLE [EPS].[DW_DATA_EXTRACT_TIMESTAMP] (
    [PREVIOUS_EXTRACT_TIMESTAMP] DATETIME2(7),
    [CURRENT_EXTRACT_TIMESTAMP] DATETIME2(7)
);

-- SPECIAL NOTE: This configuration table has no primary key in source
-- If PK is needed for application logic, add: CONSTRAINT [PK_DW_TIMESTAMP] PRIMARY KEY
-- Otherwise, leave as flexible configuration table

GO
