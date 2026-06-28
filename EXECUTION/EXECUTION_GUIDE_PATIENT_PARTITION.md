# EXECUTION GUIDE: Partitioning EPS.PATIENT by CHAIN_ID

## QUICK START

**File:** `SQL_PARTITION_PATIENT_READY_TO_EXECUTE.sql`

**Execution Time:** 5-15 minutes  
**Downtime:** ~1 minute during ALTER TABLE  
**Risk Level:** LOW (read-only pre-checks first)

---

## EXECUTION SEQUENCE

### ✅ STEP 1: Run Pre-Execution Checks (NO CHANGES)
**Duration:** 1-2 minutes  
**Action:** SAFE - Read-only, informational only

```
SECTION 1: PRE-EXECUTION CHECKS
├── Check 1: Verify table exists and size
├── Check 2: Verify no existing partitions  
├── Check 3: Check current primary key
├── Check 4: Verify CHAIN_ID column exists
└── Check 5: Check distribution of CHAIN_ID values
```

**What to look for:**
- ✅ Table exists and has rows
- ✅ No partition function/scheme with these names
- ✅ Primary key is identified
- ✅ CHAIN_ID is INT or BIGINT
- ✅ CHAIN_ID values within expected ranges (31-130727)

**If any FAILS:** Stop. Don't proceed. Contact DBA.

---

### ✅ STEP 2: Create Partition Function (ONE TIME)
**Duration:** 5 seconds  
**Action:** Creates shared partition boundaries

**Script Section:** SECTION 2

**What it does:**
- Creates partition boundaries at: 1000, 5000, 50000, 100000, 130000
- Creates 6 partitions for CHAIN_ID values
- Shared by ALL 73 CATEGORY A tables (efficient!)

**Expected result:**
```
Partition 1: CHAIN_ID <= 1000
Partition 2: 1000 < CHAIN_ID <= 5000
Partition 3: 5000 < CHAIN_ID <= 50000
Partition 4: 50000 < CHAIN_ID <= 100000
Partition 5: 100000 < CHAIN_ID <= 130000
Partition 6: CHAIN_ID > 130000
```

**Can be skipped if:** It already exists (check in pre-execution verify query)

---

### ✅ STEP 3: Create Partition Scheme (ONE TIME)
**Duration:** 5 seconds  
**Action:** Maps partition function to storage

**Script Section:** SECTION 3

**What it does:**
- Maps all 6 partitions to PRIMARY filegroup
- Shared by ALL 73 CATEGORY A tables

**Can be skipped if:** It already exists

---

### ⚠️ STEP 4: Apply Partitioning to EPS.PATIENT (TABLE-SPECIFIC, DOWNTIME!)
**Duration:** 1-5 minutes (depends on size)  
**Action:** Converts table to use partitioning  
**⚠️ IMPACT:** Table locked during this step (~30 sec - 5 min)

**Script Section:** SECTION 4

**Substeps:**

**4A: Drop non-clustered indexes** (30 seconds)
- Drops all indexes except primary key
- They'll be recreated on new partition scheme

**4B: Drop primary key constraint** (10 seconds)
- Removes old PK (not partitioned)

**4C: Create new primary key on partition scheme** (30 seconds - 5 min)
- Creates PK with CHAIN_ID included
- ⚠️ **This is where table is locked**
- The longer the table, the longer the lock

---

### ✅ STEP 5: Create Supporting Indexes
**Duration:** 30-60 seconds  
**Action:** Creates optimized indexes for common queries

**Script Section:** SECTION 5

**Indexes created:**
1. **NIX_PATIENT_DOB** — Search by date of birth
2. **NIX_PATIENT_LASTNAME** — Search by patient name  
3. **NIX_PATIENT_MRN** — Search by medical record number
4. **NIX_PATIENT_CREATED_DATE** — Search by creation date

All partition-aligned (use ps_ChainID_EPS)

---

### ✅ STEP 6: Validation & Verification (NO CHANGES)
**Duration:** 1-2 minutes  
**Action:** Confirms everything worked

**Script Section:** SECTION 6

**Checks:**
- ✅ Table is partitioned
- ✅ Data is distributed across 6 partitions
- ✅ Indexes created successfully
- ✅ Partition boundaries correct
- ✅ Partition elimination works (test query)

**Expected output:**
```
TableName: PATIENT
PartitionFunctionName: pf_ChainID_EPS
PartitionSchemeName: ps_ChainID_EPS

Partition 1: XXXX rows
Partition 2: XXXX rows
Partition 3: XXXX rows
Partition 4: XXXX rows
Partition 5: XXXX rows
Partition 6: XXXX rows
```

---

### ✅ STEP 7: Performance Baseline
**Duration:** 1 minute  
**Action:** Tests queries to establish baseline

**Script Section:** SECTION 7

**Queries tested:**
1. Count by CHAIN_ID (partition elimination test)
2. Full table scan (all partitions)
3. Range query on DOB (index usage test)

**Note:** Save execution times to compare BEFORE vs AFTER

---

## HOW TO EXECUTE

### Option A: Execute All at Once (Recommended)
```
1. Open SQL_PARTITION_PATIENT_READY_TO_EXECUTE.sql in Azure Data Studio
2. Click "Run" (or Ctrl+Shift+E)
3. Watch for any errors in output
4. Review validation results
```

**Risk:** Low (pre-checks catch issues before changes)

---

### Option B: Execute Section by Section (Safest)
```
1. Copy SECTION 1 (pre-checks)
2. Run in Azure Data Studio
3. Review output - if all OK, proceed to SECTION 2
4. Copy SECTION 2 (partition function)
5. Run in Azure Data Studio
6. Review output - if OK, proceed to SECTION 3
... and so on
```

**Benefit:** Can stop at any point if issues found

---

### Option C: Execute with Custom Modifications
```
1. Edit the SQL file with your actual column names
2. Replace PATIENT_ID, DOB, etc. with YOUR columns
3. Run as normal
```

---

## CRITICAL DECISION POINTS

### ❓ Decision 1: Table is LOCKED during Step 4C
**Question:** Is this OK? (Do we have downtime window?)

- **YES:** Proceed with execution during maintenance window
- **NO:** This must be done after hours or during scheduled downtime

### ❓ Decision 2: Index names match your standards?
**Question:** Do the index names (NIX_PATIENT_DOB, etc.) follow your naming convention?

- **YES:** Use as-is
- **NO:** Edit the script to change index names before running

### ❓ Decision 3: Are there OTHER indexes on PATIENT?
**Question:** Does EPS.PATIENT have indexes besides those listed?

- **YES:** Edit SECTION 4A to include them, or they'll be dropped
- **NO:** Script handles all indexes

### ❓ Decision 4: Is PATIENT_ID your primary key column?
**Question:** Is PATIENT_ID the actual primary key on EPS.PATIENT?

- **YES:** Script is correct
- **NO:** Edit SECTION 4C to use correct key column

---

## WHAT HAPPENS IF SOMETHING FAILS?

### Failure During Step 2-3 (Pre-partitioning)
**Status:** Safe to retry or skip  
**Action:** Read error message, fix issue, re-run

### Failure During Step 4C (Partition application)
**Status:** May be stuck  
**Action:** 
1. Kill the query (Ctrl+C)
2. Run SECTION 8 (rollback procedure)
3. Fix the issue
4. Retry

### Failure During Step 5 (Index creation)
**Status:** Partial success (table partitioned, some indexes missing)  
**Action:**
1. Run failed index creation manually
2. Or run all of SECTION 5 again

### Unknown Error
**Status:** Check validation (SECTION 6)  
**Action:** Rollback (SECTION 8) if needed, contact DBA

---

## VALIDATION RESULTS TO EXPECT

### After Successful Execution:

**Check 1 Output:**
```
TableName    PartitionSchemeName  Rows
PATIENT      ps_ChainID_EPS       [your row count]
```

**Check 2 Output (Partition Distribution):**
```
PartitionNumber  RowCount
1                XXX        (CHAIN_ID <= 1000)
2                XXX        (1000 < CHAIN_ID <= 5000)
3                XXX        (5000 < CHAIN_ID <= 50000)
4                XXX        (50000 < CHAIN_ID <= 100000)
5                XXX        (100000 < CHAIN_ID <= 130000)
6                XXX        (CHAIN_ID > 130000)
```

**Check 3 Output (Indexes):**
```
IndexName                    Type         IsPrimaryKey
PK_PATIENT                   CLUSTERED    1
NIX_PATIENT_DOB             NONCLUSTERED 0
NIX_PATIENT_LASTNAME        NONCLUSTERED 0
NIX_PATIENT_MRN             NONCLUSTERED 0
NIX_PATIENT_CREATED_DATE    NONCLUSTERED 0
```

---

## ESTIMATED TIME BREAKDOWN

| Step | Duration | Can Skip? |
|------|----------|-----------|
| Pre-checks | 2 min | No (safety critical) |
| Partition Function | 10 sec | Only if exists |
| Partition Scheme | 10 sec | Only if exists |
| **Drop Indexes** | 30 sec | No |
| **Drop PK** | 10 sec | No |
| **Apply Partitioning** | **1-5 min** | **No** ⚠️ (TABLE LOCKED) |
| Create Indexes | 1 min | No |
| Validation | 2 min | No (verify success) |
| Performance Tests | 1 min | Optional |
| **TOTAL** | **~10 minutes** | |

---

## NEXT STEPS AFTER SUCCESS

### Immediate (Same Day)
1. ✅ Run sample queries to confirm performance
2. ✅ Check application logs for any errors
3. ✅ Verify backup/restore procedures still work
4. ✅ Document partitioning applied to PATIENT

### Short-term (This Week)
1. ✅ Apply same partitioning to other A1 tables (ADDRESS, RX_TX, etc.)
2. ✅ Collect baseline performance metrics
3. ✅ Update application documentation

### Medium-term (This Month)
1. ✅ Apply to all 73 CATEGORY A tables
2. ✅ Performance testing across all partitioned tables
3. ✅ Optimize indexes based on query patterns

---

## ROLLBACK (If Needed)

**SECTION 8 contains complete rollback procedure**

Rollback will:
1. ❌ Remove all partition-aligned indexes
2. ❌ Drop partitioned primary key
3. ❌ Recreate non-partitioned primary key
4. ❌ Recreate basic indexes (non-partitioned)
5. ❌ Drop partition scheme and function

**Rollback Duration:** 2-5 minutes

**When to use:** Only if partitioning causes application issues or performance problems

---

## CHECKLIST BEFORE EXECUTION

- [ ] Database backup taken
- [ ] Pre-execution checks run (SECTION 1) and all passed
- [ ] Maintenance window scheduled (if needed for downtime)
- [ ] Column names verified (PATIENT_ID is PK, CHAIN_ID exists, etc.)
- [ ] Index names reviewed and correct
- [ ] Rollback procedure understood
- [ ] Team notified of downtime (if applicable)
- [ ] Application team aware of changes

---

**Ready to execute?** Run the SQL script with all the checks passing!

