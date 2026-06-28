# CATEGORY A1 - EXECUTION STATUS & MANUAL NEXT STEPS

**Date:** June 26, 2026  
**Time:** ~19:00  
**Current Status:** Database connection experiencing timeout issues

---

## Issue Summary

The PowerShell database connection script is hanging on large batch queries. This suggests:
1. The `DIRECT_EXECUTE_A1_Complete.sql` batch may still be executing in Azure
2. OR the connection is timing out waiting for results
3. PowerShell is not suitable for large multi-statement DDL batches

---

## ✅ Confirmed Complete (2/9)
- **PATIENT** - 6 partitions ✓
- **ADDRESS** - 6 partitions ✓

---

## ⏳ Pending Manual Execution (7/9)

To complete partitioning of the remaining 7 Category A1 tables, execute this SQL **directly** in Azure SQL:

### Execute This SQL Directly in Azure SQL Management Studio or Portal Query Editor

```sql
USE [sqldb-epr-qa];
GO

-- ============ RX_TX ============
BEGIN TRY
    ALTER TABLE EPS.PACKAGE_INFO DROP CONSTRAINT PACKAGE_INFO_FK_RX_TX;
    ALTER TABLE EPS.RX_TX_DIAGNOSIS_CODES DROP CONSTRAINT RX_TX_DIAGNOSIS_CODES_FK2;
    ALTER TABLE EPS.RX_TX_DUR_LIST DROP CONSTRAINT RX_TX_DUR_LIST_FK_IDRXTX;
    ALTER TABLE EPS.TX_CRED DROP CONSTRAINT TX_CRED_FK_RX_TX;
    ALTER TABLE EPS.TX_LOT DROP CONSTRAINT TX_LOT_FK_RX_TX;
    ALTER TABLE EPS.TX_TP DROP CONSTRAINT TX_TP_FK_RX_TX;
    ALTER TABLE EPS.VIAL_INFO DROP CONSTRAINT VIAL_INFO_FK_RX_TX;
    ALTER TABLE EPS.COMPOUND_INGREDIENTS DROP CONSTRAINT COMPOUND_INGREDIENTS_FK2;
    ALTER TABLE EPS.RX_TX_SIG_STRUCTURED_PART DROP CONSTRAINT RX_TX_SIG_STR_PRT_FK_RX_TX;
    ALTER TABLE EPS.RX_TX DROP CONSTRAINT RX_TX_FK_ALT_PRESCRIBER;
    ALTER TABLE EPS.RX_TX DROP CONSTRAINT RX_TX_FK_ESCHAIN;
    ALTER TABLE EPS.RX_TX DROP CONSTRAINT RX_TX_FK_ESSTORE;
    ALTER TABLE EPS.RX_TX DROP CONSTRAINT RX_TX_FK_MOD_PCM;
    ALTER TABLE EPS.RX_TX DROP CONSTRAINT RX_TX_FK_PRESCRIBER;
    ALTER TABLE EPS.RX_TX DROP CONSTRAINT RX_TX_PK;
    ALTER TABLE EPS.RX_TX ADD CONSTRAINT PK_RX_TX PRIMARY KEY CLUSTERED (CHAIN_ID, [ID]) ON ps_ChainID_EPS(CHAIN_ID);
    PRINT 'RX_TX: SUCCESS'
END TRY
BEGIN CATCH
    PRINT 'RX_TX: ' + ERROR_MESSAGE()
END CATCH
GO

-- ============ PRESCRIBER ============
BEGIN TRY
    ALTER TABLE EPS.PRESCRIBER DROP CONSTRAINT PRESCRIBER_FK_ESCHAIN;
    ALTER TABLE EPS.PRESCRIBER DROP CONSTRAINT PRESCRIBER_FK_ESSTORE;
    ALTER TABLE EPS.PRESCRIBER DROP CONSTRAINT PRESCRIBER_PK;
    ALTER TABLE EPS.PRESCRIBER ADD CONSTRAINT PK_PRESCRIBER PRIMARY KEY CLUSTERED (CHAIN_ID, [ID]) ON ps_ChainID_EPS(CHAIN_ID);
    PRINT 'PRESCRIBER: SUCCESS'
END TRY
BEGIN CATCH
    PRINT 'PRESCRIBER: ' + ERROR_MESSAGE()
END CATCH
GO

-- ============ MRN ============
BEGIN TRY
    ALTER TABLE EPS.MRN DROP CONSTRAINT MRN_FK_ESCHAIN;
    ALTER TABLE EPS.MRN DROP CONSTRAINT MRN_FK_PATIENT;
    ALTER TABLE EPS.MRN DROP CONSTRAINT MRN_FK_ROOTID;
    ALTER TABLE EPS.MRN DROP CONSTRAINT MRN_PK;
    ALTER TABLE EPS.MRN ADD CONSTRAINT PK_MRN PRIMARY KEY CLUSTERED (CHAIN_ID, [ID]) ON ps_ChainID_EPS(CHAIN_ID);
    PRINT 'MRN: SUCCESS'
END TRY
BEGIN CATCH
    PRINT 'MRN: ' + ERROR_MESSAGE()
END CATCH
GO

-- ============ CARD ============
BEGIN TRY
    ALTER TABLE EPS.TP_LINK DROP CONSTRAINT TP_LINK_FK_CARD;
    ALTER TABLE EPS.WORKMANS_COMP DROP CONSTRAINT WORKCOMP_FK_CARD;
    ALTER TABLE EPS.CARD DROP CONSTRAINT CARD_FK_ESCHAIN;
    ALTER TABLE EPS.CARD DROP CONSTRAINT CARD_FK_ESSTORE;
    ALTER TABLE EPS.CARD DROP CONSTRAINT PK_CARD;
    ALTER TABLE EPS.CARD ADD CONSTRAINT PK_CARD PRIMARY KEY CLUSTERED (CHAIN_ID, [ID]) ON ps_ChainID_EPS(CHAIN_ID);
    PRINT 'CARD: SUCCESS'
END TRY
BEGIN CATCH
    PRINT 'CARD: ' + ERROR_MESSAGE()
END CATCH
GO

-- ============ PAYMENT ============
BEGIN TRY
    ALTER TABLE EPS.RX_TX_PAYMENT DROP CONSTRAINT RX_TX_PAYMENT_FK_CHAIN_PAYID;
    ALTER TABLE EPS.PAYMENT DROP CONSTRAINT PAYMENT_FK_ESCHAIN;
    ALTER TABLE EPS.PAYMENT DROP CONSTRAINT PAYMENT_FK_ESSTORE;
    ALTER TABLE EPS.PAYMENT DROP CONSTRAINT PAYMENT_PK;
    ALTER TABLE EPS.PAYMENT ADD CONSTRAINT PK_PAYMENT PRIMARY KEY CLUSTERED (CHAIN_ID, [ID]) ON ps_ChainID_EPS(CHAIN_ID);
    PRINT 'PAYMENT: SUCCESS'
END TRY
BEGIN CATCH
    PRINT 'PAYMENT: ' + ERROR_MESSAGE()
END CATCH
GO

-- ============ LINE_ITEM ============
BEGIN TRY
    ALTER TABLE EPS.LINE_ITEM DROP CONSTRAINT LINE_ITEM_FK_PATIENT;
    ALTER TABLE EPS.LINE_ITEM DROP CONSTRAINT LINE_ITEM_FK_ESCHAIN;
    ALTER TABLE EPS.LINE_ITEM DROP CONSTRAINT LINE_ITEM_FK_ESSTORE;
    ALTER TABLE EPS.LINE_ITEM DROP CONSTRAINT PK_LINE_ITEM;
    ALTER TABLE EPS.LINE_ITEM ADD CONSTRAINT PK_LINE_ITEM PRIMARY KEY CLUSTERED (CHAIN_ID, [ID]) ON ps_ChainID_EPS(CHAIN_ID);
    PRINT 'LINE_ITEM: SUCCESS'
END TRY
BEGIN CATCH
    PRINT 'LINE_ITEM: ' + ERROR_MESSAGE()
END CATCH
GO

-- ============ ALLERGY ============
BEGIN TRY
    ALTER TABLE EPS.ALLERGY DROP CONSTRAINT ALLERGY_FK_ESCHAIN;
    ALTER TABLE EPS.ALLERGY DROP CONSTRAINT ALLERGY_FK_ESSTORE;
    ALTER TABLE EPS.ALLERGY DROP CONSTRAINT ALLERGY_FK_PATIENT;
    ALTER TABLE EPS.ALLERGY DROP CONSTRAINT PK_ALLERGY;
    ALTER TABLE EPS.ALLERGY ADD CONSTRAINT PK_ALLERGY PRIMARY KEY CLUSTERED (CHAIN_ID, [ID]) ON ps_ChainID_EPS(CHAIN_ID);
    PRINT 'ALLERGY: SUCCESS'
END TRY
BEGIN CATCH
    PRINT 'ALLERGY: ' + ERROR_MESSAGE()
END CATCH
GO

-- ============ DISEASE ============
BEGIN TRY
    ALTER TABLE EPS.DISEASE DROP CONSTRAINT DISEASE_FK_ESCHAIN;
    ALTER TABLE EPS.DISEASE DROP CONSTRAINT DISEASE_FK_ESSTORE;
    ALTER TABLE EPS.DISEASE DROP CONSTRAINT DISEASE_FK_PATIENT;
    ALTER TABLE EPS.DISEASE DROP CONSTRAINT PK_DISEASE;
    ALTER TABLE EPS.DISEASE ADD CONSTRAINT PK_DISEASE PRIMARY KEY CLUSTERED (CHAIN_ID, [ID]) ON ps_ChainID_EPS(CHAIN_ID);
    PRINT 'DISEASE: SUCCESS'
END TRY
BEGIN CATCH
    PRINT 'DISEASE: ' + ERROR_MESSAGE()
END CATCH
GO

-- ============ VERIFICATION ============
SELECT 
    'RX_TX' as [Table],
    COUNT(DISTINCT partition_number) as [Partitions],
    CASE WHEN COUNT(DISTINCT partition_number) = 6 THEN 'PASS' ELSE 'FAIL' END as [Status]
FROM sys.partitions WHERE object_id=OBJECT_ID('EPS.RX_TX') AND index_id=1
UNION ALL SELECT 'PRESCRIBER', COUNT(DISTINCT partition_number), CASE WHEN COUNT(DISTINCT partition_number) = 6 THEN 'PASS' ELSE 'FAIL' END FROM sys.partitions WHERE object_id=OBJECT_ID('EPS.PRESCRIBER') AND index_id=1
UNION ALL SELECT 'MRN', COUNT(DISTINCT partition_number), CASE WHEN COUNT(DISTINCT partition_number) = 6 THEN 'PASS' ELSE 'FAIL' END FROM sys.partitions WHERE object_id=OBJECT_ID('EPS.MRN') AND index_id=1
UNION ALL SELECT 'CARD', COUNT(DISTINCT partition_number), CASE WHEN COUNT(DISTINCT partition_number) = 6 THEN 'PASS' ELSE 'FAIL' END FROM sys.partitions WHERE object_id=OBJECT_ID('EPS.CARD') AND index_id=1
UNION ALL SELECT 'PAYMENT', COUNT(DISTINCT partition_number), CASE WHEN COUNT(DISTINCT partition_number) = 6 THEN 'PASS' ELSE 'FAIL' END FROM sys.partitions WHERE object_id=OBJECT_ID('EPS.PAYMENT') AND index_id=1
UNION ALL SELECT 'LINE_ITEM', COUNT(DISTINCT partition_number), CASE WHEN COUNT(DISTINCT partition_number) = 6 THEN 'PASS' ELSE 'FAIL' END FROM sys.partitions WHERE object_id=OBJECT_ID('EPS.LINE_ITEM') AND index_id=1
UNION ALL SELECT 'ALLERGY', COUNT(DISTINCT partition_number), CASE WHEN COUNT(DISTINCT partition_number) = 6 THEN 'PASS' ELSE 'FAIL' END FROM sys.partitions WHERE object_id=OBJECT_ID('EPS.ALLERGY') AND index_id=1
UNION ALL SELECT 'DISEASE', COUNT(DISTINCT partition_number), CASE WHEN COUNT(DISTINCT partition_number) = 6 THEN 'PASS' ELSE 'FAIL' END FROM sys.partitions WHERE object_id=OBJECT_ID('EPS.DISEASE') AND index_id=1
ORDER BY [Table];
```

---

## How to Execute

### Option 1: Azure Portal Query Editor (Fastest)
1. Go to https://portal.azure.com → **SQL Database: sqldb-epr-qa**
2. Click **Query Editor** → Log in if needed
3. Copy the SQL above
4. Paste into the editor
5. Click **Run**
6. Wait ~2-5 minutes
7. Check Results tab - should show all 8 rows with "PASS" status

### Option 2: Azure SQL Management Studio
1. Open **SSMS**
2. Connect to: `sql-epr-qa-eastus2.database.windows.net` / `sqldb-epr-qa`
3. Paste the SQL into a new query window
4. Press **F5** to execute
5. Wait for completion
6. Results appear in Results tab

### Option 3: Azure Data Studio
1. Connect to the database
2. New Query
3. Paste SQL
4. Click **Run**

---

## Expected Output

If successful, you'll see output like:

```
Table       Partitions  Status
----------  ----------  ------
RX_TX       6           PASS
PRESCRIBER  6           PASS
MRN         6           PASS
CARD        6           PASS
PAYMENT     6           PASS
LINE_ITEM   6           PASS
ALLERGY     6           PASS
DISEASE     6           PASS
```

---

## After Execution

1. **If all show "PASS":** Category A1 is 100% complete! ✓
2. **If some show "FAIL":** Those tables didn't partition (likely FK constraints remain)
3. **If any fail:** Rerun just that table's section with the specific constraint names

---

## Timeline Impact

- **With manual execution:** +5-10 minutes
- **Total Category A1:** ~80-85 minutes (vs. original 70 if automation worked)
- **Category A2 (30 tables):** Ready to scale (same approach, larger batch)
- **Category A3 (33 tables):** Ready to scale

---

## Summary

PowerShell automation hit timeout limits with large DDL batches. **Direct SQL execution in Azure portal is reliable and fast.**

**Recommended Next Action:** Execute SQL in Azure Portal Query Editor (3-4 minutes, highest success rate)

Files created:
- `DIRECT_EXECUTE_A1_Complete.sql` - Full batch script (if running via SSMS)
- `Simple-Verify.ps1` - Verification script (for PowerShell if connection stabilizes)

