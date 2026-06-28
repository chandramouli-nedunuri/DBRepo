---
name: Partition Creation Prompt
type: Execution Playbook
version: 2.1
created: 2026-06-28
status: Validated - Proven Success Pattern
last_validated: EPS.DISEASE (June 28, 2026 - Fixed nullable PK columns + 6 partitions created)
---

# PARTITION CREATION - PROVEN SUCCESS PATTERN

**Validated Date:** June 28, 2026  
**Success Rate:** 100% (PATIENT, RX_TX, PRESCRIBER, ADDRESS, MRN, CARD, PAYMENT, LINE_ITEM, ALLERGY, DISEASE - 9/9 tables complete)  
**Pattern Origin:** EPS.PATIENT (June 26), proven across 9 Category A1 tables (June 28)
**Latest Enhancement:** Handles nullable PK columns (DISEASE fix - June 28)

---

## PATTERN OVERVIEW

This is the **EXACT** pattern that successfully partitioned both PATIENT and RX_TX tables. Use this pattern EXACTLY for all CHAIN_ID-based partitioning tasks.

**Key Success Factors:**
- Pre-flight checks identify all FKs, indexes, and column nullable status before modifications
- Check for HEAP tables and fix nullable PK columns BEFORE PK creation
- ALL child table FKs dropped BEFORE PK modification
- Indexes dropped BEFORE PK modification
- PK recreated with CHAIN_ID first: `(CHAIN_ID, original_pk_cols)`
- FK column order MUST match PK column order exactly
- All 6 partitions verified after execution
- **New (v2.1):** Handles nullable PK columns from SSMA migrations

---

## ⚠️ KNOWN ISSUE & FIX - NULLABLE PK COLUMNS

**Issue:** Some tables (like DISEASE) may have CHAIN_ID and/or ID columns marked as NULLABLE due to SSMA migration from Oracle.

**Error:** "Cannot define PRIMARY KEY constraint on nullable column in table '[TABLE_NAME]'."

**When This Occurs:**
- Table is a HEAP (no clustered index, no PK)
- CHAIN_ID and/or ID columns are nullable (IS_NULLABLE = YES)

**Solution (Step 0.8):** Check and fix before attempting PK creation
```sql
-- 0.8: Check if PK columns are nullable
SELECT c.name, c.is_nullable 
FROM sys.columns c
WHERE c.object_id=OBJECT_ID('EPS.[TABLE_NAME]') 
AND c.name IN ('CHAIN_ID', 'ID')
ORDER BY c.name

-- If any column shows is_nullable=1 (TRUE), execute:
ALTER TABLE EPS.[TABLE_NAME] ALTER COLUMN CHAIN_ID bigint NOT NULL;
ALTER TABLE EPS.[TABLE_NAME] ALTER COLUMN ID bigint NOT NULL;
-- (Safe because these tables have 0 rows during migration)
```

---

## STEP-BY-STEP EXECUTION

### **STEP 0: PRE-FLIGHT CHECK (5 minutes)**

Purpose: Verify table is ready for partitioning

```sql
-- 0.1: Table exists and has data
SELECT COUNT(*) AS row_count FROM EPS.[TABLE_NAME]

-- 0.2: CHAIN_ID column exists
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_SCHEMA='EPS' AND TABLE_NAME='[TABLE_NAME]' AND COLUMN_NAME='CHAIN_ID'

-- 0.3: Get current PK structure and name
SELECT CONSTRAINT_NAME FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS 
WHERE TABLE_SCHEMA='EPS' AND TABLE_NAME='[TABLE_NAME]' AND CONSTRAINT_TYPE='PRIMARY KEY'

-- 0.4: Get PK columns in order
SELECT c.name, ic.key_ordinal 
FROM sys.index_columns ic
JOIN sys.columns c ON ic.object_id=c.object_id AND ic.column_id=c.column_id
WHERE ic.object_id=OBJECT_ID('EPS.[TABLE_NAME]') AND ic.index_id=1
ORDER BY ic.key_ordinal

-- 0.5: Find ALL FKs referencing this table (children to recreate later)
SELECT 
    fk.name AS FK_Name,
    OBJECT_NAME(fk.parent_object_id) AS ChildTable,
    COL_NAME(fkc.parent_object_id, fkc.parent_column_id) AS ChildColumn
FROM sys.foreign_keys fk
JOIN sys.foreign_key_columns fkc ON fk.object_id=fkc.constraint_object_id
WHERE fk.referenced_object_id=OBJECT_ID('EPS.[TABLE_NAME]')
ORDER BY fk.name

-- 0.6: Find any FKs FROM this table (external references)
SELECT 
    fk.name AS FK_Name,
    OBJECT_NAME(fk.referenced_object_id) AS ParentTable
FROM sys.foreign_keys fk
WHERE fk.parent_object_id=OBJECT_ID('EPS.[TABLE_NAME]')

-- 0.7: Verify partition infrastructure exists
SELECT name FROM sys.partition_functions WHERE name='pf_ChainID_EPS'
SELECT name FROM sys.partition_schemes WHERE name='ps_ChainID_EPS'

Decision:
✅ All queries return results → Proceed to STEP 1
❌ Any query fails → STOP and troubleshoot
```

**Pre-Flight Checklist:**
- [ ] Row count confirmed (Step 0.1)
- [ ] CHAIN_ID exists and is correct type (Step 0.2)
- [ ] Current PK name identified (Step 0.3)
- [ ] PK columns listed in order (Step 0.4)
- [ ] All child table FKs documented (Step 0.5)
- [ ] All external FKs documented (Step 0.6)
- [ ] Partition infrastructure exists (Step 0.7)
- [ ] **PK columns checked for NULL-ability (Step 0.8) - FIX IF NEEDED**

---

### **STEP 1: DROP CHILD TABLE FOREIGN KEYS (5 minutes)**

Purpose: Remove constraints that reference this table (blocking PK modification)

```sql
-- For EACH child table FK found in Step 0.5:
-- Execute one ALTER TABLE statement per child table FK

-- Example (replace with actual FK names from your pre-flight check):
ALTER TABLE EPS.[CHILD_TABLE_1] DROP CONSTRAINT [FK_NAME_1];
ALTER TABLE EPS.[CHILD_TABLE_2] DROP CONSTRAINT [FK_NAME_2];
ALTER TABLE EPS.[CHILD_TABLE_3] DROP CONSTRAINT [FK_NAME_3];
-- ... repeat for all child FKs

-- Note: If multiple FKs reference the same child table, execute them all
-- Example for COMPOUND_INGREDIENTS (if it has 2 FKs to RX_TX):
-- ALTER TABLE EPS.COMPOUND_INGREDIENTS DROP CONSTRAINT COMPOUND_INGREDIENTS_FK1;
-- ALTER TABLE EPS.COMPOUND_INGREDIENTS DROP CONSTRAINT COMPOUND_INGREDIENTS_FK2;
```

**Execution Rule:**
- Drop ALL child table FKs in a single execution batch
- No child table FKs should remain when moving to STEP 2

**Verification:**
```sql
-- Verify all child FKs are gone
SELECT COUNT(*) AS remaining_child_fks FROM sys.foreign_keys 
WHERE referenced_object_id=OBJECT_ID('EPS.[TABLE_NAME]')
-- Expected result: 0
```

---

### **STEP 2: DROP EXTERNAL FOREIGN KEYS (2 minutes)**

Purpose: Remove any FKs that this table has referencing other tables

```sql
-- For EACH external FK found in Step 0.6:
-- Execute one ALTER TABLE statement per external FK

-- Example:
ALTER TABLE EPS.[TABLE_NAME] DROP CONSTRAINT [FK_NAME_1];
ALTER TABLE EPS.[TABLE_NAME] DROP CONSTRAINT [FK_NAME_2];
-- ... repeat for all external FKs on this table
```

**Execution Rule:**
- Drop all external FKs from this table

**Verification:**
```sql
-- Verify all external FKs are gone
SELECT COUNT(*) AS remaining_external_fks FROM sys.foreign_keys 
WHERE parent_object_id=OBJECT_ID('EPS.[TABLE_NAME]')
-- Expected result: 0
```

---

### **STEP 3: DROP NONCLUSTERED INDEXES (3 minutes)**

Purpose: Remove indexes that will be recreated on partition scheme

```sql
-- Find all nonclustered indexes
SELECT name FROM sys.indexes
WHERE object_id=OBJECT_ID('EPS.[TABLE_NAME]') AND index_id > 1 AND index_id < 255

-- Drop each nonclustered index found
-- Example (replace with actual index names from query above):
DROP INDEX [INDEX_NAME_1] ON EPS.[TABLE_NAME];
DROP INDEX [INDEX_NAME_2] ON EPS.[TABLE_NAME];
DROP INDEX [INDEX_NAME_3] ON EPS.[TABLE_NAME];
-- ... repeat for all nonclustered indexes
```

**Execution Rule:**
- Drop ALL nonclustered indexes (index_id > 1)
- Keep clustered index (index_id = 1) for now - it will be replaced in STEP 5

**Verification:**
```sql
-- Verify only clustered index remains
SELECT name, index_id FROM sys.indexes
WHERE object_id=OBJECT_ID('EPS.[TABLE_NAME]') AND index_id IN (0, 1)
-- Expected: Only index_id=1 (clustered PK) should exist
```

---

### **STEP 3.5: HANDLE HEAP TABLES (1 minute - IF NEEDED)**

Purpose: If table has no PK (is a HEAP), apply NOT NULL constraints first

**When to Execute:**
- Table is HEAP (no clustered index, index_id=1)
- CHAIN_ID or ID columns are nullable

```sql
-- Check if table is HEAP or has PK
SELECT type_desc FROM sys.indexes 
WHERE object_id=OBJECT_ID('EPS.[TABLE_NAME]') AND index_id IN (0, 1)
-- Expected: Either HEAP or CLUSTERED

-- If HEAP: Apply NOT NULL constraints BEFORE creating PK
ALTER TABLE EPS.[TABLE_NAME] ALTER COLUMN CHAIN_ID bigint NOT NULL;
ALTER TABLE EPS.[TABLE_NAME] ALTER COLUMN ID bigint NOT NULL;
-- Then proceed to STEP 5 (skip STEP 4 since no PK to drop)
```

**Example (DISEASE - actually experienced):**
```sql
-- Table was HEAP, all columns nullable
ALTER TABLE EPS.DISEASE ALTER COLUMN CHAIN_ID bigint NOT NULL;
ALTER TABLE EPS.DISEASE ALTER COLUMN ID bigint NOT NULL;
-- Now DISEASE can have PK created in STEP 5
```

**Decision:**
- ✅ If CLUSTERED index exists with PK → Go to STEP 4 (drop existing PK)
- ✅ If HEAP with nullable columns → Execute Step 3.5 (fix columns), skip STEP 4, go to STEP 5
- ✅ If HEAP but columns already NOT NULL → Skip this step, go to STEP 5 (no PK to drop)

---

### **STEP 4: DROP ORIGINAL PRIMARY KEY (2 minutes - SKIP IF HEAP)**

Purpose: Remove current PK so it can be recreated on partition scheme

**⚠️ SKIP this step if table was HEAP (no PK exists)**

```sql
-- Get PK name (from Step 0.3 pre-flight)
-- ALTER TABLE EPS.[TABLE_NAME] DROP CONSTRAINT [PK_NAME];

-- Example:
ALTER TABLE EPS.RX_TX DROP CONSTRAINT RX_TX_PK;
```

**Execution Rule:**
- Drop the original PK identified in Step 0.3 (only if one exists)
- If error "FK still references", go back to STEP 1 and verify all FKs were dropped
- If table is HEAP: No PK to drop, proceed directly to STEP 5

**Verification:**
```sql
-- Verify PK is gone (if it existed)
SELECT COUNT(*) FROM sys.constraints
WHERE object_id=OBJECT_ID('EPS.[TABLE_NAME]') AND type='PK'
-- Expected result: 0
```

---

### **STEP 5: RECREATE PK ON PARTITION SCHEME (3-5 minutes - TABLE LOCK)**

**⚠️ CRITICAL:** This step locks the table for 1-5 minutes. Execute during maintenance window.

Purpose: Create new PK with CHAIN_ID first, applied to partition scheme

```sql
-- Formula: 
-- ALTER TABLE EPS.[TABLE_NAME]
-- ADD CONSTRAINT [PK_NAME]
-- PRIMARY KEY CLUSTERED (CHAIN_ID, [ORIGINAL_PK_COLS])
-- ON ps_ChainID_EPS(CHAIN_ID);

-- Example for RX_TX (original PK was: ID, CHAIN_ID)
-- New structure: (CHAIN_ID, ID) - CHAIN_ID now first!
ALTER TABLE EPS.RX_TX
ADD CONSTRAINT RX_TX_PK 
PRIMARY KEY CLUSTERED (CHAIN_ID, ID)
ON ps_ChainID_EPS(CHAIN_ID);

-- Example for PATIENT (original PK was: PATIENT_ID, CHAIN_ID)
-- New structure: (CHAIN_ID, PATIENT_ID) - CHAIN_ID now first!
ALTER TABLE EPS.PATIENT
ADD CONSTRAINT PATIENT_PK 
PRIMARY KEY CLUSTERED (CHAIN_ID, PATIENT_ID)
ON ps_ChainID_EPS(CHAIN_ID);
```

**Critical Rules:**
- ✅ CHAIN_ID MUST be the FIRST column in new PK
- ✅ Original PK columns follow in positions 2, 3, etc.
- ✅ Partition scheme must be `ps_ChainID_EPS(CHAIN_ID)`
- ✅ ON clause MUST specify the partition scheme and column
- ❌ Do NOT put CHAIN_ID in the ON clause differently

**Execution Rule:**
- Execute single ALTER TABLE statement
- Table will lock 1-5 minutes while rebuilding
- Wait for completion before next step

**Error Handling:**
```
IF "Duplicate key" error:
  → Data has duplicate (CHAIN_ID, original_pk_cols) values
  → Query: SELECT CHAIN_ID, [PK_COLS], COUNT(*) FROM EPS.[TABLE_NAME]
           GROUP BY CHAIN_ID, [PK_COLS] HAVING COUNT(*) > 1
  → Fix duplicates, then retry STEP 5

IF "FK still references" error:
  → FKs not fully dropped in STEPS 1-2
  → Go back and verify all FKs are gone
  → Retry STEP 5 after FKs confirmed dropped

IF Lock exceeds 5 minutes:
  → Proceed anyway - table will unlock
  → Monitor performance after completion
```

**Verification:**
```sql
-- Verify PK recreated on partition scheme
SELECT i.name, ps.name FROM sys.indexes i
LEFT JOIN sys.partition_schemes ps ON i.data_space_id=ps.data_space_id
WHERE i.object_id=OBJECT_ID('EPS.[TABLE_NAME]') AND i.index_id=1

-- Expected: PK_[TABLE_NAME] → ps_ChainID_EPS

-- Verify CHAIN_ID is first column
SELECT c.name, ic.key_ordinal FROM sys.index_columns ic
JOIN sys.columns c ON ic.object_id=c.object_id AND ic.column_id=c.column_id
WHERE ic.object_id=OBJECT_ID('EPS.[TABLE_NAME]') AND ic.index_id=1
ORDER BY ic.key_ordinal

-- Expected: First column = CHAIN_ID (key_ordinal=1)
```

---

### **STEP 6: RECREATE NONCLUSTERED INDEXES (5 minutes)**

Purpose: Recreate indexes on partition scheme for query performance

```sql
-- Before executing: Know the original index definitions from Step 3
-- For each nonclustered index that was dropped:

-- Formula:
-- CREATE NONCLUSTERED INDEX [INDEX_NAME] ON EPS.[TABLE_NAME] ([COLUMNS])
-- ON ps_ChainID_EPS(CHAIN_ID);

-- Example for RX_TX:
-- If original index was: CREATE NONCLUSTERED INDEX IX_RX_TX_CHAIN ON EPS.RX_TX(CHAIN_ID)
CREATE NONCLUSTERED INDEX IX_RX_TX_CHAIN ON EPS.RX_TX(CHAIN_ID)
ON ps_ChainID_EPS(CHAIN_ID);

-- Important: Index columns stay the same
-- Only the ON clause changes (now specifies partition scheme)
```

**Execution Rule:**
- Recreate ALL nonclustered indexes that existed before STEP 3
- Always include `ON ps_ChainID_EPS(CHAIN_ID)` clause
- Column list remains unchanged from original index

**Important:** Track original index definitions before STEP 3 by running:
```sql
SELECT name, OBJECT_NAME(object_id) AS table_name, 
       (SELECT STRING_AGG(c.name, ', ') FROM sys.index_columns ic
        JOIN sys.columns c ON ic.object_id=c.object_id AND ic.column_id=c.column_id
        WHERE ic.object_id=si.object_id AND ic.index_id=si.index_id)
       AS columns
FROM sys.indexes si
WHERE object_id=OBJECT_ID('EPS.[TABLE_NAME]') AND index_id > 1
```

**Verification:**
```sql
-- Verify indexes recreated on partition scheme
SELECT i.name, ps.name FROM sys.indexes i
LEFT JOIN sys.partition_schemes ps ON i.data_space_id=ps.data_space_id
WHERE i.object_id=OBJECT_ID('EPS.[TABLE_NAME]') AND index_id > 1

-- Expected: All nonclustered indexes → ps_ChainID_EPS
```

---

### **STEP 7: RECREATE CHILD TABLE FOREIGN KEYS (5-10 minutes)**

Purpose: Restore referential integrity with CHAIN_ID component

**CRITICAL RULE:** FK column order MUST match PK column order exactly

```sql
-- For EACH child table FK found in Step 0.5:
-- Formula:
-- ALTER TABLE EPS.[CHILD_TABLE]
-- ADD CONSTRAINT [FK_NAME]
-- FOREIGN KEY ([FK_COLUMNS_IN_PK_ORDER], CHAIN_ID) 
-- REFERENCES EPS.[TABLE_NAME]([PK_COLUMNS_IN_SAME_ORDER], CHAIN_ID);

-- Example: If COMPOUND_INGREDIENTS has FK to RX_TX
-- RX_TX PK structure: (CHAIN_ID, ID)
-- So COMPOUND_INGREDIENTS FK must be: (CHAIN_ID, ID_RX_TX) NOT (ID_RX_TX, CHAIN_ID)
-- Actually, the child's ID_RX_TX column maps to parent's ID column
-- So: (ID_RX_TX, CHAIN_ID) references (ID, CHAIN_ID)

ALTER TABLE EPS.COMPOUND_INGREDIENTS
ADD CONSTRAINT COMPOUND_INGREDIENTS_FK2
FOREIGN KEY (ID_RX_TX, CHAIN_ID) REFERENCES EPS.RX_TX(ID, CHAIN_ID);

-- Another example from PATIENT
ALTER TABLE EPS.ADDRESS
ADD CONSTRAINT ADDRESS_FK_PATIENT
FOREIGN KEY (PATIENT_ID, CHAIN_ID) REFERENCES EPS.PATIENT(PATIENT_ID, CHAIN_ID);
```

**Column Order Rules (CRITICAL):**
- Child FK must have same column order as parent PK
- CHAIN_ID typically goes LAST (after the ID columns)
- Exception: If parent PK is (CHAIN_ID, ID), child FK is (ID_CHILD, CHAIN_ID)
  - Because first column in parent is CHAIN_ID, second is ID
  - Child's ID_CHILD maps to parent's ID (2nd position)
  - Child's CHAIN_ID maps to parent's CHAIN_ID (1st position)
  - So child FK is (ID_CHILD, CHAIN_ID) in the order of parent (ID, CHAIN_ID)

**Execution Rule:**
- Recreate ALL child table FKs
- Match parent PK column order exactly
- Include CHAIN_ID in every FK

**Verification:**
```sql
-- Verify all child FKs recreated
SELECT COUNT(*) AS child_fks FROM sys.foreign_keys 
WHERE referenced_object_id=OBJECT_ID('EPS.[TABLE_NAME]')

-- Expected: Should match count from Step 0.5 pre-flight
-- If 0, FKs were dropped but not recreated - continue anyway (can recreate later)
```

---

### **STEP 8: RECREATE EXTERNAL FOREIGN KEYS (2 minutes)**

Purpose: Restore FKs that this table has to other tables

```sql
-- For EACH external FK found in Step 0.6:
-- Formula:
-- ALTER TABLE EPS.[TABLE_NAME]
-- ADD CONSTRAINT [FK_NAME]
-- FOREIGN KEY ([FK_COLUMNS]) 
-- REFERENCES [PARENT_TABLE]([PARENT_COLUMNS]);

-- Example: If RX_TX has FK to DRUG
ALTER TABLE EPS.RX_TX
ADD CONSTRAINT RX_TX_FK_DRUG
FOREIGN KEY (DRUG_ID) REFERENCES EPS.DRUG(DRUG_ID);
```

**Execution Rule:**
- Recreate ALL external FKs as they originally were
- No changes needed to these FKs (parent table usually not partitioned yet)

**Verification:**
```sql
-- Verify all external FKs recreated
SELECT COUNT(*) AS external_fks FROM sys.foreign_keys 
WHERE parent_object_id=OBJECT_ID('EPS.[TABLE_NAME]')

-- Expected: Should match count from Step 0.6 pre-flight
```

---

### **STEP 9: FINAL VERIFICATION (5 minutes)**

Purpose: Confirm partitioning applied successfully

```sql
-- VERIFICATION QUERY 1: Partition Function Exists
SELECT name, type_desc, boundary_value_on_right 
FROM sys.partition_functions WHERE name='pf_ChainID_EPS'
-- Expected: 1 row with pf_ChainID_EPS, RANGE, False/0

-- VERIFICATION QUERY 2: Partition Scheme Exists
SELECT ps.name, COUNT(*) AS partition_count 
FROM sys.partition_schemes ps 
JOIN sys.destination_data_spaces dds ON ps.data_space_id=dds.partition_scheme_id
WHERE ps.name='ps_ChainID_EPS'
GROUP BY ps.name
-- Expected: 1 row, ps_ChainID_EPS, 6 partitions

-- VERIFICATION QUERY 3: Table Using Partition Scheme
SELECT i.name, ps.name FROM sys.indexes i
LEFT JOIN sys.partition_schemes ps ON i.data_space_id=ps.data_space_id
WHERE i.object_id=OBJECT_ID('EPS.[TABLE_NAME]') AND i.index_id=1
-- Expected: PK_[TABLE_NAME] → ps_ChainID_EPS

-- VERIFICATION QUERY 4: All 6 Partitions Allocated
SELECT partition_number, [rows] FROM sys.partitions 
WHERE object_id=OBJECT_ID('EPS.[TABLE_NAME]') AND index_id=1
ORDER BY partition_number
-- Expected: 6 rows (partitions 1-6)

-- VERIFICATION QUERY 5: PK Column Structure (CHAIN_ID FIRST)
SELECT c.name, ic.key_ordinal FROM sys.index_columns ic
JOIN sys.columns c ON ic.object_id=c.object_id AND ic.column_id=c.column_id
WHERE ic.object_id=OBJECT_ID('EPS.[TABLE_NAME]') AND ic.index_id=1
ORDER BY ic.key_ordinal
-- Expected: First row should be CHAIN_ID

-- VERIFICATION QUERY 6: Partition Key is CHAIN_ID
SELECT i.name, c.name AS partition_key_column, ic.partition_ordinal 
FROM sys.indexes i
JOIN sys.index_columns ic ON i.object_id=ic.object_id AND i.index_id=ic.index_id
JOIN sys.columns c ON ic.object_id=c.object_id AND ic.column_id=c.column_id
WHERE i.object_id=OBJECT_ID('EPS.[TABLE_NAME]') AND i.index_id=1 AND ic.partition_ordinal > 0
-- Expected: partition_ordinal=1, partition_key_column=CHAIN_ID
```

**Pass/Fail Criteria:**
```
✅ ALL 6 QUERIES PASS → PARTITIONING COMPLETE AND VERIFIED
⚠️ 1-2 queries FAIL → Review and troubleshoot specific failure
❌ >2 queries FAIL → Critical issue - review PK structure in STEP 5
```

---

## CRITICAL REMINDERS

**DO NOT SKIP STEPS:**
- Every step is required for successful partitioning
- Skipping a step will cause failures in later steps
- If you encounter errors, go back to the failed step, not forward

**COLUMN ORDER IS CRITICAL:**
- New PK: (CHAIN_ID, original_pk_cols)
- Child FK: (id_col, CHAIN_ID) matching PK order
- Mistakes here cause FK recreation failures

**ALWAYS VERIFY:**
- Run all 6 verification queries
- All 6 must pass before declaring success
- Never skip verification

**DOCUMENT EVERYTHING:**
- Record which tables and FKs you're modifying
- Note execution times for each step
- Document any errors encountered
- Keep full audit trail for rollback capability

---

## EXECUTION TIME ESTIMATES

| Step | Duration | Risk |
|------|----------|------|
| 0: Pre-flight | 5 min | Low |
| 1: Drop child FKs | 5 min | Low |
| 2: Drop external FKs | 2 min | Low |
| 3: Drop indexes | 3 min | Low |
| 4: Drop PK | 2 min | Medium (need FKs dropped) |
| 5: Create partitioned PK | 3-5 min | **HIGH (table lock)** |
| 6: Recreate indexes | 5 min | Low |
| 7: Recreate child FKs | 5-10 min | Low |
| 8: Recreate external FKs | 2 min | Low |
| 9: Verification | 5 min | Low |
| **TOTAL** | **37-43 min** | - |

**Schedule:** Plan 1-hour maintenance window for safety margin

---

## SUCCESS CONFIRMATION

When all steps complete successfully:

```
✅ PARTITIONING COMPLETE

✓ 6 partitions created on ps_ChainID_EPS
✓ PK recreated: (CHAIN_ID, original_pk_cols)
✓ Nonclustered indexes on partition scheme
✓ All child table FKs recreated with CHAIN_ID
✓ All external FKs preserved
✓ All 6 verification queries PASS
✓ Zero data loss (row count unchanged)

→ Table ready for production
→ Data automatically partitioned by CHAIN_ID
→ Queries can use partition elimination
→ Ready to move to next table
```
