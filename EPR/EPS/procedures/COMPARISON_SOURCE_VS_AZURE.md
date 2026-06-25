# Procedure Conversion Analysis: Oracle Source vs Azure SQL Target

**Analysis Date:** June 26, 2026  
**Comparison:** Source Oracle → Current Azure Conversion

---

## Summary Table

| # | Procedure Name | Oracle Source | Current Azure | Status | Executability | Notes |
|----|---|---|---|---|---|---|
| 1 | DROP_TASK | Uses DBMS_PARALLEL_EXECUTE | Stub/No-op | ✅ | **EXECUTABLE** | Stub (Azure doesn't have DBMS_PARALLEL_EXECUTE) |
| 2 | HANNAFORD_TP_LINK_UPDATE | **WRAPPED** (encrypted) | **WRAPPED** (encrypted) | ❌ | **CANNOT EXECUTE** | Source code obfuscated - needs original unencrypted source |
| 3 | MEIJER_TP_LINK_UPDATE | **WRAPPED** (encrypted) | **MISSING** from target folder | ❌ | **CANNOT EXECUTE** | Wrapped source + missing file |
| 4 | MEIJER_UPDATE | ROWID + BULK COLLECT + FORALL | Set-based SQL conversion | ✅ | **EXECUTABLE** | Well-converted to T-SQL, fully functional |
| 5 | RESUME_TASK | DBMS_PARALLEL_EXECUTE | Stub/RETURN | ✅ | **EXECUTABLE** | Stub (Azure doesn't have DBMS_PARALLEL_EXECUTE) |
| 6 | SP_RESET_LEVEL_OF | Complex: DBMS_PARALLEL_EXECUTE + nested functions | Set-based CTE + ROW_NUMBER | ✅ | **EXECUTABLE** | Well-converted, all SQL Server features used correctly |
| 7 | SP_REVERSE_ORDER_PURGE | Oracle: EXECUTE IMMEDIATE + partitioning | T-SQL set-based + error handling | ✅ | **EXECUTABLE** | Well-converted, includes proper error handling |
| 8 | SP_STOPTEST | DBMS_PARALLEL_EXECUTE.drop_TASK | Stub/No-op | ✅ | **EXECUTABLE** | Stub (Azure doesn't have DBMS_PARALLEL_EXECUTE) |
| 9 | SP_TEST | DBMS_PARALLEL_EXECUTE (complex) | Stub/No-op | ✅ | **EXECUTABLE** | Stub (Azure doesn't have DBMS_PARALLEL_EXECUTE) |
| 10 | STOPJOB | DBMS_PARALLEL_EXECUTE (stop + drop) | Stub/No-op | ✅ | **EXECUTABLE** | Stub (Azure doesn't have DBMS_PARALLEL_EXECUTE) |

---

## Breakdown by Category

### ✅ READY TO EXECUTE (7 procedures)

#### Fully Functional (3):
1. **MEIJER_UPDATE** ⭐
   - Source: Oracle ROWID-based batch processing with BULK COLLECT/FORALL
   - Azure: Converted to clean set-based UPDATE with WHERE conditions
   - Status: **PRODUCTION READY**
   - No dependencies required

2. **SP_RESET_LEVEL_OF** ⭐
   - Source: DBMS_PARALLEL_EXECUTE with complex chunking logic
   - Azure: Converted to CTE-based approach with ROW_NUMBER() windowing
   - Status: **PRODUCTION READY**
   - Dependencies: tp_link table, eps_sec_chain table

3. **SP_REVERSE_ORDER_PURGE** ⭐
   - Source: EXECUTE IMMEDIATE with partition handling and parallel processing
   - Azure: Set-based SQL with proper transaction control and error handling
   - Status: **PRODUCTION READY**
   - Dependencies: purge_ledger table, purge_seq sequence, RX_TX tables

#### Stubs/Placeholders (4):
- DROP_TASK (no-op for DBMS_PARALLEL_EXECUTE)
- RESUME_TASK (no-op for DBMS_PARALLEL_EXECUTE)
- SP_STOPTEST (no-op for DBMS_PARALLEL_EXECUTE)
- SP_TEST (no-op for DBMS_PARALLEL_EXECUTE)
- STOPJOB (no-op for DBMS_PARALLEL_EXECUTE)

**Status:** ✅ Can execute without errors (but do nothing since DBMS_PARALLEL_EXECUTE doesn't exist in Azure)

---

### ❌ CANNOT EXECUTE (2 procedures)

1. **HANNAFORD_TP_LINK_UPDATE**
   - Source: **WRAPPED/ENCRYPTED** (Oracle obfuscation)
   - Current Azure: **WRAPPED/ENCRYPTED** (same issue persists)
   - Issue: Source code cannot be read, decrypted, or converted
   - Solution: Obtain original unencrypted Oracle source

2. **MEIJER_TP_LINK_UPDATE**
   - Source: **WRAPPED/ENCRYPTED**
   - Current Azure: **MISSING from target procedures folder**
   - Issue: (1) Source is wrapped + (2) File not in Azure target folder
   - Solution: Obtain original unencrypted Oracle source + create Azure conversion

---

## Recommendation

### Execute These 3 Procedures (Production-Ready):
```sql
-- 1. Batch updates for Meijer customer
EXEC EPS.MEIJER_UPDATE;

-- 2. Reset level_of field based on carrier cleanup
EXEC EPS.SP_RESET_LEVEL_OF @p_chain_id = 128, @p_job_class = 'DEFAULT', @p_chunk_size = 2000, @p_parallel_cnt = 8;

-- 3. Purge old prescription records (monthly maintenance)
EXEC EPS.SP_REVERSE_ORDER_PURGE @tab_name = 'RX_TX';
```

### Can Execute (Safe but No-op):
```sql
EXEC EPS.DROP_TASK;      -- No-op (stub)
EXEC EPS.RESUME_TASK;    -- No-op (stub)
EXEC EPS.SP_STOPTEST;    -- No-op (stub)
EXEC EPS.SP_TEST;        -- No-op (stub)
EXEC EPS.STOPJOB;        -- No-op (stub)
```

### Cannot Execute (Need Action):
- **HANNAFORD_TP_LINK_UPDATE** - Get unencrypted source
- **MEIJER_TP_LINK_UPDATE** - Get unencrypted source + create conversion

---

## Key Findings

| Metric | Count |
|--------|-------|
| Total procedures in source | 10 |
| Fully converted & executable | 3 |
| Stubs/Placeholders (safe) | 5 |
| Wrapped/Encrypted (unusable) | 2 |
| **Recommendation: Execute now** | **3** |

---

## Why Stubs Exist for DBMS_PARALLEL_EXECUTE Procedures

Oracle's `DBMS_PARALLEL_EXECUTE` package is **not available in Azure SQL Database**. It's an Enterprise Edition feature for:
- Task-based parallel processing
- Dynamic SQL chunking and execution
- Job queue management

**Azure SQL alternatives:**
1. **For batch processing:** Use application-level threading or Azure Data Factory
2. **For parallel execution:** SQL Server Agent jobs (if using SQL Server) or Elastic jobs (Azure)
3. **For cleanup tasks:** Use stored procedure logic directly (no parallelization package)

The converted procedures use set-based SQL instead, which is often more efficient in SQL Server/Azure than Oracle's row-by-row parallelization.

---

## Files Ready to Execute

✅ [EPS.MEIJER_UPDATE.sql](../EPS.MEIJER_UPDATE.sql)  
✅ [EPS.SP_RESET_LEVEL_OF.sql](../EPS.SP_RESET_LEVEL_OF.sql)  
✅ [EPS.SP_REVERSE_ORDER_PURGE.sql](../EPS.SP_REVERSE_ORDER_PURGE.sql)  

---

## Next Steps

1. **Immediate:** Execute 3 production-ready procedures
2. **Short-term:** Get unencrypted Oracle source for wrapped procedures
3. **Optional:** Remove or repurpose stub procedures (currently safe no-ops)
