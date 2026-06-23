-- Converted from Oracle to Azure SQL
-- Original Oracle Sequence Definition converted to Azure SQL T-SQL
-- Oracle-specific parameters (CACHE, NOORDER, NOCYCLE, NOKEEP, NOSCALE, GLOBAL) removed as they are not supported in Azure SQL

CREATE SEQUENCE EPS.MATCH_KEY_SEQ
    AS BIGINT
    START WITH 3005245901
    INCREMENT BY 1
    MINVALUE 1
    NO MAXVALUE
    CACHE 100
    NO CYCLE;
GO
