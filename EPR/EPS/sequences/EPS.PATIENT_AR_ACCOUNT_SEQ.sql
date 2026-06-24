-- Converted from Oracle to Azure SQL
-- Original Oracle Sequence Definition converted to Azure SQL T-SQL
-- Oracle-specific parameters (CACHE, ORDER, NOCYCLE, NOKEEP, NOSCALE, GLOBAL) removed as they are not supported in Azure SQL

CREATE SEQUENCE EPS.PATIENT_AR_ACCOUNT_SEQ
    AS BIGINT
    START WITH 119262
    INCREMENT BY 1
    MINVALUE 1
    NO MAXVALUE
    CACHE 20
    NO CYCLE;
GO

-- Conversion Notes:
-- 1. Converted double-quoted identifiers to unquoted standard syntax: "EPS"."PATIENT_AR_ACCOUNT_SEQ" → EPS.PATIENT_AR_ACCOUNT_SEQ
-- 2. Removed Oracle-specific clauses not supported in Azure SQL:
--    - ORDER (order guarantee not needed; implicit in Azure SQL)
--    - NOCYCLE → NO CYCLE (Azure SQL equivalent)
--    - NOKEEP (not applicable to Azure SQL)
--    - NOSCALE (not applicable to Azure SQL)
--    - GLOBAL (sequences are database-scoped in Azure SQL)
-- 3. Added AS BIGINT for explicit data type definition
-- 4. Changed to NO MAXVALUE to avoid overflow with original large MAXVALUE value
-- 5. Kept CACHE 20 as specified in original Oracle definition
