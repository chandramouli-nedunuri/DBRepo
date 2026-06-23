-- =====================================================================
-- BATCH 13 QUICK EXECUTION GUIDE
-- =====================================================================
-- Step-by-step instructions for deploying BATCH 13 (26 tables)
-- Execution Date: 2026-06-10
-- =====================================================================

/*

╔════════════════════════════════════════════════════════════════════════╗
║              BATCH 13 DEPLOYMENT - QUICK START GUIDE                  ║
╚════════════════════════════════════════════════════════════════════════╝

BATCH 13 CONTENTS:
═══════════════════════════════════════════════════════════════════════════
✓ 26 tables: ADDRESS, PATIENT, ALLERGY, AUDIT, SECURITY, ADMIN
✓ 20 Foreign Key constraints (all internal, no external dependencies)
✓ 80+ columns in PATIENT (largest table)
✓ Full audit trails for main business tables
✓ Security chain management tables

═══════════════════════════════════════════════════════════════════════════

STEP 1: REVIEW PREREQUISITE BATCHES
═══════════════════════════════════════════════════════════════════════════

Batch 13 has NO external dependencies on other batches.
All 20 FKs reference tables within this batch only.

✓ Can be executed independently
✓ No need to wait for other batches
✓ Can be executed in any order relative to other batches

═══════════════════════════════════════════════════════════════════════════

STEP 2: CREATE TABLES
═══════════════════════════════════════════════════════════════════════════

File: BATCH_CREATE_TABLES_BATCH13.sql

Execution:
  1. Open: DB_Agent/output/project1/converted_sql/tables/
                 BATCH_CREATE_TABLES_BATCH13.sql
  2. Execute entire script
  3. Wait for completion (should be <5 seconds)
  4. Verify: SELECT COUNT(*) FROM sys.tables WHERE name LIKE '%ADDRESS%';

Expected Output:
  Creating 26 tables:
    1. [EPS].[ADDRESS]
    2. [EPS].[ADDRESS_AUDIT]
    3. [EPS].[ADMIN_UNLOCK_LOG]
    4. [EPS].[AUDIT_ACCESS_LOG]
    ... (26 total)

═══════════════════════════════════════════════════════════════════════════

STEP 3: LOAD DATA
═══════════════════════════════════════════════════════════════════════════

Source Data:
  - ADDRESS: From [EPS].[ADDRESS_OLD] (your current table)
  - PATIENT: From source migration or existing system
  - Other tables: From corresponding sources

Data Load Strategy:
  ✓ Load base tables first:
    1. SEC_ADMIN.EPS_SEC_CHAIN
    2. SEC_ADMIN.EPS_SEC_STORE
    3. SEC_ADMIN.EPS_SEC_STORE_IP_ADDRESS
    4. EPS.PATIENT
    5. EPS.VERSION_MAP

  ✓ Then dependent tables:
    - ADDRESS, ALLERGY, CARD, ADMIN_UNLOCK_LOG, etc.

Data Quality Checks:
  - Ensure CHAIN_ID values exist in EPS_SEC_CHAIN
  - Ensure ID_PATIENT values exist in PATIENT (where applicable)
  - Ensure NHIN_ID values exist in EPS_SEC_STORE (where applicable)
  - Check for NULL primary keys

═══════════════════════════════════════════════════════════════════════════

STEP 4: VALIDATE FK RELATIONSHIPS (OPTIONAL BUT RECOMMENDED)
═══════════════════════════════════════════════════════════════════════════

Before creating FKs, validate data:

Validate PATIENT references:
  SELECT COUNT(*) FROM EPS.ADDRESS
  WHERE [CHAIN_ID], [ID_PATIENT] NOT IN (
    SELECT [CHAIN_ID], [ID] FROM EPS.PATIENT
  );
  -- Should return: 0

Validate EPS_SEC_CHAIN references:
  SELECT COUNT(*) FROM EPS.ADDRESS
  WHERE [CHAIN_ID] NOT IN (
    SELECT [CHAIN_NHIN_ID] FROM SEC_ADMIN.EPS_SEC_CHAIN
  );
  -- Should return: 0

Validate EPS_SEC_STORE references:
  SELECT COUNT(*) FROM EPS.ADDRESS
  WHERE [NHIN_ID] IS NOT NULL
  AND ([CHAIN_ID], [NHIN_ID]) NOT IN (
    SELECT [CHAIN_NHIN_ID], [STORE_NHIN_ID]
    FROM SEC_ADMIN.EPS_SEC_STORE
  );
  -- Should return: 0

═══════════════════════════════════════════════════════════════════════════

STEP 5: CREATE FOREIGN KEY CONSTRAINTS
═══════════════════════════════════════════════════════════════════════════

File: BATCH_FK_RESTORATION_BATCH13.sql

Execution:
  1. Open: DB_Agent/output/project1/converted_sql/tables/
                 BATCH_FK_RESTORATION_BATCH13.sql
  2. Execute entire script
  3. Wait for completion (should be <2 seconds)
  4. Verify: SELECT * FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS
             WHERE CONSTRAINT_SCHEMA = 'EPS' OR 'SEC_ADMIN';

Expected Output:
  Creating 20 Foreign Key constraints:
    1. ADMIN_UNLOCK_LOG_FK_ESCHAIN
    2. ADMIN_UNLOCK_LOG_FK_PATIENT
    3. ADDRESS_FK_ESCHAIN
    4. ADDRESS_FK_ESSTORE
    5. ADDRESS_FK_PATIENT
    ... (20 total)

═══════════════════════════════════════════════════════════════════════════

STEP 6: CREATE INDEXES (OPTIONAL)
═══════════════════════════════════════════════════════════════════════════

Recommended indexes for performance:

-- For ADDRESS table (if needed)
CREATE NONCLUSTERED INDEX [IX_ADDRESS_CHAIN_ID]
ON [EPS].[ADDRESS] ([CHAIN_ID]) INCLUDE ([ID]);

CREATE NONCLUSTERED INDEX [IX_ADDRESS_ID_PATIENT]
ON [EPS].[ADDRESS] ([ID_PATIENT])
WHERE [ID_PATIENT] IS NOT NULL;

CREATE NONCLUSTERED INDEX [IX_ADDRESS_NHIN_ID]
ON [EPS].[ADDRESS] ([NHIN_ID]) INCLUDE ([CHAIN_ID]);

-- For PATIENT table (core lookups)
CREATE NONCLUSTERED INDEX [IX_PATIENT_NHIN_ID]
ON [EPS].[PATIENT] ([NHIN_ID]);

CREATE NONCLUSTERED INDEX [IX_PATIENT_LAST_NAME]
ON [EPS].[PATIENT] ([LAST_NAME], [FIRST_NAME]);

-- For ALLERGY table
CREATE NONCLUSTERED INDEX [IX_ALLERGY_PATIENT]
ON [EPS].[ALLERGY] ([CHAIN_ID], [ID_PATIENT]);

═══════════════════════════════════════════════════════════════════════════

STEP 7: UPDATE STATISTICS
═══════════════════════════════════════════════════════════════════════════

After data load:

UPDATE STATISTICS [EPS].[ADDRESS];
UPDATE STATISTICS [EPS].[PATIENT];
UPDATE STATISTICS [EPS].[ALLERGY];
EXEC sp_updatestats;

═══════════════════════════════════════════════════════════════════════════

STEP 8: TEST FK CONSTRAINTS
═══════════════════════════════════════════════════════════════════════════

Test that FKs work correctly:

-- This should FAIL (CHAIN_ID 99999 doesn't exist)
INSERT INTO [EPS].[ADDRESS]
(CHAIN_ID, ID, DELETED)
VALUES (99999, 1, 'N');
-- Expected: Msg 547 - FK violation

-- This should SUCCEED (assuming CHAIN_ID 102 exists)
INSERT INTO [EPS].[ADDRESS]
(CHAIN_ID, ID, DELETED)
VALUES (102, 999999, 'N');
-- Expected: Success

═══════════════════════════════════════════════════════════════════════════

TROUBLESHOOTING CHECKLIST
═══════════════════════════════════════════════════════════════════════════

Problem: "Table already exists" error
Solution: Drop existing tables first with:
  DROP TABLE IF EXISTS [EPS].[ADDRESS];
  GO

Problem: "Foreign key constraint cannot be created" error
Solution: Check for orphaned records:
  - Run data validation queries from STEP 4
  - Delete invalid records
  - Re-run FK creation script

Problem: "Invalid column name" error
Solution: Verify column names match exactly:
  - Check BATCH_CREATE_TABLES_BATCH13.sql for typos
  - Verify column data types match between tables
  - Run: EXEC sp_columns '[EPS].[ADDRESS]';

Problem: "Cannot insert NULL in NOT NULL column"
Solution: Check data load:
  - Ensure CHAIN_ID is always populated
  - Ensure ID is always populated
  - Validate source data for NULLs

═══════════════════════════════════════════════════════════════════════════

ADDITIONAL RESOURCES
═══════════════════════════════════════════════════════════════════════════

For detailed information, see:
- BATCH13_SUMMARY_AND_FK_DOCUMENTATION.sql
  (Complete table inventory and FK relationships)

For ADDRESS table specific information:
- Check repository memory files:
  /memories/repo/fk-validation-analysis.md
  /memories/repo/external-fk-dependencies.md

═══════════════════════════════════════════════════════════════════════════

ESTIMATED TIMING
═══════════════════════════════════════════════════════════════════════════

Task                              Time        Notes
──────────────────────────────────────────────────────────────────────────
Step 1: Review prerequisites       2 min      No action needed
Step 2: Create 26 tables          <1 min      Very fast
Step 3: Load data                 varies      Depends on volume
Step 4: Validate FKs              5 min       Includes queries
Step 5: Create 20 FKs            <1 min       Very fast
Step 6: Create indexes            5 min       Optional
Step 7: Update statistics         5 min       Recommended
Step 8: Test FKs                  5 min       Quick testing
──────────────────────────────────────────────────────────────────────────
TOTAL (excluding data load):     ~28 min

═══════════════════════════════════════════════════════════════════════════

NEXT STEPS AFTER BATCH 13
═══════════════════════════════════════════════════════════════════════════

After successful deployment:

1. Address Migration (if applicable):
   - Run BATCH_ADDRESS_DATA_MIGRATE.sql (if using new ADDRESS table)
   - Run BATCH_ADDRESS_FK_VALIDATE.sql
   - Run BATCH_ADDRESS_FK_RESTORE.sql

2. Application Testing:
   - Test INSERT/UPDATE/DELETE operations
   - Verify FK constraints are working
   - Check audit triggers fire correctly

3. Performance Tuning:
   - Analyze query plans
   - Add missing indexes
   - Consider partitioning strategy

4. Documentation:
   - Document any custom changes
   - Update runbooks
   - Update deployment procedures

═══════════════════════════════════════════════════════════════════════════

CONTACT & SUPPORT
═══════════════════════════════════════════════════════════════════════════

If you encounter issues:
1. Check TROUBLESHOOTING CHECKLIST above
2. Review table structure with: EXEC sp_help '[EPS].[ADDRESS]';
3. Review FK structure with: EXEC sp_fkeys '[EPS].[ADDRESS]';
4. Check constraint status: sp_helpconstraint '[EPS].[ADDRESS]';

═══════════════════════════════════════════════════════════════════════════
*/
