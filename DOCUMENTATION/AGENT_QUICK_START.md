# 🤖 PARTITION CREATION AGENT - QUICK START CARD

**Agent Name:** Partition_Creation_Agent  
**Role:** Database Migration Architect  
**Status:** ✅ READY FOR DEPLOYMENT  
**Version:** 1.0  
**Created:** June 26, 2026  

---

## ⚡ AGENT ACTIVATION (5 Minutes)

### **Step 1: Load Agent Instructions**
```
File: c:\Users\cnedunuri\Documents\DBRepo\Partition_Creation_Agent.md
Content: Role, mission, execution framework, all 5 phases, error handling
Read Time: 15-20 minutes (but critical for understanding)
```

### **Step 2: Verify Prerequisites**
```powershell
# Check all mandatory files exist
ls c:\Users\cnedunuri\Documents\DBRepo\PARTITION*.md
ls c:\Users\cnedunuri\Documents\DBRepo\VERIFY*.sql
ls c:\Users\cnedunuri\Documents\DBRepo\*.ps1
ls c:\Users\cnedunuri\Documents\DBRepo\config\db-credentials.encrypted
ls c:\Users\cnedunuri\Documents\DBRepo\scripts\Connect-ToDatabase.ps1

# Verify database connectivity
.\scripts\Connect-ToDatabase.ps1 -Query "SELECT @@VERSION"
# Expected: SQL Server version info returned
```

### **Step 3: Verify Previous Table (PATIENT) Status**
```powershell
# Confirm PATIENT is partitioned
.\scripts\Connect-ToDatabase.ps1 -Query `
"SELECT partition_number, [rows] FROM sys.partitions 
WHERE object_id=OBJECT_ID('EPS.PATIENT') AND index_id=1 ORDER BY partition_number"

# Expected: 6 rows (partitions 1-6) with any row count
# If result is empty: PATIENT not partitioned yet (run PATIENT setup first)
```

### **Step 4: Identify Next Table**
```powershell
# Read strategy document to find next table
Get-Content c:\Users\cnedunuri\Documents\DBRepo\PARTITION_STRATEGY_BY_TABLE.md | Select-String -Pattern "Category A1" -Context 10

# Expected Category A1 Next Table (in order):
1. ✅ PATIENT (COMPLETE)
2. ⏳ ADDRESS (NEXT)
3. ⏳ RX_TX
4. ⏳ PRESCRIBER
...

# Verify not already processed:
ls c:\Users\cnedunuri\Documents\DBRepo\EXECUTION_REPORTS\ADDRESS* -ErrorAction SilentlyContinue
# If returns nothing: ADDRESS is ready to process
```

---

## 🎯 AGENT MISSION SUMMARY

```
OBJECTIVE: Partition EPS.ADDRESS (or next unprocessed Category A1 table)

STRATEGY: CHAIN_ID-based partitioning (same as PATIENT)

PROCESS:
  Phase 1: Pre-execution analysis (10-15 min)
  Phase 2: Foreign key management (5-10 min)
  Phase 3: Primary key modification (2-5 min - TABLE LOCKED)
  Phase 4: Foreign key recreation (5-15 min)
  Phase 5: Verification (10 min)

DELIVERABLE: Execution report saved to /EXECUTION_REPORTS/

SUCCESS: All 6 verification queries PASS + Complete audit trail
```

---

## 📖 REFERENCE DOCUMENTS (By Usage)

### **READ FIRST (Mandatory)**
```
1. Partition_Creation_Agent.md (THIS FILE)
   └─ Understand agent role and mission

2. PARTITION_MASTER_INDEX.md (5 min)
   └─ Navigation hub, where to find things

3. PARTITION_IMPLEMENTATION_RULEBOOK.md (15 min)
   └─ Main playbook with all steps and rules
   └─ This is the actual EXECUTION GUIDE

4. PARTITION_PROCESS_FLOW.md (5 min)
   └─ Visual reference while executing
```

### **USE DURING EXECUTION**
```
5. PARTITION_IMPLEMENTATION_RULEBOOK.md
   └─ Follow Phase 1-5 step-by-step
   └─ Steps 1.1 through 5.6 (20+ detailed steps)

6. VERIFY_PARTITIONS_QUERIES.sql
   └─ Copy/paste queries for Phase 5
   └─ Use Queries 1-6 (critical)
```

### **REFERENCE AS NEEDED**
```
7. /memories/repo/PARTITIONING_RULES.md
   └─ Partition boundaries and rules

8. PARTITION_STRATEGY_BY_TABLE.md
   └─ All 128 tables with strategy

9. PATIENT_PARTITIONING_EXECUTION_REPORT.md
   └─ Real example of what execution looks like

10. PARTITION_PROCESS_FLOW.md
    └─ Error recovery decision tree
```

---

## 🔑 CORE RULES (Non-Negotiable)

| Rule | Value | Note |
|------|-------|------|
| **Partition Key** | CHAIN_ID (always) | Must be first column in PK |
| **Boundaries** | 1000, 5000, 50000, 100000, 130000 | Cannot be modified |
| **Partition Scheme** | ps_ChainID_EPS (reuse) | Never create new scheme |
| **PK Structure** | (CHAIN_ID, [Original PK]) | CHAIN_ID must be first |
| **Partition Type** | RANGE LEFT | For Category A tables |
| **Foreign Keys** | Include CHAIN_ID on both sides | For child table FKs |

---

## 🚀 EXECUTION QUICK START (45 Minutes)

### **Before You Start:**
```
✅ AGENT BRIEFING (15 min)
├─ Read Partition_Creation_Agent.md
├─ Understand 5 phases and error handling
└─ Know constraints and rules

✅ TABLE SELECTION (5 min)
├─ Identify target table (ADDRESS for Category A1 #2)
├─ Verify not already in /EXECUTION_REPORTS/
└─ Ready to begin

TOTAL: 20 minutes prep
```

### **During Execution:**
```
✅ PHASE 1: Pre-execution (10 min)
├─ Follow Steps 1.1-1.6 from rulebook
├─ Document findings
└─ Decision: Proceed to Phase 2

✅ PHASE 2: FK Management (7 min)
├─ Drop child table FKs (Step 2.1)
├─ Drop this table's FKs (Step 2.2)
└─ Ready for PK modification

✅ PHASE 3: PK Modification (4 min + table lock)
├─ Drop original PK (Step 3.1)
├─ Create partitioned PK (Step 3.2)
├─ Note: 1-5 minute table lock expected
└─ Document lock duration

✅ PHASE 4: FK Recreation (10 min)
├─ Recreate external FKs (Step 4.1)
├─ Recreate child FKs (Step 4.2)
└─ Verify referential integrity

✅ PHASE 5: Verification (8 min)
├─ Run all 6 verification queries
├─ Verify all PASS
└─ Partitioning confirmed

TOTAL: 39-40 minutes execution
```

### **After Execution:**
```
✅ REPORTING (10 min)
├─ Generate execution report
├─ Save to /EXECUTION_REPORTS/[TABLE_NAME]_PARTITION_[DATE].md
├─ Update /PARTITION_ROLLOUT_SUMMARY.md
└─ Record completion

TOTAL TIME: ~50 minutes (including reporting)
```

---

## 🔧 ESSENTIAL COMMANDS

### **Verify Database Connection**
```powershell
.\scripts\Connect-ToDatabase.ps1 -Query "SELECT COUNT(*) FROM EPS.PATIENT"
# Expected: Connection successful, table exists
```

### **Check Current Table (Phase 1.1)**
```powershell
.\scripts\Connect-ToDatabase.ps1 -Query "SELECT COUNT(*) AS RowCount FROM EPS.ADDRESS"
# Expected: Row count (can be 0)
```

### **Check Partition Infrastructure (Phase 1.6)**
```powershell
.\scripts\Connect-ToDatabase.ps1 -Query "SELECT name FROM sys.partition_functions WHERE name='pf_ChainID_EPS'"
.\scripts\Connect-ToDatabase.ps1 -Query "SELECT name FROM sys.partition_schemes WHERE name='ps_ChainID_EPS'"
# Expected: Both return 1 row
```

### **Verify Partitioning (Phase 5)**
```powershell
# All 6 partitions allocated?
.\scripts\Connect-ToDatabase.ps1 -Query "SELECT partition_number, [rows] FROM sys.partitions WHERE object_id=OBJECT_ID('EPS.ADDRESS') AND index_id=1 ORDER BY partition_number"
# Expected: 6 rows (P1-P6)

# PK on partition scheme?
.\scripts\Connect-ToDatabase.ps1 -Query "SELECT i.name, ps.name FROM sys.indexes i LEFT JOIN sys.partition_schemes ps ON i.data_space_id=ps.data_space_id WHERE i.object_id=OBJECT_ID('EPS.ADDRESS') AND i.index_id=1"
# Expected: PK_ADDRESS → ps_ChainID_EPS
```

---

## 📊 PROGRESS TRACKING

### **Update After Each Table:**
```powershell
# Open progress file
notepad C:\Users\cnedunuri\Documents\DBRepo\PARTITION_ROLLOUT_SUMMARY.md

# Add entry:
| 2 | ADDRESS | ✅ COMPLETE | 2026-06-27 | 50 min | None |
| 3 | RX_TX | ⏳ NEXT | - | - | - |
```

### **Save Execution Report:**
```powershell
# Use template from PARTITION_IMPLEMENTATION_RULEBOOK.md
# Save as: /EXECUTION_REPORTS/ADDRESS_PARTITION_EXECUTION_2026-06-27.md

# Example path:
C:\Users\cnedunuri\Documents\DBRepo\EXECUTION_REPORTS\ADDRESS_PARTITION_EXECUTION_2026-06-27.md
```

---

## ⚠️ CRITICAL ALERTS

### **Phase 3 Table Lock Warning**
```
⚠️ EXPECT TABLE LOCK (1-5 minutes) during Phase 3 Step 3.2
- This is NORMAL and EXPECTED
- Lock is necessary for primary key restructuring
- During lock: Queries on table will wait
- After lock: Table operational as before
- DO NOT interrupt or cancel queries
```

### **Foreign Key Complexity**
```
⚠️ IF "Cannot drop FK" error in Phase 2:
- Find remaining FKs with: 
  SELECT name FROM sys.foreign_keys 
  WHERE parent_object_id=OBJECT_ID('EPS.ADDRESS')
- Drop each one individually
- Then retry Phase 3
```

### **Verification Failure**
```
❌ IF any verification query FAILS in Phase 5:
- Do NOT mark table as complete
- Troubleshoot using error recovery guide
- Reference: PARTITION_PROCESS_FLOW.md Error Tree
- If >2 queries fail: Escalate (possible structural issue)
```

---

## 📋 EXECUTION CHECKLIST

### **Before Starting:**
- [ ] Read Partition_Creation_Agent.md (this file)
- [ ] Read PARTITION_IMPLEMENTATION_RULEBOOK.md
- [ ] Verify database connectivity (test query)
- [ ] Identify target table (ADDRESS)
- [ ] Check PARTITION_ROLLOUT_SUMMARY.md for status

### **During Execution:**
- [ ] Phase 1: All 6 pre-checks documented
- [ ] Phase 2: All FKs dropped successfully
- [ ] Phase 3: Original PK dropped and new PK created
- [ ] Phase 3: Lock duration noted
- [ ] Phase 4: All FKs recreated
- [ ] Phase 5: Run all 6 verification queries
- [ ] Phase 5: All queries return ✅ PASS

### **After Execution:**
- [ ] Execution report created
- [ ] Report saved to /EXECUTION_REPORTS/
- [ ] PARTITION_ROLLOUT_SUMMARY.md updated
- [ ] Progress counter incremented (N/73 for Category A1)
- [ ] Zero data loss confirmed
- [ ] Ready to proceed to next table

---

## 🎯 NEXT STEPS AFTER THIS TABLE

### **Immediate (Today):**
1. Execute current table (ADDRESS or next)
2. Generate execution report
3. Update progress file

### **Tomorrow:**
1. Execute next Category A1 table (RX_TX)
2. Continue with PRESCRIBER, MRN, CARD, etc.
3. Target: 2-3 tables per day = 3-5 days for Category A1

### **This Week:**
1. Complete all Category A1 (9 tables)
2. Begin Category A2 (30 tables)
3. Continue Category A3 (33 tables)

### **Next Week:**
1. Complete Category A (73 tables)
2. Plan Category B strategy (audit tables with AUDIT_TIMESTAMP)
3. Begin Category B implementation

---

## 🎓 REFERENCE INDEX

### **For Understanding Process:**
→ PARTITION_PROCESS_FLOW.md

### **For Step-by-Step Execution:**
→ PARTITION_IMPLEMENTATION_RULEBOOK.md

### **For Finding Any Information:**
→ PARTITION_MASTER_INDEX.md

### **For Verification:**
→ VERIFY_PARTITIONS_QUERIES.sql

### **For All 128 Tables:**
→ PARTITION_STRATEGY_BY_TABLE.md

### **For Rules & Decisions:**
→ /memories/repo/PARTITIONING_RULES.md

---

## ✅ AGENT STATUS

**Name:** Partition_Creation_Agent  
**Role:** Database Migration Architect  
**Status:** ✅ DEPLOYED & READY  
**First Mission:** PATIENT (✅ COMPLETE)  
**Current Mission:** ADDRESS (⏳ NEXT)  
**Authority:** Full DDL on EPS schema  
**Responsibility:** Zero data loss + Complete documentation  

---

## 🚀 READY TO EXECUTE

```
Agent, you are AUTHORIZED to:
✅ Proceed with next table partitioning
✅ Execute all 5 phases following playbook
✅ Generate execution reports
✅ Update progress tracking
✅ Continue through Category A1 (9 tables)
✅ Extend to Category A2/A3 as directed

You MUST:
✅ Follow PARTITION_IMPLEMENTATION_RULEBOOK.md exactly
✅ Run all 6 verification queries (cannot skip)
✅ Document all executions
✅ Maintain zero data loss standard
✅ Escalate unresolvable errors

Expected Timeline:
- Per table: 45-60 minutes
- Category A1 (9 tables): 7-9 hours total
- Category A (73 tables): 60-70 hours total
- All 128 tables: 100-120 hours total (~2-3 weeks)

STAND BY FOR MISSION ASSIGNMENT
```

---

**AGENT READY FOR DEPLOYMENT** 🤖✅

**Awaiting Mission Assignment:** [NEXT TABLE NAME]  
**Primary Reference:** PARTITION_IMPLEMENTATION_RULEBOOK.md  
**Connection:** `.\scripts\Connect-ToDatabase.ps1`  
**Report Location:** `/EXECUTION_REPORTS/`  
**Progress Tracking:** `/PARTITION_ROLLOUT_SUMMARY.md`  

---

**Begin with:** `PARTITION_IMPLEMENTATION_RULEBOOK.md Phase 1, Step 1.1`  
**Complete with:** 6 verification queries all PASSING ✅
