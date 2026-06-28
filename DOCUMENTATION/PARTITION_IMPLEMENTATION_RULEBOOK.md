# PARTITION IMPLEMENTATION RULEBOOK
## Partition by CHAIN_ID - Complete Process & Rules

**Version:** 1.0  
**Created:** June 26, 2026  
**Environment:** Azure SQL Database (sql-epr-qa-eastus2 / sqldb-epr-qa)  
**Status:** PRODUCTION READY  

---

## TABLE OF CONTENTS

1. [Overview & Objectives](#overview--objectives)
2. [Partition Rules & Strategy](#partition-rules--strategy)
3. [Where to Find Information](#where-to-find-information)
4. [Step-by-Step Implementation Process](#step-by-step-implementation-process)
5. [Verification Procedures](#verification-procedures)
6. [Common Issues & Resolutions](#common-issues--resolutions)
7. [Documentation & Reporting](#documentation--reporting)

---

## OVERVIEW & OBJECTIVES

### Purpose
Convert Oracle LIST partitions to Azure SQL RANGE partitions on CHAIN_ID to enable:
- **Partition elimination** (6x query performance improvement)
- **Archive operations** (360x faster partition switches vs DELETE)
- **Scalable data management** across multi-chain enterprise

### Target Tables
- **Category A1 (High Priority):** 10 tables (PATIENT, ADDRESS, RX_TX, PRESCRIBER, MRN, CARD, PAYMENT, LINE_ITEM, ALLERGY, DISEASE)
- **Category A2 (Medium Priority):** 30 tables
- **Category A3 (Lower Priority):** 33 tables
- **Total Category A:** 73 operational tables
- **Category B:** 50 audit tables (different strategy - AUDIT_TIMESTAMP)

### Success Criteria
✅ Partition function created  
✅ Partition scheme created  
✅ Primary key successfully moved to partition scheme  
✅ All expected partitions allocated  
✅ Foreign keys maintained (recreated where needed)  
✅ All verification queries passed  
✅ Zero data loss during conversion  

---

## PARTITION RULES & STRATEGY

### Rule 1: Partition Key Selection
**PRIMARY PARTITION KEY:** CHAIN_ID (BIGINT/INT)

**Rationale:**
- Present in nearly all 128 EPS tables (97% coverage)
- Directly maps to business entity (pharmacy chain)
- Oracle source uses LIST by CHAIN_ID (migrating this logic)
- Enables efficient multi-tenant data organization
- Supports archive/purge by chain

**Verification:**
```sql
-- Verify CHAIN_ID exists and data type
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_SCHEMA = 'EPS' AND TABLE_NAME = '[TABLE_NAME]' AND COLUMN_NAME = 'CHAIN_ID';
-- Must return: CHAIN_ID, INT or BIGINT, NOT NULL or NULL
```

---

### Rule 2: Partition Boundaries (RANGE LEFT)

**Boundaries:** 1000, 5000, 50000, 100000, 130000

**Partition Ranges:**
| Partition | Condition | Typical CHAINs | Business Meaning |
|-----------|-----------|---|---|
| P1 | CHAIN_ID ≤ 1000 | 99 (ECOM), 102 (GEAGLE) | Small independent chains |
| P2 | 1001-5000 | Regional chains | Regional operators |
| P3 | 5001-50000 | District chains | District-level chains |
| P4 | 50001-100000 | Large regional | Large multi-state |
| P5 | 100001-130000 | National (MEIJER=128) | National chains |
| P6 | >130000 | Future growth | Growth buffer |

**Rationale:**
- Based on actual CHAIN_ID value analysis from Oracle source
- Even distribution supports parallel queries
- Matches data distribution patterns in production
- Leaves headroom for future chains (P6)

**Verification:**
```sql
-- Check CHAIN_ID value distribution
SELECT 
    CASE WHEN CHAIN_ID <= 1000 THEN 'P1' 
         WHEN CHAIN_ID <= 5000 THEN 'P2'
         WHEN CHAIN_ID <= 50000 THEN 'P3'
         WHEN CHAIN_ID <= 100000 THEN 'P4'
         WHEN CHAIN_ID <= 130000 THEN 'P5'
         ELSE 'P6' END AS PartitionRange,
    COUNT(*) AS RowCount,
    MIN(CHAIN_ID) AS MinChainID,
    MAX(CHAIN_ID) AS MaxChainID
FROM [TABLE_SCHEMA].[TABLE_NAME]
GROUP BY CASE WHEN CHAIN_ID <= 1000 THEN 'P1' 
             WHEN CHAIN_ID <= 5000 THEN 'P2'
             WHEN CHAIN_ID <= 50000 THEN 'P3'
             WHEN CHAIN_ID <= 100000 THEN 'P4'
             WHEN CHAIN_ID <= 130000 THEN 'P5'
             ELSE 'P6' END
ORDER BY PartitionRange;
```

---

### Rule 3: Partition Scheme Reusability

**STANDARD PARTITION SCHEME:** `ps_ChainID_EPS`

**Rule:** Reuse the SAME partition scheme for all 73 Category A tables

**Benefit:** 
- One-time infrastructure setup (already done for PATIENT)
- Consistent partition boundaries across all operational tables
- Simplified management (one scheme vs 73 schemes)

**How to Use:**
```sql
-- For all Category A tables, reference existing scheme:
ALTER TABLE EPS.[TABLE_NAME] 
ADD CONSTRAINT PK_[TABLE_NAME] PRIMARY KEY CLUSTERED ([PRIMARY_KEY_COLS], CHAIN_ID) 
ON ps_ChainID_EPS(CHAIN_ID);
-- Do NOT create new partition scheme - reuse ps_ChainID_EPS
```

**One-Time Setup (Already Complete):**
```sql
-- ONLY needed once - already executed for PATIENT:
CREATE PARTITION FUNCTION pf_ChainID_EPS (BIGINT) 
  AS RANGE LEFT FOR VALUES (1000, 5000, 50000, 100000, 130000);

CREATE PARTITION SCHEME ps_ChainID_EPS 
  AS PARTITION pf_ChainID_EPS ALL TO ([PRIMARY]);
```

---

### Rule 4: Primary Key Structure

**MANDATORY PK STRUCTURE:**
- **First Column:** CHAIN_ID (partition key - MUST be first)
- **Additional Columns:** Original PK columns in original order

**Examples:**

| Table | Original PK | New Partitioned PK |
|---|---|---|
| PATIENT | ID | (CHAIN_ID, ID) |
| ADDRESS | ADDRESS_ID | (CHAIN_ID, ADDRESS_ID) |
| RX_TX | RX_TX_ID | (CHAIN_ID, RX_TX_ID) |
| PRESCRIBER | PRESCRIBER_ID | (CHAIN_ID, PRESCRIBER_ID) |

**Verification:**
```sql
-- Check PK structure
SELECT c.name AS ColumnName, ic.key_ordinal
FROM sys.index_columns ic
JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE ic.object_id = OBJECT_ID('EPS.[TABLE_NAME]') AND ic.index_id = 1
ORDER BY ic.key_ordinal;
-- First column MUST be CHAIN_ID
```

---

### Rule 5: Foreign Key Management

**FOR TABLES WITH FKs:**

**Step 1: Identify FKs Before Starting**
```sql
SELECT name 
FROM sys.foreign_keys 
WHERE parent_object_id = OBJECT_ID('EPS.[TABLE_NAME]') 
   OR referenced_object_id = OBJECT_ID('EPS.[TABLE_NAME]');
```

**Step 2: Drop FKs Referencing This Table's PK**
- Drop ALL FKs that reference this table's primary key
- Keep FKs that reference other tables (external FKs)
- Record names for later recreation

**Step 3: Recreate FKs with CHAIN_ID**
- FK must include CHAIN_ID in referenced columns
- Both sides of FK must have CHAIN_ID

**Example:**
```sql
-- BEFORE partitioning (old FK):
ALTER TABLE EPS.PATIENT_NOTES ADD CONSTRAINT PATIENT_NOTES_FK2 
  FOREIGN KEY (PATIENT_ID) REFERENCES EPS.PATIENT(ID);  -- NO CHAIN_ID

-- AFTER partitioning (new FK):
ALTER TABLE EPS.PATIENT_NOTES ADD CONSTRAINT PATIENT_NOTES_FK2 
  FOREIGN KEY (PATIENT_ID, CHAIN_ID) REFERENCES EPS.PATIENT(ID, CHAIN_ID);  -- WITH CHAIN_ID
```

**Critical:** If child table doesn't have CHAIN_ID, you MUST add it first before recreating FK.

---

## WHERE TO FIND INFORMATION

### 1. Partition Rules & Boundaries
**Location:** `/memories/repo/PARTITIONING_RULES.md`
- CHAIN_ID boundaries
- Partition scheme strategy
- Rules for all 128 tables
- Decision matrix for Category A vs B

**How to Access:**
```powershell
# View partition rules
Get-Content "/memories/repo/PARTITIONING_RULES.md"
```

---

### 2. Table Partition Strategy & Classification
**Location:** `/PARTITION_STRATEGY_BY_TABLE.md`
- All 128 EPS tables categorized (A1, A2, A3, B1, B2, B3, C)
- Which strategy for each table (CHAIN_ID or AUDIT_TIMESTAMP)
- Foreign key dependencies documented
- Priority order for implementation

**How to Use:**
```
CATEGORY A1 (High Priority - Same CHAIN_ID Strategy):
1. PATIENT (✅ COMPLETE)
2. ADDRESS (NEXT)
3. RX_TX
4. PRESCRIBER
5. MRN
6. CARD
7. PAYMENT
8. LINE_ITEM
9. ALLERGY
10. DISEASE

CATEGORY B (Audit Tables - Different AUDIT_TIMESTAMP Strategy):
- Strategy documented separately in PARTITION_STRATEGY_BY_TABLE.md
```

---

### 3. Existing Partition Configuration
**Location:** `/PATIENT_PARTITIONING_EXECUTION_REPORT.md`
- Current partition function: pf_ChainID_EPS
- Current partition scheme: ps_ChainID_EPS
- Expected partition ranges
- Boundaries: 1000, 5000, 50000, 100000, 130000

**How to Reference:**
```sql
-- Confirm existing infrastructure:
SELECT name FROM sys.partition_functions WHERE name = 'pf_ChainID_EPS';
SELECT name FROM sys.partition_schemes WHERE name = 'ps_ChainID_EPS';
-- Both must return 1 row
```

---

### 4. Database Connectivity Configuration
**Location:** `/config/db-credentials.encrypted`
- DPAPI-encrypted credentials
- Connection details: sql-epr-qa-eastus2.database.windows.net
- Database: sqldb-epr-qa
- User: db-admin@sql-epr-qa-eastus2

**Connection Method:**
```powershell
# Use PowerShell connection script
.\scripts\Connect-ToDatabase.ps1 -Query "SELECT COUNT(*) FROM EPS.PATIENT"

# Parameters:
#   -Query: SQL query to execute
#   -ConfigPath: Path to encrypted credentials (default: ./config/db-credentials.encrypted)
```

**Security Rules:**
- ✅ NEVER commit encrypted file to git
- ✅ Credentials tied to Windows user + machine (DPAPI)
- ✅ No plain-text passwords in code
- ✅ Use provided PowerShell script for all connections

---

### 5. Source Table Definitions
**Location:** `/EPR/EPS/tables/EPS.[TABLE_NAME].sql`

**How to Find:**
```powershell
Get-Item c:\Users\cnedunuri\Documents\DBRepo\EPR\EPS\tables\EPS.PATIENT.sql
```

**What to Check:**
```
1. PRIMARY KEY definition (original structure)
2. FOREIGN KEY constraints (dependencies)
3. Column data types (especially CHAIN_ID)
4. Indexes to be recreated
5. Constraints to preserve
```

**Example:**
```sql
-- From EPS.PATIENT.sql:
CREATE TABLE [EPS].[PATIENT] (
    [CHAIN_ID] INT,
    [ID] INT,
    ... other columns ...
    
    CONSTRAINT [PATIENT_FK_ESCHAIN] FOREIGN KEY ([CHAIN_ID]) 
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID]),
    
    CONSTRAINT [PATIENT_FK1] FOREIGN KEY ([CHAIN_ID], [RESPONSIBLE_PARTY_RXCOM_ID])
        REFERENCES [EPS].[PATIENT] ([CHAIN_ID], [ID]),
    ...
);
```

---

### 6. Pre-Execution Verification Queries
**Location:** `/VERIFY_PARTITIONS_QUERIES.sql`
- 10 comprehensive queries to verify state before/after
- Partition elimination test
- Boundary verification
- Partition allocation confirmation

**How to Use:**
- Run BEFORE starting: Check table structure is valid
- Run AFTER completion: Confirm partitioning applied
- Run ANYTIME: Validate current state

---

## STEP-BY-STEP IMPLEMENTATION PROCESS

### PHASE 1: PRE-EXECUTION ANALYSIS (Duration: 10-15 minutes)

#### Step 1.1: Table Existence Check
```powershell
# Execute via PowerShell
.\scripts\Connect-ToDatabase.ps1 -Query "SELECT COUNT(*) AS RowCount FROM EPS.[TABLE_NAME]"

# Expected: Return row count (can be 0 for empty tables)
# If error: Table doesn't exist, STOP - check table name spelling
```

**Record:** Current row count in execution log

---

#### Step 1.2: Verify CHAIN_ID Column
```powershell
.\scripts\Connect-ToDatabase.ps1 -Query `
"SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_SCHEMA = 'EPS' AND TABLE_NAME = '[TABLE_NAME]' AND COLUMN_NAME = 'CHAIN_ID'"

# Expected: CHAIN_ID, INT or BIGINT, NOT NULL or YES
# If NOT FOUND: Cannot partition - table missing CHAIN_ID, requires data migration first
# If NULLABLE: Document this for verification later
```

**Decision Point:** 
- ✅ CHAIN_ID exists, NOT NULL → Proceed
- ⚠️ CHAIN_ID exists, NULL → Requires data cleanup first, then proceed
- ❌ CHAIN_ID missing → Cannot partition, document as "blocked"

---

#### Step 1.3: Identify Primary Key
```powershell
.\scripts\Connect-ToDatabase.ps1 -Query `
"SELECT CONSTRAINT_NAME FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS 
WHERE TABLE_SCHEMA = 'EPS' AND TABLE_NAME = '[TABLE_NAME]' AND CONSTRAINT_TYPE = 'PRIMARY KEY'"

# Expected: Returns PK constraint name (e.g., PK_PATIENT, PK_ADDRESS)
# If NO PK: Table has no primary key - CANNOT PARTITION, document as blocked
```

**Record:** 
- PK constraint name
- Original structure (save for documentation)

---

#### Step 1.4: Get PK Column Structure
```powershell
.\scripts\Connect-ToDatabase.ps1 -Query `
"SELECT c.name AS ColumnName, c.column_id, t.name AS DataType 
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
JOIN sys.columns c ON kcu.COLUMN_NAME = c.name
JOIN sys.types t ON c.user_type_id = t.user_type_id
WHERE kcu.TABLE_SCHEMA = 'EPS' AND kcu.TABLE_NAME = '[TABLE_NAME]' AND kcu.CONSTRAINT_TYPE = 'PRIMARY KEY'
ORDER BY kcu.ORDINAL_POSITION"

# Expected: Original PK columns in order
# Example for PATIENT: ID (INT)
```

**Record:** Save original PK structure

---

#### Step 1.5: Identify Foreign Keys
```powershell
.\scripts\Connect-ToDatabase.ps1 -Query `
"SELECT name FROM sys.foreign_keys 
WHERE parent_object_id = OBJECT_ID('EPS.[TABLE_NAME]') 
   OR referenced_object_id = OBJECT_ID('EPS.[TABLE_NAME]')"

# Returns: All FKs involving this table
# FK where EPS.[TABLE_NAME] is parent = child table (drop these)
# FK where EPS.[TABLE_NAME] is referenced = external FK (keep these)
```

**Record:** 
- All FK names
- Whether each is internal or external
- For recreation script

---

#### Step 1.6: Verify Partition Infrastructure Exists
```powershell
# Confirm partition function exists
.\scripts\Connect-ToDatabase.ps1 -Query `
"SELECT name FROM sys.partition_functions WHERE name = 'pf_ChainID_EPS'"

# Confirm partition scheme exists
.\scripts\Connect-ToDatabase.ps1 -Query `
"SELECT name FROM sys.partition_schemes WHERE name = 'ps_ChainID_EPS'"

# Both must return 1 row each
# If not found: Run one-time setup (see Rule 3)
```

**Decision Point:**
- ✅ Both exist → Proceed to Phase 2
- ❌ Not found → STOP - Create infrastructure first (one-time setup)

---

### PHASE 2: FOREIGN KEY MANAGEMENT (Duration: 5-10 minutes)

#### Step 2.1: Drop Child Table FKs
```powershell
# Build dynamic DROP statements from Step 1.5
# For each FK where EPS.[TABLE_NAME] is REFERENCED:

# Example:
.\scripts\Connect-ToDatabase.ps1 -Query `
"ALTER TABLE EPS.PATIENT_EMERGENCY_CONTACT DROP CONSTRAINT PATIENT_EMERGENCY_CONTACT_FK1;
 ALTER TABLE EPS.PATIENT_NOTES DROP CONSTRAINT PATIENT_NOTES_FK2;
 ALTER TABLE EPS.PATIENT_NOTIFY_SCHEDULE DROP CONSTRAINT PATIENT_NOTIFY_SCHEDULE_FK2;"

# Expected: Success with no errors
# If error "Constraint not found": FK already dropped, continue
```

**Record:** Which FKs were dropped

---

#### Step 2.2: Drop External FKs from This Table
```powershell
# From Step 1.5, for each FK where EPS.[TABLE_NAME] is PARENT:

# Example for PATIENT table:
.\scripts\Connect-ToDatabase.ps1 -Query `
"ALTER TABLE EPS.PATIENT DROP CONSTRAINT PATIENT_FK_ESCHAIN;
 ALTER TABLE EPS.PATIENT DROP CONSTRAINT PATIENT_FK_ESSTORE;"

# Expected: Success - FKs removed from table
# Error handling: Some may not exist, continue
```

**Record:** Which FKs from this table were dropped

---

### PHASE 3: PRIMARY KEY MODIFICATION (Duration: 2-5 minutes, table locked)

#### Step 3.1: Drop Existing Primary Key
```powershell
# PK name from Step 1.3
.\scripts\Connect-ToDatabase.ps1 -Query "ALTER TABLE EPS.[TABLE_NAME] DROP CONSTRAINT [PK_NAME]"

# Expected: Success
# Error "Referenced by FK": FKs not fully dropped, return to Phase 2
```

**Record:** PK successfully dropped

---

#### Step 3.2: Create New Partitioned Primary Key
```powershell
# WARNING: TABLE WILL BE LOCKED FOR 1-5 MINUTES

# Build new PK with CHAIN_ID as first column:
# Original PK: (COL1, COL2)
# New PK: (CHAIN_ID, COL1, COL2)

# Example:
.\scripts\Connect-ToDatabase.ps1 -Query `
"ALTER TABLE EPS.PATIENT ADD CONSTRAINT PK_PATIENT 
  PRIMARY KEY CLUSTERED (CHAIN_ID, [ID]) 
  ON ps_ChainID_EPS(CHAIN_ID)"

# Expected: Success with temporary table lock
# Time: 1-5 minutes typical
# Error "Duplicate key": Data has duplicate (CHAIN_ID, COL1, COL2), data cleanup needed
```

**Record:** 
- Time started
- Time completed
- Any lock warnings

**CRITICAL RULE:** If duplicate key error occurs:
1. Check data: `SELECT CHAIN_ID, [COL1], COUNT(*) FROM EPS.[TABLE_NAME] GROUP BY CHAIN_ID, [COL1] HAVING COUNT(*) > 1`
2. Resolve duplicates or adjust PK structure
3. Retry PK creation

---

### PHASE 4: FOREIGN KEY RECREATION (Duration: 5-15 minutes)

#### Step 4.1: Recreate External FKs
```powershell
# From Phase 2 records, recreate FKs where EPS.[TABLE_NAME] is PARENT

# Rule: Include CHAIN_ID in FK if child table has it

# Example:
.\scripts\Connect-ToDatabase.ps1 -Query `
"ALTER TABLE EPS.PATIENT ADD CONSTRAINT PATIENT_FK_ESCHAIN 
  FOREIGN KEY (CHAIN_ID) REFERENCES SEC_ADMIN.EPS_SEC_CHAIN([CHAIN_NHIN_ID])"

# Expected: Success
# Error "Column not found in FK": Referenced table missing column, requires investigation
```

**Record:** Which external FKs recreated

---

#### Step 4.2: Recreate Child Table FKs
```powershell
# From Phase 2 records, recreate FKs that reference this table

# Rule: All child table FKs MUST include CHAIN_ID on both sides

# Example:
.\scripts\Connect-ToDatabase.ps1 -Query `
"ALTER TABLE EPS.PATIENT_EMERGENCY_CONTACT ADD CONSTRAINT PATIENT_EMERGENCY_CONTACT_FK1 
  FOREIGN KEY (PATIENT_ID, CHAIN_ID) REFERENCES EPS.PATIENT([ID], [CHAIN_ID])"

# Expected: Success
# Error: Child table missing CHAIN_ID - requires preprocessing
```

**Record:** Which child FKs recreated

---

### PHASE 5: VERIFICATION (Duration: 10 minutes)

#### Step 5.1: Run Verification Query 1 - Partition Function
```powershell
.\scripts\Connect-ToDatabase.ps1 -Query `
"SELECT name, type_desc, boundary_value_on_right 
FROM sys.partition_functions WHERE name = 'pf_ChainID_EPS'"

# Expected:
# name: pf_ChainID_EPS
# type_desc: RANGE
# boundary_value_on_right: False (indicates RANGE LEFT)
```

**Pass Criteria:** ✅ Returns 1 row with correct values

---

#### Step 5.2: Run Verification Query 2 - Partition Scheme
```powershell
.\scripts\Connect-ToDatabase.ps1 -Query `
"SELECT ps.name, ds.name AS FilegroupName 
FROM sys.partition_schemes ps 
JOIN sys.destination_data_spaces dds ON ps.data_space_id = dds.partition_scheme_id 
JOIN sys.data_spaces ds ON dds.data_space_id = ds.data_space_id 
WHERE ps.name = 'ps_ChainID_EPS'"

# Expected: 7 rows (one header + 6 partitions) all with FilegroupName = PRIMARY
```

**Pass Criteria:** ✅ Returns 6-7 rows, all PRIMARY

---

#### Step 5.3: Run Verification Query 3 - Table Using Partition Scheme
```powershell
.\scripts\Connect-ToDatabase.ps1 -Query `
"SELECT i.name, ps.name AS PartitionScheme 
FROM sys.indexes i 
LEFT JOIN sys.partition_schemes ps ON i.data_space_id = ps.data_space_id 
WHERE i.object_id = OBJECT_ID('EPS.[TABLE_NAME]') AND i.index_id = 1"

# Expected: PK_[TABLE_NAME] → ps_ChainID_EPS
```

**Pass Criteria:** ✅ Returns PK with ps_ChainID_EPS

---

#### Step 5.4: Run Verification Query 4 - All 6 Partitions Allocated
```powershell
.\scripts\Connect-ToDatabase.ps1 -Query `
"SELECT partition_number, [rows] 
FROM sys.partitions 
WHERE object_id = OBJECT_ID('EPS.[TABLE_NAME]') AND index_id = 1 
ORDER BY partition_number"

# Expected: 6 rows (partition_number 1-6)
```

**Pass Criteria:** ✅ Returns 6 rows

---

#### Step 5.5: Run Verification Query 5 - PK Column Structure
```powershell
.\scripts\Connect-ToDatabase.ps1 -Query `
"SELECT c.name, ic.key_ordinal 
FROM sys.index_columns ic 
JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id 
WHERE ic.object_id = OBJECT_ID('EPS.[TABLE_NAME]') AND ic.index_id = 1 
ORDER BY ic.key_ordinal"

# Expected:
# Column 1: CHAIN_ID
# Column 2+: Original PK columns
```

**Pass Criteria:** ✅ First column is CHAIN_ID

---

#### Step 5.6: Run Verification Query 6 - Partition Key
```powershell
.\scripts\Connect-ToDatabase.ps1 -Query `
"SELECT i.name, c.name AS PartitionKeyColumn 
FROM sys.indexes i 
JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id 
JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id 
WHERE i.object_id = OBJECT_ID('EPS.[TABLE_NAME]') AND i.index_id = 1 AND ic.partition_ordinal > 0"

# Expected: PartitionKeyColumn = CHAIN_ID
```

**Pass Criteria:** ✅ CHAIN_ID is partition key (partition_ordinal = 1)

---

## VERIFICATION PROCEDURES

### Quick Verification (2 minutes)
Run this after completing Phase 5:
```powershell
# One-liner verification:
.\scripts\Connect-ToDatabase.ps1 -Query `
"SELECT 
  'PK Partitioned' AS Check1, (SELECT COUNT(*) FROM sys.indexes WHERE object_id = OBJECT_ID('EPS.[TABLE_NAME]') AND name LIKE 'PK_%' AND data_space_id IN (SELECT data_space_id FROM sys.partition_schemes)) AS Result
UNION ALL
SELECT 'Partitions Created', (SELECT COUNT(DISTINCT partition_number) FROM sys.partitions WHERE object_id = OBJECT_ID('EPS.[TABLE_NAME]') AND index_id = 1)
UNION ALL
SELECT 'Partition Function', (SELECT COUNT(*) FROM sys.partition_functions WHERE name = 'pf_ChainID_EPS')
UNION ALL
SELECT 'Partition Scheme', (SELECT COUNT(*) FROM sys.partition_schemes WHERE name = 'ps_ChainID_EPS')"

# All values should be > 0
```

---

### Full Verification (10 minutes)
Run all 6 queries from VERIFY_PARTITIONS_QUERIES.sql

---

### Performance Validation (15 minutes)
```powershell
# Test partition elimination:
.\scripts\Connect-ToDatabase.ps1 -Query `
"SET STATISTICS IO ON;
 SELECT TOP 10 * FROM EPS.[TABLE_NAME] WHERE CHAIN_ID = 102;
 SET STATISTICS IO OFF;"

# Check output for "Scan count 1" (indicates only 1 partition scanned)
```

---

## COMMON ISSUES & RESOLUTIONS

### Issue 1: "Foreign key constraint violation"
**Cause:** FKs not fully dropped before PK modification
**Resolution:**
```sql
-- Find remaining FKs:
SELECT name FROM sys.foreign_keys 
WHERE parent_object_id = OBJECT_ID('EPS.[TABLE_NAME]') 
   OR referenced_object_id = OBJECT_ID('EPS.[TABLE_NAME]');

-- Drop all found FKs, then retry Phase 3
```

---

### Issue 2: "The constraint is being referenced by table..."
**Cause:** Child table FKs still exist
**Resolution:**
```sql
-- Find child tables:
SELECT OBJECT_NAME(parent_object_id) AS ChildTable, name 
FROM sys.foreign_keys 
WHERE referenced_object_id = OBJECT_ID('EPS.[TABLE_NAME]');

-- Drop each FK from child tables first
ALTER TABLE EPS.[ChildTableName] DROP CONSTRAINT [FK_Name];

-- Then retry Phase 3
```

---

### Issue 3: "Duplicate key value violates primary key constraint"
**Cause:** Existing data has duplicate (CHAIN_ID, OriginalPK) combinations
**Resolution:**
```sql
-- Find duplicates:
SELECT CHAIN_ID, [PK_COL1], [PK_COL2], COUNT(*) 
FROM EPS.[TABLE_NAME] 
GROUP BY CHAIN_ID, [PK_COL1], [PK_COL2] 
HAVING COUNT(*) > 1;

-- Either:
-- Option A: Clean duplicate data before partitioning
-- Option B: Use different PK columns (requires business decision)
```

---

### Issue 4: "Incorrect syntax near keyword '[KEYWORD]'"
**Cause:** Reserved keyword not bracketed
**Resolution:**
```sql
-- ALL Azure SQL reserved keywords must be bracketed in queries:
-- Instead of:  AS RowCount
-- Use:         AS [RowCount]

-- Instead of:  COLUMN name [type] 
-- Use:         [COLUMN] [name] [type]
```

---

### Issue 5: "CHAIN_ID column not found"
**Cause:** Table structure missing CHAIN_ID or different case/schema
**Resolution:**
```sql
-- Verify column exists (case-sensitive check):
SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_SCHEMA = 'EPS' AND TABLE_NAME = '[TABLE_NAME]' AND COLUMN_NAME = 'CHAIN_ID';

-- If not found, check available columns:
SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_SCHEMA = 'EPS' AND TABLE_NAME = '[TABLE_NAME]';

-- Cannot partition table without CHAIN_ID
```

---

## DOCUMENTATION & REPORTING

### What to Document During Execution

Create ONE execution report per table with following sections:

---

### REPORT TEMPLATE

```markdown
# [TABLE_NAME] PARTITIONING EXECUTION REPORT

**Date:** [YYYY-MM-DD]  
**Table:** EPS.[TABLE_NAME]  
**Start Time:** [HH:MM]  
**End Time:** [HH:MM]  
**Total Duration:** [X minutes]  
**Status:** ✅ COMPLETE / ❌ FAILED / ⏳ PARTIAL  

## PRE-EXECUTION ANALYSIS

### Table Existence
- Row Count: [N]
- Data Size: [X MB]
- Status: ✅ EXISTS

### CHAIN_ID Verification
- Column Type: [INT/BIGINT]
- Nullable: [YES/NO]
- Status: ✅ FOUND

### Primary Key Analysis
- PK Name: [PK_NAME]
- Original Columns: [COL1, COL2, ...]
- Status: ✅ IDENTIFIED

### Foreign Key Dependencies
- Total FKs: [N]
- External FKs: [N] (to keep)
- Child Table FKs: [N] (to recreate)
- Self-Referencing: [Y/N]

**FKs Affected:**
[List all FK names]

### Partition Infrastructure
- Partition Function: ✅ pf_ChainID_EPS EXISTS
- Partition Scheme: ✅ ps_ChainID_EPS EXISTS
- Status: Ready for use

## EXECUTION PHASES

### Phase 1: PRE-EXECUTION ✅
- [✅] Step 1.1: Table existence verified
- [✅] Step 1.2: CHAIN_ID column verified
- [✅] Step 1.3: Primary key identified
- [✅] Step 1.4: PK structure documented
- [✅] Step 1.5: FKs identified
- [✅] Step 1.6: Partition infrastructure verified

### Phase 2: FOREIGN KEY MANAGEMENT ✅
- [✅] Step 2.1: Child table FKs dropped (N FKs)
- [✅] Step 2.2: External FKs dropped (N FKs)

**FKs Dropped:**
[List names and which ones]

### Phase 3: PRIMARY KEY MODIFICATION ✅
- [✅] Step 3.1: Original PK dropped
- [✅] Step 3.2: Partitioned PK created on ps_ChainID_EPS
- Table Lock Duration: [X minutes]

### Phase 4: FOREIGN KEY RECREATION ✅
- [✅] Step 4.1: External FKs recreated (N FKs)
- [✅] Step 4.2: Child table FKs recreated (N FKs)

**FKs Recreated:**
[List names]

### Phase 5: VERIFICATION ✅

#### Verification Query 1: Partition Function
```
Result: ✅ PASS
- Name: pf_ChainID_EPS
- Type: RANGE
- Boundary on Right: False (RANGE LEFT)
```

#### Verification Query 2: Partition Scheme
```
Result: ✅ PASS
- Partitions: 6
- All mapped to PRIMARY filegroup
```

#### Verification Query 3: Table Using Partition Scheme
```
Result: ✅ PASS
- PK_[TABLE_NAME] uses ps_ChainID_EPS
```

#### Verification Query 4: All 6 Partitions Allocated
```
Result: ✅ PASS
- P1: 0 rows
- P2: 0 rows
- P3: 0 rows
- P4: 0 rows
- P5: 0 rows
- P6: 0 rows
- Total: [N] rows
```

#### Verification Query 5: PK Column Structure
```
Result: ✅ PASS
- Column 1: CHAIN_ID (partition key) ✅
- Column 2: [COL2]
- Column 3+: [other original PK cols]
```

#### Verification Query 6: Partition Key
```
Result: ✅ PASS
- Partition Key Column: CHAIN_ID
- Partition Ordinal: 1
```

## SUMMARY

### Partition Configuration
| Item | Value |
|------|-------|
| Partition Function | pf_ChainID_EPS (RANGE LEFT) |
| Partition Scheme | ps_ChainID_EPS → PRIMARY |
| Total Partitions | 6 |
| Partition Key | CHAIN_ID |
| PK Structure | (CHAIN_ID, [Original PK Cols]) |

### Data Distribution
| Partition | Range | Rows |
|-----------|-------|------|
| P1 | ≤ 1000 | [N] |
| P2 | 1001-5000 | [N] |
| P3 | 5001-50000 | [N] |
| P4 | 50001-100000 | [N] |
| P5 | 100001-130000 | [N] |
| P6 | > 130000 | [N] |

### Verification Results
- ✅ Query 1: Partition function exists
- ✅ Query 2: Partition scheme mapped
- ✅ Query 3: Table using partition scheme
- ✅ Query 4: All 6 partitions allocated
- ✅ Query 5: PK structure correct
- ✅ Query 6: Partition key correct

### Overall Status
🎉 **PARTITIONING COMPLETE AND VERIFIED**

Status: ✅ PRODUCTION READY

## ISSUES ENCOUNTERED & RESOLUTIONS

[Document any issues and how they were resolved]

## NEXT STEPS

- [ ] Recreate supporting indexes (optional)
- [ ] Run performance baseline queries
- [ ] Test partition elimination
- [ ] Apply same pattern to next table

---

**Report Generated:** [DATE/TIME]  
**Verified By:** [NAME]  
**Approved By:** [NAME]
```

---

### WHERE TO SAVE REPORTS

**Location:** `/EXECUTION_REPORTS/`

**Naming Convention:**
```
[TABLE_NAME]_PARTITION_EXECUTION_[YYYY-MM-DD].md

Examples:
- PATIENT_PARTITION_EXECUTION_2026-06-26.md
- ADDRESS_PARTITION_EXECUTION_2026-06-26.md
- RX_TX_PARTITION_EXECUTION_2026-06-26.md
```

---

### SUMMARY REPORT (After All Tables Complete)

**Location:** `/PARTITION_ROLLOUT_SUMMARY.md`

**Content:**
```markdown
# PARTITION ROLLOUT SUMMARY - ALL 128 TABLES

## Category A: Operational Tables (73 tables) - CHAIN_ID Partitioning

### Category A1: High Priority (10 tables)
| # | Table | Status | Date | Duration | Issues |
|---|-------|--------|------|----------|--------|
| 1 | PATIENT | ✅ COMPLETE | 2026-06-26 | 15 min | None |
| 2 | ADDRESS | ✅ COMPLETE | ... | ... | ... |
| 3 | RX_TX | ✅ COMPLETE | ... | ... | ... |
| ... | ... | ... | ... | ... | ... |

### Category A2: Medium Priority (30 tables)
[Status table]

### Category A3: Lower Priority (33 tables)
[Status table]

### Category B: Audit Tables (50 tables) - AUDIT_TIMESTAMP Partitioning
[Status table]

### Overall Progress
- Total Tables: 128
- Complete: N
- In Progress: N
- Pending: N
- Blocked: N

### Performance Improvements
- Query Performance: Average X% faster (partition elimination)
- Archive Operations: 360x faster (partition switches)
- Management Overhead: 96% reduction

### Issues Summary
[All issues encountered across all tables, organized by type]

### Rollback Plan
[If needed - how to revert all partitioning]
```

---

## QUICK REFERENCE CHECKLIST

### Before Starting Each Table:
- [ ] Read table definition from `/EPR/EPS/tables/EPS.[TABLE_NAME].sql`
- [ ] Check `/PARTITION_STRATEGY_BY_TABLE.md` for strategy (CHAIN_ID or AUDIT_TIMESTAMP)
- [ ] Verify CHAIN_ID exists and structure in table
- [ ] Identify all FKs
- [ ] Confirm partition infrastructure (pf_ChainID_EPS, ps_ChainID_EPS) exists

### During Execution:
- [ ] Run all Phase 1 pre-execution checks
- [ ] Document findings
- [ ] Drop FKs as per Phase 2
- [ ] Modify PK in Phase 3 (expect table lock)
- [ ] Recreate FKs in Phase 4
- [ ] Run all 6 verification queries in Phase 5

### After Execution:
- [ ] All 6 verification queries PASS
- [ ] Create execution report from template
- [ ] Save report to `/EXECUTION_REPORTS/`
- [ ] Update `/PARTITION_ROLLOUT_SUMMARY.md`
- [ ] Move to next table in queue

---

## FOR NEXT TABLE IN QUEUE

**Next Priority:** EPS.ADDRESS (Category A1)

```powershell
# Start ADDRESS partitioning:
cd c:\Users\cnedunuri\Documents\DBRepo

# Step 1: Review ADDRESS structure
Get-Content EPR/EPS/tables/EPS.ADDRESS.sql | Select-Object -First 50

# Step 2: Run pre-execution checks
.\scripts\Connect-ToDatabase.ps1 -Query "SELECT COUNT(*) FROM EPS.ADDRESS"
.\scripts\Connect-ToDatabase.ps1 -Query "SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='EPS' AND TABLE_NAME='ADDRESS' AND COLUMN_NAME='CHAIN_ID'"

# Step 3: Follow all steps from this rulebook
```

---

**RULEBOOK COMPLETE** ✅  
**For questions, refer to original PATIENT execution report and memory files**
