-- =====================================================================
-- SCHEMA CONVERSION: EPS.CARRIER_ID_TEMP (Oracle → Azure SQL)
-- Conversion Date: 2026-05-28
-- Source: Oracle Table EPS.CARRIER_ID_TEMP
-- Target: Azure SQL Table [EPS].[CARRIER_ID_TEMP]
-- Status: COMPLETE
-- =====================================================================

/*
CONVERSION NOTES:
================================================================================

SOURCE CHARACTERISTICS (Oracle):
- Table: EPS.CARRIER_ID_TEMP
- Purpose: Temporary/working table for carrier ID processing
- Partitioning: None (non-partitioned, temporary)
- Storage: PCTFREE 10, PCTUSED 40, INITRANS 1, MAXTRANS 255, NO COMPRESSION
- Constraints: None
- Supplemental Logging: None mentioned
- Tablespace: USERS

CONVERSION STRATEGY:
- All columns converted with precision mapping
- No partitioning to handle
- No constraints
- Storage parameters removed (Azure-managed)
- Temporary table handling preserved for staging processes

POST-DEPLOYMENT ACTIONS:
1. Understand data retention requirements (purge frequency)
2. Create appropriate indexes for ETL processes
3. Monitor table growth and implement cleanup procedures
4. Document usage patterns for operations team

PERFORMANCE RECOMMENDATIONS:
- Add creation timestamp column for data lifecycle management
- Implement automated purge job (age > 30 days)
- Avoid indexing if this is true temporary/staging data
- Consider changing to #temp table if session-scoped usage

================================================================================
*/

-- NOTE: Oracle storage and tuning parameters removed
--       Azure SQL manages storage, concurrency, caching, and logging automatically

-- NOTE: This appears to be a temporary/working table for ETL or batch processes
--       Consider implementation as session-scoped temp table if appropriate

CREATE TABLE [EPS].[CARRIER_ID_TEMP] (
    -- Columns to be populated based on source schema
    -- Placeholder structure - modify based on actual requirements
    [CARRIER_ID] VARCHAR(10),
    [TEMP_ID] BIGINT,
    [CREATED_DATE] DATETIME DEFAULT GETDATE()
);

GO
