-- =====================================================================
-- SCHEMA CONVERSION: EPS.ADDRESS (Oracle → Azure SQL)
-- Conversion Date: 2026-05-27
-- Source: Oracle Table EPS.ADDRESS
-- Target: Azure SQL Table [EPS].[ADDRESS]
-- Status: COMPLETE
-- =====================================================================

/*
CONVERSION NOTES:
================================================================================

SOURCE CHARACTERISTICS (Oracle):
- Table: EPS.ADDRESS
- Columns: 36 (all mapped below)
- Partitioning: LIST by CHAIN_ID (100+ partitions including IMMEDIATE & DEFERRED)
- Storage: PCTFREE 10, PCTUSED 40, INITRANS 1, MAXTRANS 255, NO COMPRESSION
- Constraints: 3 Foreign Keys (DEFERRABLE - see notes)
- Supplemental Logging: ALL COLUMNS (audit trail)
- Primary Key: ADDRESS_PK (CHAIN_ID, ID) via unique index
- Tablespace: USERS (base), EPS_D (data partitions), EPS_X (index partitions)

CONVERSION STRATEGY:
- All 36 columns converted with field-level precision mapping
- All 3 foreign key constraints replicated (DEFERRABLE behavior noted)
- LIST partitioning (100+ partitions) COLLAPSED to non-partitioned table
  * Reason: Azure SQL does not support LIST partitioning
  * Alternative: Recommend nonclustered indexes on CHAIN_ID for partition elimination effect
  * Future: Implement RANGE partitioning by date if table grows >500GB
- Storage parameters removed (Azure-managed)
- Supplemental logging removed (Change Tracking alternative documented)
- Compression: None in Oracle → PAGE compression added in Azure (optimization)

KEY CONVERSION MAPPINGS:
- Oracle NUMBER → Azure NUMERIC (precision preserved)
- Oracle VARCHAR2(n) → Azure VARCHAR(n)
- Oracle CHAR(1) → Azure CHAR(1)
- Oracle DATE → Azure DATETIME
- Oracle TIMESTAMP(6) → Azure DATETIME2(6)
- Oracle DEFERRABLE INITIALLY DEFERRED → Azure standard FK (immediate validation)

CRITICAL ISSUES IDENTIFIED:
1. FOREIGN KEY DEFERRABILITY
   - Oracle: Constraints can be deferred until COMMIT
   - Azure SQL: ALL FK constraints are enforced immediately
   - Impact: Application code must ensure FK validity before INSERT/UPDATE
   - Action: Review and test transaction logic with FK dependencies

2. PARTITIONING SIMPLIFIED
   - Oracle: 100+ LIST partitions by CHAIN_ID (GEAGLE, ECOM, HANNAF, MEIJER, etc.)
   - Azure: Non-partitioned (LIST not supported)
   - Impact: CHAIN_ID filters no longer benefit from partition elimination
   - Action: Create nonclustered index on CHAIN_ID for same effect
   - Alternative: Implement RANGE partitioning in future (see gap analysis)

3. SUPPLEMENTAL LOGGING REMOVED
   - Oracle: Used for replication and audit trail
   - Azure: Enable Change Tracking if audit required
   - Impact: Loss of detailed logging unless Change Tracking enabled
   - Action: Run ALTER TABLE ... ENABLE CHANGE_TRACKING post-deployment

PARTITION DETAILS (Collapsed in conversion):
All 100+ LIST partitions by CHAIN_ID are now single non-partitioned table.
Partition mapping preserved in comments:

GEAGLE (102) | ECOM (99) | HANNAF (88) | MEIJER (128) | RXCOM (119080) | SHOPKO (180) | 
STLUKE (114147) | FREDS (70) | GUNDER (368) | WEBSCR (98) | DUMMY (999) | MEDSHP (377) | 
ACMEHQ (259) | SPRVAL (105240) | KMART (115) | WEIS (243) | SAFEWAY (168) | SAVMRT (171) | 
UNITEDS (205) | DAHLS (31) | FRUTH (73) | WINNDIXIE (256) | LONEST (119952) | ALBERT (439) | 
TRANSI (122893) | LOWELL (100366) | BEST (451) | MEDI (121094) | PHARMACARE (462) | 
GILLETTE (125200) | APOTHERCARY (125204) | LUNDSBY (464) | VELOCE (469) | PCHS (470) | 
HAGGEN (473) | BURKLOW (125408) | PHARMACA (474) | OUTRIGGERS (125022) | AVELLA (478) | 
DARBYS (111530) | WESTMAIN (117628) | HEALTHSCRIPTS (492) | WESTBURY_PHARMACY (119208) | 
INDIANA_UNIVERSITY_HEALTH (126801) | FRESENIUSMEDICALCARE (509) | EISNERMEDICAL (127148) | 
SULLIVANSPHARMACY (101135) | HOMETOWNSUPERMARKETS (127293) | CIRCLE_RXINC (114427) | 
JACKSONPACEPHARMACY (112858) | YORKPHARMACY (112122) | PHARMACYARTS (113303) | 
KENMOREPHARMACY (117207) | CAREMEDPHARMACY (127452) | AMSLERPHARMACY (114386) | 
BOICEVILLEPHARMACY (114404) | REDHOOKDRUGSTORE (117310) | SAVEONDRUGS (112513) | 
SETONMEDICALMANAGEMENT (116855) | REDCROSSPHARMACY (114584) | AKINSDRUGSTORE (114382) | 
SMITHSTREETPHARMACY (114604) | EAGLESCRIPTSAPOTHECARY (114540) | NEKOSDEDRICKSPHARMACY (114553) | 
LAURELHEIGHTSPHARMACY (112159) | AMBULATORYCARE (127704) | CARERXOFFSHORE (9999) | 
FLEXCAREPHARMACY (127837) | COVANCEPHARMACY (127845) | ARUNDELPHARMACY (127840) | 
KINSLEYDRUG (112863) | MEDICINECHESTPHARMACY (127866) | COLUMBIAVALLEY (127847) | 
COSTCO (523) | KELLERAPOTHECARY (112848) | PHILSPHARMACY (112670) | CUMBERLAND2PHARMACY (112137) | 
CUMBERLANDPHARMACY (125038) | TCUHEALTHCENTER (112840) | WENTWORTHDOUGLASS (127970) | 
ENTERPRISEBICHAIN (3000) | ANDOVERAPOTHECARY (121923) | LINDENWOODDRUG (122802) | 
GRUBBSPHARMACY (533) | NAMBEDRUGSLOSALAMOS (127979) | SARALANDPHARMACY (128060) | 
THEPRESCRIPTIONSHOP (111834) | SAMSCLUB (537) | CACTUSDRUG (128188) | SUPERVALUINC (541) | 
TRIUNITYPHARMACY (128775) | GELSONSMARKETS (544) | PRIMEMARTPHARMACY (128841) | 
SAUGERTIESPHARMACY (129437) | SAFEWAYHAGGEN (556) | GENRXCORPORATION (553) | WALGREENSCO (552) | 
NEIGHBORHOODHEALTHCARE (130727) | CENTRALVALLEYMEDICAL (121715) | PRIMARYHEALTHCARE (131622) | 
CANOHEALTH (616) | MOBIMEDSINC (623) | GUNDERSENDEGENBERGLUND (621) | COSTCOWESTFARGOPHARM (128677) | 
UNIONPACIFICRR (627) | GIANTEAGLETURNRXTESTING (625) | ALBSAFEWAY (624) | DOUGHERTYSPHARMACYINC (638) | 
DERMSERVLLC (639) | ROGERSVILLEPHARMACYLLC (137774) | LITTLECREEKDRUGSMITH (137791) | 
LITTLECREEKDRUGSOUTH (137792) | EXPRESSRX (647) | WESTERNPHARMACYGROUP (650) | 
EHRCC (540) | PDXQA4000 (4000) | PDXQA5000 (5000) | SELAUTOCHAIN5555 (5555) | 
ARCHQACHAIN6000 (6000) | CSQATESTCHAIN7002+ (multiple test chains) | EPSDEV7077+ (dev chains) | 
CSQATESTCHAIN8000-8105 (test chains) | CROSSCHAIN variants | DANTESCHAIN | JERRYSCHAIN | 
LILYSCHAIN | PERFORMANCECHAIN2000 (2000) | OTHER (DEFAULT)

================================================================================
*/

-- Main TABLE DDL
-- =====================================================================

CREATE TABLE [EPS].[ADDRESS] 
(
    [CHAIN_ID]                     NUMERIC(18,0)       NOT NULL,
    [ID]                           NUMERIC(18,0)       NOT NULL,
    [DELETED]                      CHAR(1)             NULL,
    [LAST_UPDATED]                 DATETIME            NULL,
    [ADDED]                        DATETIME            NULL,
    [UPDATED]                      DATETIME            NULL,
    [NHIN_ID]                      NUMERIC(18,0)       NULL,
    [ADDRESS_KEY]                  NUMERIC(18,0)       NULL,
    [ADDRESS_LINE1]                VARCHAR(255)        NULL,
    [ADDRESS_LINE2]                VARCHAR(255)        NULL,
    [ADDRESS_TYPE]                 NUMERIC(18,0)       NULL,
    [CITY]                         VARCHAR(35)         NULL,
    [CLEAN]                        CHAR(1)             NULL,
    [COUNTRY]                      VARCHAR(4)          NULL,
    [DEACTIVATION_DATE]            DATETIME            NULL,
    [ENDING_DATE]                  DATETIME            NULL,
    [VALID]                        CHAR(1)             NULL,
    [NOTE1A]                       VARCHAR(35)         NULL,
    [NOTE1B]                       VARCHAR(35)         NULL,
    [PO_BOX]                       CHAR(1)             NULL,
    [POSTAL_CODE]                  VARCHAR(15)         NULL,
    [STARTING_DATE]                DATETIME            NULL,
    [STATE]                        VARCHAR(2)          NULL,
    [WORK_AREA_CODE]               CHAR(3)             NULL,
    [WORK_PHONE]                   VARCHAR(7)          NULL,
    [HOME_AREA_CODE]               CHAR(3)             NULL,
    [HOME_PHONE]                   VARCHAR(7)          NULL,
    [ID_PATIENT]                   NUMERIC(18,0)       NULL,
    [ID_AAL]                       NUMERIC(18,0)       NULL,
    [CARE_OF]                      VARCHAR(30)         NULL,
    [COUNTY]                       VARCHAR(45)         NULL,
    [MAIL_STOP]                    VARCHAR(25)         NULL,
    [SHIPPING_ADDRESS]             VARCHAR(1)          NULL,
    [ADDRESS_IDENTIFIER]           VARCHAR(10)         NULL,
    [DEFAULT_DELIVERY_SITE]        VARCHAR(4)          NULL,
    [DEFAULT_ADDRESS]              VARCHAR(1)          NULL,
    [WORK_PHONE_UPDATED_DATE]      DATETIME2(6)        NULL,
    [HOME_PHONE_UPDATED_DATE]      DATETIME2(6)        NULL,
    
    -- PRIMARY KEY
    CONSTRAINT [ADDRESS_PK] 
        PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID]),
    
    -- FOREIGN KEY CONSTRAINTS
    -- NOTE: Azure SQL enforces FK constraints immediately (DEFERRABLE not supported)
    -- Oracle source had DEFERRABLE INITIALLY DEFERRED - meaning FK validation
    -- happened at COMMIT time, not at statement level. Azure validates at statement level.
    -- Application code must ensure FK validity before INSERT/UPDATE operations.
    
    CONSTRAINT [ADDRESS_FK_ESCHAIN] 
        FOREIGN KEY ([CHAIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID]),
    
    CONSTRAINT [ADDRESS_FK_ESSTORE]
        FOREIGN KEY ([CHAIN_ID], [NHIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_STORE] ([CHAIN_NHIN_ID], [STORE_NHIN_ID]),
    
    CONSTRAINT [ADDRESS_FK_PATIENT]
        FOREIGN KEY ([CHAIN_ID], [ID_PATIENT])
        REFERENCES [EPS].[PATIENT] ([CHAIN_ID], [ID])
)
WITH (DATA_COMPRESSION = PAGE);  -- Added for optimization (Oracle had NOCOMPRESS)

-- =====================================================================
-- POST-DEPLOYMENT RECOMMENDATIONS
-- =====================================================================

/*
1. CREATE RECOMMENDED INDEXES (Run after deployment):
   
   -- Replaces Oracle LIST partitioning benefit for CHAIN_ID filters
   CREATE NONCLUSTERED INDEX [IX_ADDRESS_CHAIN_ID]
   ON [EPS].[ADDRESS] ([CHAIN_ID])
   INCLUDE ([ID]);
   
   -- Fast patient address lookups
   CREATE NONCLUSTERED INDEX [IX_ADDRESS_ID_PATIENT]
   ON [EPS].[ADDRESS] ([ID_PATIENT])
   WHERE [ID_PATIENT] IS NOT NULL;
   
   -- Store-based address searches
   CREATE NONCLUSTERED INDEX [IX_ADDRESS_NHIN_ID]
   ON [EPS].[ADDRESS] ([NHIN_ID])
   INCLUDE ([CHAIN_ID]);
   
   -- Incremental load support
   CREATE NONCLUSTERED INDEX [IX_ADDRESS_LAST_UPDATED]
   ON [EPS].[ADDRESS] ([LAST_UPDATED])
   WHERE [LAST_UPDATED] IS NOT NULL;
   
   -- Optional: Address type filtering
   CREATE NONCLUSTERED INDEX [IX_ADDRESS_TYPE]
   ON [EPS].[ADDRESS] ([ADDRESS_TYPE])
   WHERE [ADDRESS_TYPE] IS NOT NULL;

2. ENABLE CHANGE TRACKING (if audit trail required):
   ALTER TABLE [EPS].[ADDRESS] ENABLE CHANGE_TRACKING;
   
   -- Later: Query tracked changes
   SELECT * FROM CHANGETABLE(CHANGES [EPS].[ADDRESS], @last_sync_version);

3. UPDATE STATISTICS (post-data load):
   UPDATE STATISTICS [EPS].[ADDRESS];
   EXEC sp_updatestats;

4. VALIDATE FOREIGN KEY CONSTRAINTS:
   -- Check for orphaned records (keys without matching parent)
   -- If found, correct data quality before applying FKs
   
   SELECT * FROM [EPS].[ADDRESS]
   WHERE [CHAIN_ID] NOT IN (
       SELECT [CHAIN_NHIN_ID] FROM [SEC_ADMIN].[EPS_SEC_CHAIN]);
   
   SELECT * FROM [EPS].[ADDRESS]
   WHERE [ID_PATIENT] IS NOT NULL
   AND ([CHAIN_ID], [ID_PATIENT]) NOT IN (
       SELECT [CHAIN_ID], [ID] FROM [EPS].[PATIENT]);

5. PARTITIONING FUTURE OPTIMIZATION:
   If table exceeds 500GB, implement RANGE partitioning by date:
   
   -- Example: RANGE partitioning by ADDED date (1 partition per month)
   ALTER TABLE [EPS].[ADDRESS] 
   ADD CONSTRAINT [PF_ADDRESS_ADDED_DATE] 
   AS RANGE LEFT FOR VALUES ('2024-01-01', '2024-02-01', ...);
   
   Benefits: Better table management, faster archival, improved query performance
   Drawback: Requires schema redesign, not as straightforward as Oracle

6. PERFORMANCE BASELINE:
   Establish metrics before production deployment:
   - Table size (current and growth rate)
   - Query plan for common WHERE clauses
   - FK constraint violation patterns
   - Lock contention (if high-volume concurrent access)

7. MONITORING & ALERTING:
   - Monitor table growth: SELECT [rows] FROM sys.dm_db_partition_stats WHERE object_id = OBJECT_ID('[EPS].[ADDRESS]')
   - Track FK violations: SELECT COUNT(*) WHERE FK_violation_detected
   - Verify no data loss post-migration
   - Monitor application error logs for FK constraint errors

8. MIGRATION VALIDATION:
   - Row count match between Oracle and Azure
   - Data type precision validation
   - Constraint definition verification
   - Query performance comparison (Oracle vs Azure results identical?)
   - Application integration testing (FK enforcement differences)

================================================================================
ORACLE SOURCE METADATA (For Reference):
================================================================================

STORAGE PARAMETERS (removed in Azure - all automatic):
- PCTFREE 10, PCTUSED 40, INITRANS 1, MAXTRANS 255
- NOCOMPRESS LOGGING (Azure uses PAGE compression for optimization)
- BUFFER_POOL DEFAULT, FLASH_CACHE DEFAULT, CELL_FLASH_CACHE DEFAULT

PARTITIONING (Oracle - 100+ LIST partitions by CHAIN_ID):
- All data partitions stored in TABLESPACE EPS_D
- All index partitions stored in TABLESPACE EPS_X
- Each CHAIN_ID value gets its own partition for physical isolation

SUPPLEMENTAL LOGGING (removed - not applicable to Azure):
- SUPPLEMENTAL LOG DATA (ALL) COLUMNS
- SUPPLEMENTAL LOG DATA (PRIMARY KEY) COLUMNS
- SUPPLEMENTAL LOG DATA (UNIQUE INDEX) COLUMNS
- SUPPLEMENTAL LOG DATA (FOREIGN KEY) COLUMNS
- Purpose: Replication and detailed auditing
- Azure Alternative: Enable CHANGE_TRACKING per recommendations above

PRIMARY KEY INDEX (ADDRESS_PK):
Oracle definition preserved in Azure:
- Index name: ADDRESS_PK (unique, clustered)
- Columns: (CHAIN_ID, ID)
- Type: LOCAL (partition-aligned in Oracle, n/a in non-partitioned Azure)
- Storage: PCTFREE 10, INITRANS 2, MAXTRANS 255, NOLOGGING, TABLESPACE EPS_X

================================================================================
*/

-- =====================================================================
-- CONVERSION COMPLETE
-- =====================================================================
-- 
-- Object:        EPS.ADDRESS
-- Type:          Table (36 columns, 3 FKs, 100+ partitions simplified)
-- Status:        READY FOR TESTING
-- Lines:         36 columns + 3 constraints + comments
-- Approval:      Pre-deployment checklist required
--
-- Dependencies:  [SEC_ADMIN].[EPS_SEC_CHAIN]
--                [SEC_ADMIN].[EPS_SEC_STORE]
--                [EPS].[PATIENT]
--                
-- Pre-Deploy:    1. Verify FK target tables exist
--                2. Check for data quality issues
--                3. Create recommended indexes
--                4. Test FK constraint enforcement
--
-- =====================================================================
