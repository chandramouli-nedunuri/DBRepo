# PARTITION IMPLEMENTATION - VISUAL PROCESS FLOW

## Complete Process: Step 1 → Verification Complete

```
╔════════════════════════════════════════════════════════════════════════════════╗
║                    PARTITION IMPLEMENTATION PROCESS                            ║
║                         By CHAIN_ID Strategy                                   ║
╚════════════════════════════════════════════════════════════════════════════════╝


PHASE 1: PRE-EXECUTION ANALYSIS (10-15 min)
═══════════════════════════════════════════════════════════════════════════════

Step 1.1: Table Exists?
├─ Query: SELECT COUNT(*) FROM EPS.[TABLE_NAME]
├─ Expected: Row count ≥ 0
└─ Decision: ✅ Proceed / ❌ STOP (table not found)

    ↓ YES

Step 1.2: CHAIN_ID Column Exists?
├─ Query: SELECT CHAIN_ID FROM INFORMATION_SCHEMA.COLUMNS
├─ Expected: INT or BIGINT, NOT NULL optional
└─ Decision: ✅ Proceed / ❌ STOP (cannot partition without CHAIN_ID)

    ↓ YES

Step 1.3: Primary Key Exists?
├─ Query: SELECT CONSTRAINT_NAME WHERE CONSTRAINT_TYPE = 'PRIMARY KEY'
├─ Expected: One PK constraint name
└─ Decision: ✅ Proceed / ❌ STOP (no PK - cannot partition)

    ↓ YES

Step 1.4: Get PK Column Structure
├─ Query: Get all columns in PK order
├─ Record: Original structure (e.g., ID, RX_COM_ID)
└─ Need for Phase 3: Create new PK with CHAIN_ID first

    ↓

Step 1.5: Identify All Foreign Keys
├─ Query: SELECT name FROM sys.foreign_keys WHERE parent_object_id OR referenced_object_id
├─ Record: All FK names and type (internal/external)
└─ Need for Phase 2: Drop FKs before PK modification

    ↓

Step 1.6: Verify Partition Infrastructure
├─ Query: Check sys.partition_functions (pf_ChainID_EPS)
├─ Query: Check sys.partition_schemes (ps_ChainID_EPS)
├─ Expected: Both must exist (one-time setup only)
└─ Decision: ✅ Proceed / ❌ STOP (infrastructure not found)

    ↓ ALL CHECKS PASS


PHASE 2: FOREIGN KEY MANAGEMENT (5-10 min)
═══════════════════════════════════════════════════════════════════════════════

Step 2.1: Drop Child Table FKs
├─ For each FK where [TABLE_NAME] is REFERENCED:
├─ Execute: ALTER TABLE [CHILD_TABLE] DROP CONSTRAINT [FK_NAME]
├─ Expected: Success (FKs removed)
└─ Record: Which FKs were dropped

    ↓

Step 2.2: Drop This Table's External FKs
├─ For each FK where [TABLE_NAME] is PARENT:
├─ Execute: ALTER TABLE [TABLE_NAME] DROP CONSTRAINT [FK_NAME]
├─ Expected: Success (FKs removed from this table)
└─ Record: Which FKs from this table were dropped

    ↓ ALL FKs DROPPED


PHASE 3: PRIMARY KEY MODIFICATION (2-5 min, TABLE LOCKED)
═══════════════════════════════════════════════════════════════════════════════

⚠️  WARNING: TABLE WILL BE LOCKED DURING THIS PHASE ⚠️

Step 3.1: Drop Original Primary Key
├─ Execute: ALTER TABLE [TABLE_NAME] DROP CONSTRAINT [PK_NAME]
├─ Expected: Success
├─ Error Handling: If "referenced by FK" → Go back to Phase 2
└─ Record: PK dropped at [TIME]

    ↓

Step 3.2: Create Partitioned Primary Key
├─ Build: ALTER TABLE [TABLE_NAME] ADD CONSTRAINT [PK_NAME] 
│         PRIMARY KEY CLUSTERED (CHAIN_ID, [ORIGINAL_PK_COLS])
│         ON ps_ChainID_EPS(CHAIN_ID)
├─ Execute Query
├─ Expected: Success (table will be locked 1-5 min)
├─ Error "Duplicate key": Data has duplicate (CHAIN_ID, PK) - STOP for data cleanup
├─ Error "Referenced by FK": FKs not fully dropped - Go back to Phase 2
└─ Record: New PK created at [TIME], lock duration: X minutes

    ↓ PK SUCCESSFULLY RECREATED


PHASE 4: FOREIGN KEY RECREATION (5-15 min)
═══════════════════════════════════════════════════════════════════════════════

Step 4.1: Recreate External FKs
├─ For each FK from Phase 2 Step 2.2:
├─ Build: ALTER TABLE [TABLE_NAME] ADD CONSTRAINT [FK_NAME]
│         FOREIGN KEY ([FK_COLS]) REFERENCES [REF_TABLE]([REF_COLS])
├─ Execute: Each FK
├─ Expected: Success
└─ Record: Which external FKs recreated

    ↓

Step 4.2: Recreate Child Table FKs  
├─ For each FK from Phase 2 Step 2.1:
├─ Build: ALTER TABLE [CHILD_TABLE] ADD CONSTRAINT [FK_NAME]
│         FOREIGN KEY ([FK_COLS], CHAIN_ID) REFERENCES [TABLE_NAME]([PK_COLS], CHAIN_ID)
├─ Execute: Each FK
├─ Expected: Success (FK must include CHAIN_ID on both sides)
├─ Error: Child table missing CHAIN_ID - Requires data migration
└─ Record: Which child FKs recreated

    ↓ ALL FKs RECREATED


PHASE 5: VERIFICATION (10 min)
═══════════════════════════════════════════════════════════════════════════════

Verification Query 1: Partition Function Exists
├─ Query: SELECT name FROM sys.partition_functions WHERE name = 'pf_ChainID_EPS'
├─ Expected: 1 row (name: pf_ChainID_EPS, type: RANGE, boundary_value_on_right: False)
└─ Result: ✅ PASS / ❌ FAIL

    ↓ PASS

Verification Query 2: Partition Scheme Exists
├─ Query: SELECT ps.name, ds.name FROM sys.partition_schemes ps JOIN ... 
│         WHERE ps.name = 'ps_ChainID_EPS'
├─ Expected: 6 rows (one per partition), all FilegroupName = PRIMARY
└─ Result: ✅ PASS / ❌ FAIL

    ↓ PASS

Verification Query 3: Table Using Partition Scheme
├─ Query: SELECT i.name, ps.name FROM sys.indexes i LEFT JOIN sys.partition_schemes
│         WHERE object_id = OBJECT_ID('EPS.[TABLE_NAME]') AND index_id = 1
├─ Expected: PK_[TABLE_NAME] → ps_ChainID_EPS
└─ Result: ✅ PASS / ❌ FAIL

    ↓ PASS

Verification Query 4: All 6 Partitions Allocated
├─ Query: SELECT partition_number, [rows] FROM sys.partitions
│         WHERE object_id = OBJECT_ID('EPS.[TABLE_NAME]') AND index_id = 1
├─ Expected: 6 rows (partition_number 1-6, rows = current data)
└─ Result: ✅ PASS / ❌ FAIL

    ↓ PASS

Verification Query 5: PK Column Structure Correct
├─ Query: SELECT c.name, ic.key_ordinal FROM sys.index_columns ic JOIN sys.columns c
│         WHERE index_id = 1 ORDER BY key_ordinal
├─ Expected: 
│  • Column 1: CHAIN_ID ✅ (MUST be first)
│  • Column 2+: Original PK columns
└─ Result: ✅ PASS / ❌ FAIL

    ↓ PASS

Verification Query 6: Partition Key Correct
├─ Query: SELECT c.name FROM sys.indexes i JOIN sys.index_columns ic 
│         JOIN sys.columns c WHERE partition_ordinal > 0
├─ Expected: CHAIN_ID (partition_ordinal = 1)
└─ Result: ✅ PASS / ❌ FAIL

    ↓ PASS


═══════════════════════════════════════════════════════════════════════════════

                    🎉 ALL VERIFICATIONS PASSED ✅
                    
              PARTITIONING COMPLETE AND SUCCESSFUL

═══════════════════════════════════════════════════════════════════════════════


FINAL STATE
═══════════════════════════════════════════════════════════════════════════════

Table:                  EPS.[TABLE_NAME]
Status:                 ✅ PARTITIONED

Partition Function:     pf_ChainID_EPS (RANGE LEFT)
  Boundaries:           1000, 5000, 50000, 100000, 130000

Partition Scheme:       ps_ChainID_EPS (all → PRIMARY filegroup)

Primary Key:            (CHAIN_ID, [Original PK Cols]) on ps_ChainID_EPS
  Partition Key:        CHAIN_ID

Partitions:             6 (P1-P6)
  P1: CHAIN_ID ≤ 1000           [X rows]
  P2: CHAIN_ID ≤ 5000           [X rows]
  P3: CHAIN_ID ≤ 50000          [X rows]
  P4: CHAIN_ID ≤ 100000         [X rows]
  P5: CHAIN_ID ≤ 130000         [X rows]
  P6: CHAIN_ID > 130000         [X rows]

Data Integrity:         ✅ Preserved (0 data loss)
Foreign Keys:           ✅ Recreated
Queries:                ✅ Can now use partition elimination


NEXT STEPS
═══════════════════════════════════════════════════════════════════════════════

1. Generate Execution Report
   └─ Save to: /EXECUTION_REPORTS/[TABLE_NAME]_PARTITION_[DATE].md

2. Update Rollout Summary
   └─ Add table to: /PARTITION_ROLLOUT_SUMMARY.md

3. Proceed to Next Table
   └─ Find next table in: /PARTITION_STRATEGY_BY_TABLE.md (Category A1)

4. Optional: Performance Tuning
   └─ Create supporting indexes on frequently queried columns
   └─ Run baseline performance queries
   └─ Compare before/after partition elimination


ERROR RECOVERY DECISION TREE
═══════════════════════════════════════════════════════════════════════════════

IF error occurs at:

Phase 2 (FK Management)
  └─ "Cannot drop FK - still referenced" 
     → Find all references, drop them first, retry

Phase 3.1 (Drop PK)
  └─ "Cannot drop PK - referenced by FK"
     → Go back to Phase 2, drop FKs completely, retry Phase 3

Phase 3.2 (Create New PK)
  └─ "Duplicate key violates primary key constraint"
     → STOP: Duplicate (CHAIN_ID, PK) values exist
     → Options:
        A) Remove duplicate rows
        B) Adjust PK structure (requires business decision)
        C) Skip table (document as blocked)

Phase 4 (Recreate FKs)
  └─ "Invalid column in referenced table"
     → Child table missing CHAIN_ID or column renamed
     → Add missing column first, then recreate FK

Phase 5 (Verification)
  └─ ANY query returns unexpected result
     → Check Phase 3 actually completed successfully
     → Verify PK structure with: SELECT * FROM sys.indexes WHERE...
     → If PK not on partition scheme, go back to Phase 3


KEY INFORMATION LOCATIONS
═══════════════════════════════════════════════════════════════════════════════

📍 Partition Rules:
   /memories/repo/PARTITIONING_RULES.md

📍 Table Classification & Strategy:
   /PARTITION_STRATEGY_BY_TABLE.md

📍 Connectivity Configuration:
   /config/db-credentials.encrypted (encrypted DPAPI)
   /scripts/Connect-ToDatabase.ps1 (connection script)

📍 Existing Partition Setup (from PATIENT):
   /PATIENT_PARTITIONING_EXECUTION_REPORT.md

📍 Verification Queries (copy-paste ready):
   /VERIFY_PARTITIONS_QUERIES.sql

📍 All Execution Reports (save here):
   /EXECUTION_REPORTS/

📍 Rollout Summary (update after each table):
   /PARTITION_ROLLOUT_SUMMARY.md

📍 This Complete Rulebook:
   /PARTITION_IMPLEMENTATION_RULEBOOK.md


FOR AGENT EXECUTION
═══════════════════════════════════════════════════════════════════════════════

Agent Loop for Category A Tables:

FOR EACH table in [ADDRESS, RX_TX, PRESCRIBER, MRN, CARD, PAYMENT, LINE_ITEM, ALLERGY, DISEASE]:
  
  1. READ /PARTITION_IMPLEMENTATION_RULEBOOK.md (this file)
  2. EXECUTE Phase 1: Pre-execution analysis (read all steps 1.1-1.6)
  3. EXECUTE Phase 2: FK management (all steps)
  4. EXECUTE Phase 3: PK modification (with lock warning)
  5. EXECUTE Phase 4: FK recreation (all steps)
  6. EXECUTE Phase 5: Verification (all 6 queries)
  7. CREATE execution report using REPORT_TEMPLATE
  8. SAVE report to /EXECUTION_REPORTS/[TABLE_NAME]_PARTITION_[DATE].md
  9. UPDATE /PARTITION_ROLLOUT_SUMMARY.md with completion
  10. REPEAT for next table

TOTAL TIME PER TABLE: 30-45 minutes (including all phases + verification + reporting)

═══════════════════════════════════════════════════════════════════════════════
```

---

## QUICK REFERENCE COMMANDS

### Pre-Execution Checks
```powershell
# Check table exists
.\scripts\Connect-ToDatabase.ps1 -Query "SELECT COUNT(*) FROM EPS.[TABLE_NAME]"

# Check CHAIN_ID column
.\scripts\Connect-ToDatabase.ps1 -Query "SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='EPS' AND TABLE_NAME='[TABLE_NAME]' AND COLUMN_NAME='CHAIN_ID'"

# Check PK exists
.\scripts\Connect-ToDatabase.ps1 -Query "SELECT CONSTRAINT_NAME FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA='EPS' AND TABLE_NAME='[TABLE_NAME]' AND CONSTRAINT_TYPE='PRIMARY KEY'"

# Find FKs
.\scripts\Connect-ToDatabase.ps1 -Query "SELECT name FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID('EPS.[TABLE_NAME]') OR referenced_object_id=OBJECT_ID('EPS.[TABLE_NAME]')"
```

### Partition Verification Commands
```powershell
# All 6 partitions allocated
.\scripts\Connect-ToDatabase.ps1 -Query "SELECT partition_number, [rows] FROM sys.partitions WHERE object_id=OBJECT_ID('EPS.[TABLE_NAME]') AND index_id=1 ORDER BY partition_number"

# PK on partition scheme
.\scripts\Connect-ToDatabase.ps1 -Query "SELECT i.name, ps.name FROM sys.indexes i LEFT JOIN sys.partition_schemes ps ON i.data_space_id=ps.data_space_id WHERE i.object_id=OBJECT_ID('EPS.[TABLE_NAME]') AND i.index_id=1"

# Partition key is CHAIN_ID
.\scripts\Connect-ToDatabase.ps1 -Query "SELECT i.name, c.name FROM sys.indexes i JOIN sys.index_columns ic ON i.object_id=ic.object_id AND i.index_id=ic.index_id JOIN sys.columns c ON ic.object_id=c.object_id AND ic.column_id=c.column_id WHERE i.object_id=OBJECT_ID('EPS.[TABLE_NAME]') AND i.index_id=1 AND ic.partition_ordinal>0"
```

---

**REFERENCE COMPLETE** ✅

See `/PARTITION_IMPLEMENTATION_RULEBOOK.md` for detailed step-by-step instructions
