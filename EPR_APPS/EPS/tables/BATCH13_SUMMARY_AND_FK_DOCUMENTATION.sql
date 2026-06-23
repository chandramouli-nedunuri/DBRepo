-- =====================================================================
-- BATCH 13 SUMMARY & FK DOCUMENTATION
-- =====================================================================
-- Quick reference for BATCH 13: 26 core tables
-- Execution Date: 2026-06-10
-- =====================================================================

/*
╔════════════════════════════════════════════════════════════════════════╗
║                    BATCH 13 TABLE INVENTORY                           ║
╚════════════════════════════════════════════════════════════════════════╝

BATCH 13 creates 26 tables covering:
✓ ADDRESS and ADDRESS_AUDIT
✓ ADMIN, AUDIT, and SECURITY tables
✓ ALLERGY management tables
✓ CARD management tables
✓ Core PATIENT and security tables
✓ FDB and reference tables

═══════════════════════════════════════════════════════════════════════════

TABLE CATEGORIES:

1. ADDRESS TABLES (2)
   - ADDRESS (Address records with FK to PATIENT, EPS_SEC_CHAIN, EPS_SEC_STORE)
   - ADDRESS_AUDIT (Audit trail)

2. AUDIT & SECURITY TABLES (8)
   - ADMIN_UNLOCK_LOG (Admin unlock requests - FKs to PATIENT, EPS_SEC_CHAIN)
   - AUDIT_ACCESS_LOG (Access logging - FK to EPS_SEC_CHAIN)
   - AUDIT_DBU_LOG (Database update logging)
   - AUDIT_MESSAGE_CONTENT (Message content auditing)
   - AUDIT_PHI_EVENT (PHI event tracking - FKs to PATIENT, EPS_SEC_CHAIN)
   - AUDIT_USER_LOG (User activity logging - FK to EPS_SEC_CHAIN)
   - EPS_SEC_LOG (Security event logging - FK to EPS_SEC_CHAIN)

3. ALLERGY TABLES (4)
   - ALLERGY (Allergy records - FKs to PATIENT, EPS_SEC_CHAIN, EPS_SEC_STORE)
   - ALLERGY_AUDIT (Audit trail)
   - FDB_PAT_ALLERGY_REACTION_AUDIT (Allergy reaction tracking - FK to PATIENT)

4. CARD TABLES (2)
   - CARD (Card records - FK to PATIENT)
   - CARD_AUDIT (Audit trail)

5. PRESCRIBER & ALT TABLES (2)
   - ALT_PRESCRIBER (Alternative prescriber info)
   - ALT_PRESCRIBER_AUDIT (Audit trail)

6. SECURITY & CHAIN TABLES (3)
   - EPS_SEC_CHAIN (Security chain master - BASE TABLE)
   - EPS_SEC_STORE (Store configuration - FK to EPS_SEC_CHAIN)
   - EPS_SEC_STORE_IP_ADDRESS (IP address restrictions - FK to EPS_SEC_STORE)

7. CORE BUSINESS TABLES (2)
   - PATIENT (Core patient table - BASE TABLE with 80+ columns)
   - LINK_TOKENS (Token management)

8. REFERENCE & LOOKUP TABLES (1)
   - VERSION_MAP (Version/release information - BASE TABLE)
   - KP_RXNUM_REF (RX number references)
   - MATCH_KEY (Patient matching - FK to PATIENT)
   - MEDICAL_CONDITION (Conditions - FKs to PATIENT, EPS_SEC_CHAIN)
   - MEDICAL_CONDITION_AUDIT_CSD_23800 (Audit trail)

═══════════════════════════════════════════════════════════════════════════

FOREIGN KEY RELATIONSHIPS:

Total FK Constraints: 20

Category Breakdown:
┌─────────────────────────────────────────────────────────────────────┐
│ TO PATIENT (10 FKs):                                                 │
│  1. ADMIN_UNLOCK_LOG → PATIENT ([CHAIN_ID], [ID_PATIENT])           │
│  2. ADDRESS → PATIENT ([CHAIN_ID], [ID_PATIENT])                    │
│  3. ALLERGY → PATIENT ([CHAIN_ID], [ID_PATIENT])                    │
│  4. AUDIT_PHI_EVENT → PATIENT ([CHAIN_ID], [ID_PATIENT])            │
│  5. CARD → PATIENT ([CHAIN_ID], [ID_PATIENT])                       │
│  6. FDB_PAT_ALLERGY_REACTION_AUDIT → PATIENT ([CHAIN_ID], [ID_...]) │
│  7. MATCH_KEY → PATIENT ([CHAIN_ID], [ID_PATIENT])                  │
│  8. MEDICAL_CONDITION → PATIENT ([CHAIN_ID], [ID_PATIENT])          │
│                                                                      │
├─────────────────────────────────────────────────────────────────────┤
│ TO EPS_SEC_CHAIN (7 FKs):                                            │
│  1. ADMIN_UNLOCK_LOG → EPS_SEC_CHAIN ([CHAIN_ID])                   │
│  2. ADDRESS → EPS_SEC_CHAIN ([CHAIN_ID])                            │
│  3. ALLERGY → EPS_SEC_CHAIN ([CHAIN_ID])                            │
│  4. AUDIT_ACCESS_LOG → EPS_SEC_CHAIN ([CHAIN_ID])                   │
│  5. AUDIT_PHI_EVENT → EPS_SEC_CHAIN ([CHAIN_ID])                    │
│  6. AUDIT_USER_LOG → EPS_SEC_CHAIN ([CHAIN_ID])                     │
│  7. EPS_SEC_LOG → EPS_SEC_CHAIN ([CHAIN_ID])                        │
│  8. EPS_SEC_STORE → EPS_SEC_CHAIN ([CHAIN_NHIN_ID])                 │
│  9. MEDICAL_CONDITION → EPS_SEC_CHAIN ([CHAIN_ID])                  │
│                                                                      │
├─────────────────────────────────────────────────────────────────────┤
│ TO EPS_SEC_STORE (2 FKs):                                            │
│  1. ADDRESS → EPS_SEC_STORE ([CHAIN_ID], [NHIN_ID])                 │
│  2. ALLERGY → EPS_SEC_STORE ([CHAIN_ID], [NHIN_ID])                 │
│                                                                      │
├─────────────────────────────────────────────────────────────────────┤
│ INTERNAL (1 FK):                                                     │
│  1. EPS_SEC_STORE_IP_ADDRESS → EPS_SEC_STORE                        │
│     ([CHAIN_NHIN_ID], [STORE_NHIN_ID])                              │
└─────────────────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════════════════════

BASE TABLES (No incoming FKs):
- EPS_SEC_CHAIN - Foundation for all chain-based partitioning
- PATIENT - Core patient master data (80+ columns)
- VERSION_MAP - System versioning reference

DEPENDENT TABLES (Have incoming FKs):
- Most others depend on PATIENT or EPS_SEC_CHAIN

LOAD SEQUENCE RECOMMENDATION:
1. EPS_SEC_CHAIN (base)
2. EPS_SEC_STORE (depends on EPS_SEC_CHAIN)
3. EPS_SEC_STORE_IP_ADDRESS (depends on EPS_SEC_STORE)
4. PATIENT (base)
5. All patient-dependent tables (ADDRESS, ALLERGY, CARD, etc.)
6. All chain-dependent tables
7. Audit and log tables

═══════════════════════════════════════════════════════════════════════════

SPECIAL NOTES:

✓ NO EXTERNAL DEPENDENCIES
  All 20 FKs reference tables within this batch (BATCH 13)
  No need to wait for other batches for these tables

⚠ ORACLE vs AZURE DIFFERENCES:
  - Oracle FKs were DEFERRABLE INITIALLY DEFERRED
  - Azure SQL enforces FKs immediately (at statement level)
  - Ensure data is clean before loading
  - Use NOCHECK during bulk loads if needed

⚠ DATA QUALITY ISSUE:
  - MEDICAL_CONDITION has ID_PATIENT column
  - No FK defined to PATIENT in original Oracle
  - BATCH 13 FK script ADDS this constraint (recommended)
  - Validate data quality before applying

✓ PARTITIONING NOTES:
  - Original Oracle: LIST partitioning by CHAIN_ID
  - Azure SQL: Use RANGE or non-partitioned
  - Recommend indexes on CHAIN_ID for partition elimination effect

═══════════════════════════════════════════════════════════════════════════

EXECUTION CHECKLIST:

Pre-Execution:
☐ All source tables converted and reviewed
☐ Oracle DDL extracted and converted to Azure SQL
☐ Data quality assessed
☐ Orphaned record checks completed

Phase 1 - Table Creation:
☐ Run BATCH_CREATE_TABLES_BATCH13.sql
☐ Verify 26 tables created successfully
☐ Check table structure matches requirements

Phase 2 - Data Load:
☐ Load data from ADDRESS_OLD or source
☐ Verify record counts
☐ Check for NULL primary keys
☐ Validate CHAIN_ID references exist

Phase 3 - FK Validation:
☐ Run data quality checks
☐ Verify no orphaned records
☐ Document any data issues

Phase 4 - FK Creation:
☐ Run BATCH_FK_RESTORATION_BATCH13.sql
☐ Verify all 20 FKs created successfully
☐ Test FK constraints with INSERT/UPDATE

Post-Execution:
☐ Create recommended indexes
☐ Update table statistics
☐ Run performance tests
☐ Document any modifications

═══════════════════════════════════════════════════════════════════════════

FILES LOCATION:

DB_Agent/output/project1/converted_sql/tables/

BATCH_CREATE_TABLES_BATCH13.sql
  └─ 26 CREATE TABLE statements (no FKs in table def)

BATCH_FK_RESTORATION_BATCH13.sql
  └─ 20 ALTER TABLE ADD CONSTRAINT statements
  └─ Verification queries
  └─ Comments on removed FKs and Oracle differences

═══════════════════════════════════════════════════════════════════════════

COMPARISON TO OTHER BATCHES:

Batch 1:  10 tables (CARRIER_ID_TEMP, CHAIN_RX_TX_SHARING_LINK, etc.)
Batch 2:  8 tables (DISEASE, EMAIL, FDB_PATIENT_ALLERGY, etc.)
Batch 3:  8 tables (FREE_FORM_ALLERGY, IDGEN, INTAKE_SOURCES, etc.)
Batch 4:  4 tables (MATCH_KEY, MEDICAL_CONDITION, MOD_PCM, MRN)
Batch 5:  7 tables (MTM_PATIENT_*, PACKAGE_INFO)
Batch 6:  7 tables (PATIENT_*, PAYMENT)
Batch 7:  6 tables (PATIENT_EMERGENCY_CONTACT, PATIENT_NOTES, etc.)
Batch 8:  8 tables (PATIENT_PROGRAM_*, PATIENT_SIGNATURES, etc.)
Batch 9:  7 tables (PRESCRIBER, PRIOR_ADVERSE_REACTION, PURGE_*, etc.)
Batch 10: 9 tables (RX_TX, RX_TX_AUDIT, RENAL_MEASUREMENT, etc.)
Batch 11: 10 tables (STAT_EXP, SIGNATURE, TELEPHONE, TP_LINK, etc.)
Batch 12: 9 tables (UNMERGE_DELETE_LIST, VERSION, VIAL_INFO, etc.)
Batch 13: 26 tables (ADDRESS, ADMIN_UNLOCK_LOG, ALLERGY, PATIENT, etc.)

TOTAL: 129 tables + 22 remaining = ~150 total EPS tables

═══════════════════════════════════════════════════════════════════════════
*/
