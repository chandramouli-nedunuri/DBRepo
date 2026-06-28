# Azure SQL Partitioning Strategy Review
## EPR Migration: EPS.ADDRESS & EPS.AUDIT_ACCESS_LOG

**Document Date:** June 26, 2026  
**Status:** For Client Review & Decision  
**Classification:** Technical Design Proposal

---

## EXECUTIVE SUMMARY

This document outlines the strategy for converting Oracle LIST and COMPOSITE partitioning to Azure SQL for two critical EPS schema tables:

1. **EPS.ADDRESS** — Master data table partitioned by CHAIN_ID
2. **EPS.AUDIT_ACCESS_LOG** — Audit trail table with composite partitioning (CHAIN_ID + AUDIT_TIMESTAMP)

### Key Finding
**Azure SQL does NOT support native composite partitioning** like Oracle does. We must choose a single partitioning column and use supporting indexes for the second dimension.

This document presents **5 strategic options** with recommendations based on your business requirements.

---

## TABLE OF CONTENTS

1. [Oracle Partitioning Overview](#oracle-partitioning-overview)
2. [Azure SQL Limitations](#azure-sql-limitations)
3. [EPS.ADDRESS Conversion Plan](#epsaddress-conversion-plan)
4. [EPS.AUDIT_ACCESS_LOG Options](#epsaudit_access_log-options)
5. [Comparison Matrix](#comparison-matrix)
6. [Recommended Approach](#recommended-approach)
7. [Decision Questions for Client](#decision-questions-for-client)

---

## ORACLE PARTITIONING OVERVIEW

### EPS.ADDRESS Table
```
Partitioning: LIST on CHAIN_ID
Partitions: 100+ named partitions (GEAGLE, ECOM, MEIJER, etc.)
Data Range: CHAIN_ID values 31 to 130,727
Total Records: ~100 chains across multiple addresses
Primary Use: Address lookups by pharmacy chain
```

**Oracle Definition Example:**
```sql
PARTITION BY LIST (CHAIN_ID)
(PARTITION "GEAGLE" VALUES (102),
 PARTITION "ECOM" VALUES (99),
 PARTITION "MEIJER" VALUES (128),
 ...);
```

### EPS.AUDIT_ACCESS_LOG Table
```
Partitioning: COMPOSITE (LIST × RANGE)
  Primary:   LIST on CHAIN_ID (100+ pharmacy chains)
  Secondary: RANGE on AUDIT_TIMESTAMP (daily/weekly ranges)
Subpartitions: 6,031 total (100 chains × ~60 date ranges)
Data Range: AUDIT_TIMESTAMP from 2026-06-10 to 2026-07-17 (38 days)
Primary Use: Audit trail queries by date range and chain
```

**Oracle Definition Example:**
```sql
PARTITION BY LIST (CHAIN_ID)
  SUBPARTITION BY RANGE (AUDIT_TIMESTAMP)
  (PARTITION "GEAGLE" VALUES (102)
    (SUBPARTITION "GEAGLE202606" VALUES LESS THAN (TIMESTAMP'2026-07-01'),
     SUBPARTITION "GEAGLE202607" VALUES LESS THAN (TIMESTAMP'2026-08-01'),
     ...));
```

---

## AZURE SQL LIMITATIONS

### ❌ What Azure SQL Does NOT Support

1. **COMPOSITE Partitioning** — Cannot partition on 2+ columns simultaneously
2. **Subpartitioning** — No SUBPARTITION keyword
3. **RANGE LEFT/RIGHT on Non-Numeric** — Limited boundary value types
4. **Named Partitions** — Partitions are numbered (1, 2, 3, etc.), not named
5. **List Partitioning** — Must use RANGE or HASH partitioning only

### ✅ What Azure SQL DOES Support

1. **RANGE Partitioning** — On numeric, date, or datetime columns
2. **HASH Partitioning** — For even data distribution
3. **Partition Schemes** — Map partitions to filegroups (PRIMARY only in Azure SQL)
4. **Partition Switching** — Move partition data between tables (excellent for archival)
5. **Partition Functions** — Define partition boundaries

### The Challenge
**You can partition on CHAIN_ID OR AUDIT_TIMESTAMP, but not BOTH directly.**

---

## EPS.ADDRESS CONVERSION PLAN

### Table Characteristics
- **Partition Column:** CHAIN_ID (INT)
- **CHAIN_ID Values:** 31 to 130,727
- **Conversion Type:** Oracle LIST → Azure SQL RANGE
- **Partition Strategy:** Value-based boundaries

### Proposed Azure SQL Implementation

#### Step 1: Create Partition Function
```sql
CREATE PARTITION FUNCTION pf_ADDRESS_ChainID (INT)
AS RANGE LEFT 
FOR VALUES (1000, 5000, 50000, 100000, 130000);
```

**Partition Boundaries:**
| Partition | Range | Example Chains |
|-----------|-------|----------------|
| P1 | CHAIN_ID ≤ 1,000 | GEAGLE(102), ECOM(99), MEIJER(128), SHOPKO(180) |
| P2 | 1,000 < CHAIN_ID ≤ 5,000 | ENTERPRISEBICHAIN(3000) |
| P3 | 5,000 < CHAIN_ID ≤ 50,000 | CARERXOFFSHORE(9999) |
| P4 | 50,000 < CHAIN_ID ≤ 100,000 | RYCOM(119080), SPRVAL(105240), LOWELL(100366) |
| P5 | 100,000 < CHAIN_ID ≤ 130,000 | TRANSI(122893), OUTRIGGERS(125022), GILLETTE(125200) |
| P6 | CHAIN_ID > 130,000 | Future values, overflow |

#### Step 2: Create Partition Scheme
```sql
CREATE PARTITION SCHEME ps_ADDRESS_ChainID
AS PARTITION pf_ADDRESS_ChainID
ALL TO ([PRIMARY]);
```

#### Step 3: Apply Partitioning to Table
```sql
-- Drop existing constraints
ALTER TABLE EPS.ADDRESS
DROP CONSTRAINT PK_ADDRESS;

-- Recreate primary key on partition scheme
ALTER TABLE EPS.ADDRESS
ADD CONSTRAINT PK_ADDRESS PRIMARY KEY (ADDRESS_ID, CHAIN_ID)
ON ps_ADDRESS_ChainID(CHAIN_ID);

-- Create clustered index on partition scheme
CREATE CLUSTERED INDEX CIX_ADDRESS_CHAINID
ON EPS.ADDRESS (CHAIN_ID)
ON ps_ADDRESS_ChainID(CHAIN_ID);
```

#### Step 4: Recreate Supporting Indexes
```sql
-- Non-clustered indexes optimized for common queries
CREATE NONCLUSTERED INDEX NIX_ADDRESS_TYPE
ON EPS.ADDRESS (CHAIN_ID, ADDRESS_TYPE)
ON ps_ADDRESS_ChainID(CHAIN_ID);
```

### Performance Impact
- ✅ CHAIN_ID lookups: **EXCELLENT** (partition elimination)
- ✅ CHAIN_ID range queries: **EXCELLENT** (partition elimination)
- ⚠️ Address type queries: **GOOD** (index-based, possibly cross-partition)

### Advantages
- Straightforward 1:1 mapping from Oracle LIST
- Familiar query patterns work unchanged
- Per-chain maintenance windows supported
- Partition elimination on CHAIN_ID predicates

---

## EPS.AUDIT_ACCESS_LOG OPTIONS

### The Core Challenge
**Oracle uses COMPOSITE partitioning:**
- PRIMARY dimension: CHAIN_ID (100+ chains)
- SECONDARY dimension: AUDIT_TIMESTAMP (38 days)
- **Result:** 6,031 fine-grained subpartitions

**Azure SQL cannot replicate this directly.** You must choose between:

---

### OPTION 1: PARTITION BY CHAIN_ID + INDEX ON AUDIT_TIMESTAMP

**Concept:** Replicate Oracle's PRIMARY partition (CHAIN_ID); use index for date queries

**Implementation:**
```sql
-- Same partition function/scheme as EPS.ADDRESS
CREATE PARTITION FUNCTION pf_AUDIT_CHAINID (INT)
AS RANGE LEFT FOR VALUES (1000, 5000, 50000, 100000, 130000);

CREATE PARTITION SCHEME ps_AUDIT_CHAINID
AS PARTITION pf_AUDIT_CHAINID ALL TO ([PRIMARY]);

-- Clustered index on partition scheme
CREATE CLUSTERED INDEX CIX_AUDIT_CHAINID_TS
ON EPS.AUDIT_ACCESS_LOG (CHAIN_ID, AUDIT_TIMESTAMP)
ON ps_AUDIT_CHAINID(CHAIN_ID);

-- Supporting index for date-range queries
CREATE NONCLUSTERED INDEX NIX_AUDIT_TS
ON EPS.AUDIT_ACCESS_LOG (AUDIT_TIMESTAMP, CHAIN_ID);
```

**Performance Profile:**
| Query Type | Performance | Notes |
|-----------|-------------|-------|
| `WHERE CHAIN_ID = 102` | ⭐⭐⭐⭐⭐ Excellent | Partition elimination |
| `WHERE CHAIN_ID IN (102, 115, 128)` | ⭐⭐⭐⭐⭐ Excellent | Partition elimination |
| `WHERE AUDIT_TIMESTAMP > '2026-07-01'` | ⭐⭐⭐ Good | Index scan (slower) |
| `WHERE CHAIN_ID = 102 AND AUDIT_TIMESTAMP > '2026-07-01'` | ⭐⭐⭐⭐⭐ Excellent | Partition + index |

**Advantages:**
✅ Maintains per-chain isolation (like Oracle's PRIMARY partition)  
✅ Chain-based maintenance windows work  
✅ Replicates Oracle structure closely  

**Disadvantages:**
❌ Date-range only queries don't get partition elimination  
❌ Archive strategy requires identifying old rows first  
❌ Less efficient for typical audit queries (date-focused)  

**Best For:** Scenarios requiring per-chain maintenance or isolation

---

### OPTION 2: PARTITION BY AUDIT_TIMESTAMP + INDEX ON CHAIN_ID ⭐ RECOMMENDED

**Concept:** Replicate Oracle's SECONDARY partition (AUDIT_TIMESTAMP); use index for chain queries

**Implementation:**
```sql
-- Partition by AUDIT_TIMESTAMP (weekly ranges)
CREATE PARTITION FUNCTION pf_AUDIT_TS (DATETIME2)
AS RANGE RIGHT FOR VALUES (
    '2026-06-15', '2026-06-22', '2026-06-29', 
    '2026-07-06', '2026-07-13', '2026-07-20'
);

CREATE PARTITION SCHEME ps_AUDIT_TS
AS PARTITION pf_AUDIT_TS ALL TO ([PRIMARY]);

-- Clustered index on partition scheme
CREATE CLUSTERED INDEX CIX_AUDIT_TS_CHAINID
ON EPS.AUDIT_ACCESS_LOG (AUDIT_TIMESTAMP, CHAIN_ID)
ON ps_AUDIT_TS(AUDIT_TIMESTAMP);

-- Supporting index for chain-filtered queries
CREATE NONCLUSTERED INDEX NIX_AUDIT_CHAINID
ON EPS.AUDIT_ACCESS_LOG (CHAIN_ID, AUDIT_TIMESTAMP);
```

**Partition Boundaries (Weekly):**
| Partition | Date Range | Chains |
|-----------|-----------|--------|
| P1 | 2026-06-10 to 2026-06-15 | All ~160 chains |
| P2 | 2026-06-15 to 2026-06-22 | All ~160 chains |
| P3 | 2026-06-22 to 2026-06-29 | All ~160 chains |
| P4 | 2026-06-29 to 2026-07-06 | All ~160 chains |
| P5 | 2026-07-06 to 2026-07-13 | All ~160 chains |
| P6 | 2026-07-13 onwards | All ~160 chains |

**Performance Profile:**
| Query Type | Performance | Notes |
|-----------|-------------|-------|
| `WHERE AUDIT_TIMESTAMP > '2026-07-01'` | ⭐⭐⭐⭐⭐ Excellent | Partition elimination |
| `WHERE AUDIT_TIMESTAMP BETWEEN '2026-07-01' AND '2026-07-07'` | ⭐⭐⭐⭐⭐ Excellent | Partition elimination |
| `WHERE CHAIN_ID = 102` | ⭐⭐⭐ Good | Index scan (slower) |
| `WHERE CHAIN_ID = 102 AND AUDIT_TIMESTAMP > '2026-07-01'` | ⭐⭐⭐⭐⭐ Excellent | Partition + index |

**Advantages:**
✅ **Time-series queries are fastest** (partition elimination on dates)  
✅ **Weekly archive/purge is automatic** (partition switching)  
✅ **Operational simplicity** (6 manageable partitions vs 6,031)  
✅ **Perfect for audit log retention** (delete old weeks easily)  
✅ **Most common audit query pattern** (date-filtered)  

**Disadvantages:**
❌ Chain-only queries use index (slower than partitioned)  
❌ All chains' data in same partition (no per-chain isolation)  
❌ Cannot isolate maintenance per chain  

**Best For:** Typical audit log use cases; time-series data; retention policies

**Example Archive Workflow:**
```sql
-- Each week, archive old partition
ALTER TABLE EPS.AUDIT_ACCESS_LOG
SWITCH PARTITION 1 TO EPS.AUDIT_ACCESS_LOG_ARCHIVE;

-- Drop old partition
DROP TABLE EPS.AUDIT_ACCESS_LOG_ARCHIVE;
```

---

### OPTION 3: HYBRID - CHAIN_ID PARTITIONING + INDEXED VIEWS FOR DATES

**Concept:** Partition by CHAIN_ID, then create indexed views simulating date boundaries

**Implementation:**
```sql
-- Physical partition by CHAIN_ID
CREATE PARTITION FUNCTION pf_AUDIT_CHAINID (INT)
AS RANGE LEFT FOR VALUES (1000, 5000, 50000, 100000, 130000);

CREATE PARTITION SCHEME ps_AUDIT_CHAINID
AS PARTITION pf_AUDIT_CHAINID ALL TO ([PRIMARY]);

-- Clustered index
CREATE CLUSTERED INDEX CIX_AUDIT_CHAINID
ON EPS.AUDIT_ACCESS_LOG (CHAIN_ID, AUDIT_TIMESTAMP)
ON ps_AUDIT_CHAINID(CHAIN_ID);

-- Create indexed view for each week
CREATE VIEW v_AUDIT_WEEK1 WITH SCHEMABINDING AS
SELECT * FROM EPS.AUDIT_ACCESS_LOG 
WHERE AUDIT_TIMESTAMP >= '2026-06-10' 
  AND AUDIT_TIMESTAMP < '2026-06-17';

CREATE UNIQUE CLUSTERED INDEX CIX_V_AUDIT_WEEK1
ON v_AUDIT_WEEK1 (CHAIN_ID, AUDIT_TIMESTAMP);

-- Repeat for weeks 2-6...
```

**Advantages:**
⚠️ Mimics composite structure  
⚠️ Both dimensions queryable with indexes  

**Disadvantages:**
❌ **Complex to maintain** (views + indexes)  
❌ **Not true partitioning** (management overhead)  
❌ Indexed views require NOEXPAND hint  
❌ Loses partition switching benefits  

**Best For:** NOT RECOMMENDED unless strongly mandated

---

### OPTION 4: SHARDED TABLES - SEPARATE TABLE PER CHAIN RANGE

**Concept:** Create 6 separate physical tables (one per CHAIN_ID range), each partitioned by AUDIT_TIMESTAMP

**Implementation:**
```sql
-- Table 1: CHAIN_ID 1-1000
CREATE TABLE EPS.AUDIT_ACCESS_LOG_RANGE1 (
    AUDIT_LOG_ID INT PRIMARY KEY,
    CHAIN_ID INT,
    AUDIT_TIMESTAMP DATETIME2,
    ACTION VARCHAR(50),
    USER_ID INT,
    -- all other columns
)
ON ps_AUDIT_TS(AUDIT_TIMESTAMP);  -- Partitioned by date

-- Table 2: CHAIN_ID 1001-5000
CREATE TABLE EPS.AUDIT_ACCESS_LOG_RANGE2 (
    -- same structure
)
ON ps_AUDIT_TS(AUDIT_TIMESTAMP);

-- Table 3: CHAIN_ID 5001-50000
CREATE TABLE EPS.AUDIT_ACCESS_LOG_RANGE3 (
    -- same structure
)
ON ps_AUDIT_TS(AUDIT_TIMESTAMP);

-- ... repeat for RANGE4, RANGE5, RANGE6

-- Create UNION view for transparent access
CREATE VIEW EPS.AUDIT_ACCESS_LOG AS
SELECT * FROM EPS.AUDIT_ACCESS_LOG_RANGE1
UNION ALL SELECT * FROM EPS.AUDIT_ACCESS_LOG_RANGE2
UNION ALL SELECT * FROM EPS.AUDIT_ACCESS_LOG_RANGE3
UNION ALL SELECT * FROM EPS.AUDIT_ACCESS_LOG_RANGE4
UNION ALL SELECT * FROM EPS.AUDIT_ACCESS_LOG_RANGE5
UNION ALL SELECT * FROM EPS.AUDIT_ACCESS_LOG_RANGE6;
```

**Physical Structure:**
```
6 Tables × 6 Date Partitions = 36 Physical Partitions
├── RANGE1 (CHAIN_ID 1-1000)
│   ├── P1_20260610 (Partition: Jun 10-15)
│   ├── P2_20260622 (Partition: Jun 15-22)
│   └── ... P6_20260720
├── RANGE2 (CHAIN_ID 1001-5000)
│   ├── P1_20260610
│   ├── P2_20260622
│   └── ... P6_20260720
└── ... (RANGE3-6)
```

**Performance Profile:**
| Query Type | Performance |
|-----------|-------------|
| `WHERE CHAIN_ID = 102` | ⭐⭐⭐⭐⭐ Excellent (goes to RANGE1) |
| `WHERE AUDIT_TIMESTAMP > '2026-07-01'` | ⭐⭐⭐⭐⭐ Excellent (partition elim) |
| `WHERE CHAIN_ID = 102 AND AUDIT_TIMESTAMP > '2026-07-01'` | ⭐⭐⭐⭐⭐ Excellent (both optimized) |

**Advantages:**
✅ **Best Oracle compatibility** (closest to composite structure)  
✅ **Excellent for both query dimensions** (both get partition elim)  
✅ Per-chain isolation maintained  
✅ Per-chain backup/recovery possible  
✅ Per-chain maintenance windows work  

**Disadvantages:**
❌ **High management complexity** (6 separate tables to maintain)  
❌ Backup/restore more complex (6 tables)  
❌ Cross-chain queries slower (UNION query)  
❌ Application logic needed to route inserts to correct table  
❌ Constraints harder to manage (FKs point to multiple tables)  

**Best For:** IF you absolutely must replicate Oracle's composite structure AND have dedicated DBA support

---

### OPTION 5: NO PARTITIONING - INDEX-BASED APPROACH (SIMPLEST)

**Concept:** Skip partitioning; rely on optimized indexes only

**Implementation:**
```sql
-- Clustered index on date (most common audit queries)
CREATE CLUSTERED INDEX CIX_AUDIT_TS_CHAINID
ON EPS.AUDIT_ACCESS_LOG (AUDIT_TIMESTAMP, CHAIN_ID);

-- Non-clustered index for chain-filtered queries
CREATE NONCLUSTERED INDEX NIX_AUDIT_CHAINID
ON EPS.AUDIT_ACCESS_LOG (CHAIN_ID, AUDIT_TIMESTAMP)
INCLUDE (ACTION, USER_ID, ...);

-- Filtered index for hot data (recent audits only)
CREATE NONCLUSTERED INDEX NIX_AUDIT_RECENT
ON EPS.AUDIT_ACCESS_LOG (AUDIT_TIMESTAMP, CHAIN_ID)
WHERE AUDIT_TIMESTAMP >= DATEADD(DAY, -7, CAST(GETDATE() AS DATE))
INCLUDE (ACTION, USER_ID);
```

**Performance Profile:**
| Query Type | Performance | Notes |
|-----------|-------------|-------|
| `WHERE AUDIT_TIMESTAMP > '2026-07-01'` | ⭐⭐⭐⭐ Very Good | Index seek + range scan |
| `WHERE CHAIN_ID = 102` | ⭐⭐⭐⭐ Very Good | Index seek |
| `WHERE CHAIN_ID = 102 AND AUDIT_TIMESTAMP > '2026-07-01'` | ⭐⭐⭐⭐⭐ Excellent | Both columns in index |

**Advantages:**
✅ **Simplest to implement** (no partitioning management)  
✅ Excellent performance with good indexes  
✅ No partition management overhead  
✅ Suitable if table < 500 GB  

**Disadvantages:**
❌ Zero partition-level isolation  
❌ Cannot use partition switching for archival  
❌ Full table scans possible if indexes unused  
❌ Less granular control for very large tables  
❌ Retention requires delete statements (slower)  

**Best For:** Small to medium audit tables; low DBA overhead desired

---

## COMPARISON MATRIX

### Implementation Complexity vs Performance Trade-off

| Option | Implementation | Chain Queries | Date Queries | Both (Typical) | Archive | Mgmt Overhead | Recommendation |
|--------|----------------|---------------|--------------|---|---------|---------------|---|
| **1** | Medium | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⚠️ | Medium | Chain-focused workloads |
| **2** | Medium | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Low | **✅ RECOMMENDED** |
| **3** | High | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⚠️ | High | Only if mandated |
| **4** | Very High | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Very High | Oracle replication required |
| **5** | Low | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ❌ | Very Low | Small tables (< 500GB) |

---

## RECOMMENDED APPROACH

### For EPS.ADDRESS
**Recommendation: PARTITION BY CHAIN_ID (Option 1 equivalent)**

- Straightforward conversion of Oracle LIST partitioning
- 6 partitions covering all CHAIN_ID values
- Familiar query patterns for address lookups
- Per-chain maintenance supported

**Why this works:** Master data is naturally partitioned by business entity (chain)

---

### For EPS.AUDIT_ACCESS_LOG
**Recommendation: PARTITION BY AUDIT_TIMESTAMP (Option 2)** ⭐⭐⭐

**Rationale:**
1. **Audit logs are time-series data** — queries naturally filter by date range
   - "Show me audit logs from last 7 days"
   - "Show me audit logs from Jan 2026"
   - "Show me today's activity"

2. **Retention is time-driven** — archive/purge policies based on age
   - "Delete audit logs > 90 days old"
   - "Archive last quarter's logs"
   - "Keep only 1 year of data"

3. **Weekly cycles are natural and predictable**
   - Monday: Archive last week
   - Friday: Report on this week
   - Standard DBA maintenance windows

4. **Partition switching is powerful** — Move entire week without INSERT/DELETE
   ```sql
   -- Fast: Move 1 week of data in seconds
   ALTER TABLE EPS.AUDIT_ACCESS_LOG
   SWITCH PARTITION 1 TO EPS.AUDIT_ACCESS_LOG_ARCHIVE;
   ```

5. **Operational simplicity** — 6 partitions vs Oracle's 6,031
   - Simpler monitoring
   - Faster partition elimination
   - Predictable performance

6. **Performance is excellent for typical workloads**
   - Date-range queries: Partition elimination ⭐⭐⭐⭐⭐
   - Chain + date queries: Partition + index ⭐⭐⭐⭐⭐
   - Chain-only queries: Index scan ⭐⭐⭐⭐

### Implementation Summary (Option 2)
```sql
-- 1. Partition by AUDIT_TIMESTAMP (6 weekly ranges)
CREATE PARTITION FUNCTION pf_AUDIT_TS (DATETIME2)
AS RANGE RIGHT FOR VALUES (
    '2026-06-15', '2026-06-22', '2026-06-29', 
    '2026-07-06', '2026-07-13', '2026-07-20'
);

-- 2. Map to primary filegroup
CREATE PARTITION SCHEME ps_AUDIT_TS
AS PARTITION pf_AUDIT_TS ALL TO ([PRIMARY]);

-- 3. Clustered index on partition scheme
CREATE CLUSTERED INDEX CIX_AUDIT_TS_CHAINID
ON EPS.AUDIT_ACCESS_LOG (AUDIT_TIMESTAMP, CHAIN_ID)
ON ps_AUDIT_TS(AUDIT_TIMESTAMP);

-- 4. Supporting index for chain queries
CREATE NONCLUSTERED INDEX NIX_AUDIT_CHAINID
ON EPS.AUDIT_ACCESS_LOG (CHAIN_ID, AUDIT_TIMESTAMP);
```

---

## DECISION QUESTIONS FOR CLIENT

### Critical Decisions Required:

#### Q1: Query Pattern Priority
**Which query pattern is MORE important for EPS.AUDIT_ACCESS_LOG?**

- A) Chain-filtered queries: "Show me all audits for CHAIN_ID 102"
  - **→ Choose Option 1** (PARTITION BY CHAIN_ID)
- B) Date-range queries: "Show me audits from last 7 days"
  - **→ Choose Option 2** (PARTITION BY AUDIT_TIMESTAMP) ⭐ **RECOMMENDED**
- C) Both equally important, and we need per-chain isolation
  - **→ Choose Option 4** (Sharded Tables — with higher complexity cost)

**Typical Answer:** Most audit systems are queried by date range → **Option 2 wins**

---

#### Q2: Retention & Archive Strategy
**How will you manage audit log retention?**

- A) "Delete audit logs older than 90 days" (time-based purge)
  - **→ Strongly favors Option 2** (PARTITION BY AUDIT_TIMESTAMP)
  - Partition switching makes this operation fast (seconds vs hours)

- B) "Keep last 5 years of audit data" (indefinite retention)
  - **→ Could work with Option 1 or 2**
  - Less pressure on retention, but Option 2 still simpler

- C) "Archive by chain to separate storage, keep for 2 years"
  - **→ Favors Option 4** (Sharded Tables)
  - Per-chain backup/restore is critical

**Typical Answer:** Time-based purge is standard → **Option 2 wins**

---

#### Q3: Per-Chain Operational Isolation
**Do you need separate maintenance windows per pharmacy chain?**

- A) Yes, some chains require isolated backup/recovery schedules
  - **→ Consider Option 4** (Sharded Tables)
  - Adds significant complexity; only if justified by business need

- B) No, we're fine with shared maintenance across all chains
  - **→ Choose Option 2** (PARTITION BY AUDIT_TIMESTAMP)
  - Simpler, lower cost, easier to manage

**Typical Answer:** Shared maintenance is preferred → **Option 2 wins**

---

#### Q4: DBA Support & Complexity Tolerance
**What is your team's capacity for partition management?**

- A) We have dedicated DBA(s) and want maximum flexibility
  - **→ Option 4** (Sharded Tables) is acceptable
  - Provides best Oracle parity and query performance

- B) We have moderate DBA support; prefer simplicity
  - **→ Option 2** (PARTITION BY AUDIT_TIMESTAMP) ⭐ **RECOMMENDED**
  - 6 partitions, weekly cycles, easy to manage

- C) We prefer minimal maintenance overhead
  - **→ Option 5** (No Partitioning, Index-Based)
  - Lowest complexity; works for small to medium tables

**Typical Answer:** Balanced approach → **Option 2 wins**

---

#### Q5: Table Size & Growth Projection
**What is your expected EPS.AUDIT_ACCESS_LOG table size?**

- A) Small (< 50 GB)
  - **→ Option 5** (Index-Based) is viable and simple

- B) Medium (50-500 GB)
  - **→ Option 2** (PARTITION BY AUDIT_TIMESTAMP) ⭐ **RECOMMENDED**
  - Good balance of performance and management

- C) Large (> 500 GB) with rapid growth
  - **→ Option 2 or Option 4**
  - Partitioning is mandatory; date-based partitioning is easier to manage

**Typical Answer:** Medium size + growth → **Option 2 wins**

---

#### Q6: Oracle Compatibility & Migration Risk
**How critical is exact replication of Oracle's composite partitioning?**

- A) Critical — Our application expects composite structure
  - **→ Choose Option 4** (Sharded Tables)
  - Only way to truly replicate Oracle's composite behavior

- B) Important but not critical — We can adapt to Azure's constraints
  - **→ Choose Option 2** (PARTITION BY AUDIT_TIMESTAMP) ⭐ **RECOMMENDED**
  - Better performance and simpler for Azure

- C) Not critical — We'll optimize for Azure SQL best practices
  - **→ Choose Option 2 or Option 5**
  - Leverage Azure's strengths, not Oracle's model

**Typical Answer:** Adapt to Azure → **Option 2 wins**

---

## FINAL RECOMMENDATION SUMMARY

| Table | Recommendation | Partitions | Key Benefit |
|-------|---|---|---|
| **EPS.ADDRESS** | PARTITION BY CHAIN_ID | 6 value ranges | Direct Oracle LIST conversion; chain isolation |
| **EPS.AUDIT_ACCESS_LOG** | **PARTITION BY AUDIT_TIMESTAMP** | **6 weekly ranges** | **Time-series optimization; easy archive/purge** |

### Why Option 2 for AUDIT_ACCESS_LOG?

✅ **Best overall balance** — Performance + simplicity  
✅ **Optimizes typical audit queries** — Date-range filtering  
✅ **Supports retention policies** — Weekly archive/purge with partition switching  
✅ **Lower management cost** — 6 simple partitions vs 6,031 complex subpartitions  
✅ **Azure SQL native** — Leverages Azure's strengths, not Oracle's model  
✅ **Production proven** — Industry standard for audit log partitioning  

### When to Consider Alternatives?

- **Use Option 1** if most queries filter by CHAIN_ID first
- **Use Option 4** if you must replicate Oracle composite structure exactly AND have dedicated DBA support
- **Use Option 5** if table is small (<100 GB) and you prefer zero partition management

---

## NEXT STEPS

1. **Client Review** — Review this document with stakeholders
2. **Answer Decision Questions** — Provide answers to Q1-Q6 above
3. **Validate Assumptions** — Confirm typical query patterns from application team
4. **Proof of Concept** — Optional: Test performance with sample data using Option 2
5. **Detailed Design** — Create complete DDL scripts and maintenance procedures
6. **Implementation Plan** — Schedule migration with cutover strategy
7. **Go/No-Go Decision** — Final approval before production deployment

---

## APPENDIX: GLOSSARY

**Partition Function:** SQL object defining partition boundaries (e.g., RANGE LEFT boundaries)

**Partition Scheme:** SQL object mapping partition function to storage (e.g., filegroups)

**Partition Elimination:** Query optimization that reads only relevant partitions (not full table)

**Partition Switching:** Fast operation to move partition data between tables (used for archive)

**LIST Partitioning:** Oracle's method of assigning specific values to named partitions

**RANGE Partitioning:** Azure SQL's method of assigning value ranges to numbered partitions

**Composite Partitioning:** Oracle's feature combining PRIMARY (LIST) + SECONDARY (RANGE) partitioning

**Sharding:** Application-level partitioning with separate physical tables per partition key

---

**Document Prepared For:** Client Review  
**Status:** Ready for Discussion  
**Next Review Date:** After client feedback received

