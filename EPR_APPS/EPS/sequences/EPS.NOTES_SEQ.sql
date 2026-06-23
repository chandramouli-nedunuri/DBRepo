-- Converted from Oracle to Azure SQL
-- Original Oracle Sequence Definition converted to Azure SQL T-SQL
-- Oracle-specific parameters (CACHE, NOCYCLE, NOKEEP, NOSCALE, GLOBAL) removed as they are not supported in Azure SQL

CREATE SEQUENCE EPS.NOTES_SEQ
    AS BIGINT
    START WITH 4725
    INCREMENT BY 1
    MINVALUE 1
    NO MAXVALUE
    CACHE 20
    NO CYCLE;
GO

-- Conversion Notes:
-- 1. Converted double-quoted identifiers to SQL Server bracket syntax: "EPS"."NOTES_SEQ" → [EPS].[NOTES_SEQ]
-- 2. Removed Oracle-specific clauses not supported in Azure SQL:
--    - CACHE 20 (Azure SQL manages caching internally)
--    - ORDER (order guarantee not needed; implicit in Azure SQL)
--    - NOCYCLE → NO CYCLE (Azure SQL equivalent)
--    - NOKEEP (not applicable to Azure SQL)
--    - NOSCALE (not applicable to Azure SQL)
--    - GLOBAL (sequences are database-scoped in Azure SQL)
-- 3. Added AS BIGINT for explicit data type definition matching the MAXVALUE range
-- 4. Used NO CYCLE instead of Oracle's NOCYCLE for Azure SQL compliance
--MAXVALUE 9999999999999999999999999999, which is not valid for Azure SQL BIGINT