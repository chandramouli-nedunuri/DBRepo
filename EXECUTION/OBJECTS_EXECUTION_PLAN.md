# Functions, Indexes & Triggers - Migration Plan

**Date:** June 26, 2026  
**Phase:** 4b - Advanced Objects Deployment  
**Status:** Planning → Execution

---

## Object Inventory

### 1. **Triggers** ✅ Found
- **Location:** `EPR/EPS/Triggers/` (50+ files)
- **Count:** ~50 audit triggers (AUR, AIUR, BIUR patterns)
- **Types:** AFTER UPDATE, AFTER INSERT/UPDATE, BEFORE INSERT
- **Purpose:** Audit trail logging to _AUDIT tables
- **Status:** All well-converted to T-SQL
- **Sample Triggers:**
  - EPS.ADDRESS_AUR (AFTER UPDATE)
  - EPS.PATIENT_TRIG_AIUR (AFTER INSERT/UPDATE)
  - EPS.RX_TX_AUR (AFTER UPDATE)
  - EPS.PATIENT_TRIG_BIUR (BEFORE INSERT)

### 2. **Functions** ✅ Found
- **Location:** `EPR/EPS/packages/` (as stored procedures)
- **Count:** ~21 package files with embedded functions
- **Types:** 
  - Package procedures (EPS.CS_SUPPORT_*)
  - Audit logging functions
  - Business logic procedures
- **Status:** Already converted as procedures in packages
- **Examples:**
  - EPS.CS_SUPPORT_log_audit_dbu
  - EPS.CS_SUPPORT_log_error
  - EPS.CS_SUPPORT_dbu_address
  - EPS.PKG_AUDIT_* functions

### 3. **Indexes** ⏳ Need Creation
- **Location:** No dedicated folder (requires custom creation)
- **Count:** Unknown (~20-50 estimated)
- **Types:** 
  - Non-clustered indexes on FK columns
  - Filtered indexes on active records
  - Composite indexes on frequently joined columns
- **Status:** Need to create based on query patterns
- **Candidates:**
  - Indexes on CHAIN_ID (multi-table)
  - Indexes on PATIENT_ID (FK references)
  - Indexes on date columns (WHERE clauses)

---

## Execution Strategy

### Phase 1: Deploy Triggers (50+) 🔴
**Duration:** ~30 minutes  
**Risk:** LOW  
**Impact:** Audit trail functionality

1. ✅ Collect all trigger SQL files
2. ✅ Create batch execution script
3. ⏳ **Execute in Azure SQL**
4. ✅ Validate creation count

### Phase 2: Deploy Package Functions (21+) 🟠
**Duration:** ~20 minutes  
**Risk:** LOW  
**Impact:** Business logic, data maintenance

1. ✅ Inventory package procedures
2. ✅ Create execution script
3. ⏳ **Execute in Azure SQL**
4. ✅ Test sample procedures

### Phase 3: Create Indexes (20-50) 🟡
**Duration:** ~15 minutes  
**Risk:** MEDIUM  
**Impact:** Query performance

1. ✅ Analyze current tables for index candidates
2. ✅ Generate CREATE INDEX statements
3. ⏳ **Execute in batches**
4. ✅ Measure performance impact

---

## Recommended Execution Order

```
1️⃣ TRIGGERS    (50+)  → Audit functionality      → ~5 minutes
2️⃣ FUNCTIONS   (21+)  → Business logic            → ~3 minutes
3️⃣ INDEXES     (20-50) → Performance optimization → ~10 minutes
```

**Total Expected Time:** 20-30 minutes

---

## Success Criteria

| Component | Criterion | Verification |
|-----------|-----------|--------------|
| **Triggers** | All ~50 triggers created without errors | SELECT COUNT(*) FROM sys.triggers WHERE schema_id = 5 |
| **Functions** | All procedures in packages executable | EXEC sp_stored_procedures |
| **Indexes** | All indexes created and enabled | SELECT COUNT(*) FROM sys.indexes |
| **Performance** | Query execution time < baseline | Run explain plan |
| **No Errors** | Zero error log entries | Check ERRORLOG |

---

## Next Actions

- [ ] **STEP 1:** Execute all triggers from Triggers/ folder
- [ ] **STEP 2:** Execute all package procedures
- [ ] **STEP 3:** Create and execute indexes
- [ ] **STEP 4:** Validate all objects in Azure
- [ ] **STEP 5:** Update migration summary

---

**Ready to proceed? Execute in this order:**
1. Generate Trigger Batch Script
2. Execute Triggers
3. Execute Package Functions
4. Create & Execute Indexes
5. Final Validation
