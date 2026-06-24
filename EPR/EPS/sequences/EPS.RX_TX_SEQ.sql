-- Converted from Oracle to Azure SQL
-- Original Oracle Sequence Definition converted to Azure SQL T-SQL
-- Oracle-specific parameters (CACHE, NOORDER, NOCYCLE, NOKEEP, NOSCALE, GLOBAL) removed as they are not supported in Azure SQL

CREATE SEQUENCE EPS.RX_TX_SEQ
    AS BIGINT
    START WITH 27690321849
    INCREMENT BY 1
    MINVALUE 1
    NO MAXVALUE
    CACHE 1000
    NO CYCLE;
GO
