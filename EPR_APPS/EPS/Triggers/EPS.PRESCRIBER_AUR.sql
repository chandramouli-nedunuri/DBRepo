-- TRIGGER: [EPS].[PRESCRIBER_AUR] - Oracle to Azure SQL conversion
-- Converted: AFTER UPDATE trigger with set-based INSERT...SELECT

IF OBJECT_ID('[EPS].[PRESCRIBER_AUR]', 'TR') IS NOT NULL
    DROP TRIGGER [EPS].[PRESCRIBER_AUR];
GO

CREATE TRIGGER [EPS].[PRESCRIBER_AUR]
ON [EPS].[PRESCRIBER]
AFTER UPDATE
AS
BEGIN
    INSERT INTO [EPS].[PRESCRIBER_AUDIT] (
        [CHAIN_ID],
        [ID],
        [DELETED],
        [LAST_UPDATED],
        [NHIN_ID],
        [ADDRESS],
        [ADDRESS1],
        [AREA_CODE],
        [CITY],
        [COUNTRY],
        [DEA],
        [FAX_AREA_CODE],
        [FAX_PHONE],
        [FIRST_NAME],
        [LAST_NAME],
        [MIDDLE_NAME],
        [NAME],
        [PHONE],
        [STATE],
        [STATE_ID],
        [ZIP],
        [ID_AAL],
        [ARCHIVE_DATE],
        [NPI_NUM],
        [HCID],
        [HMS_IDENTIFIER],
        [CPM_IDENTIFIER],
        [ID_AUDIT],
        [AUDIT_TIMESTAMP]
    )
    SELECT
        [CHAIN_ID],
        [ID],
        [DELETED],
        [LAST_UPDATED],
        [NHIN_ID],
        [ADDRESS],
        [ADDRESS1],
        [AREA_CODE],
        [CITY],
        [COUNTRY],
        [DEA],
        [FAX_AREA_CODE],
        [FAX_PHONE],
        [FIRST_NAME],
        [LAST_NAME],
        [MIDDLE_NAME],
        [NAME],
        [PHONE],
        [STATE],
        [STATE_ID],
        [ZIP],
        [ID_AAL],
        [ARCHIVE_DATE],
        [NPI_NUM],
        [HCID],
        [HMS_IDENTIFIER],
        [CPM_IDENTIFIER],
        NEXT VALUE FOR [EPS].[AUDIT_SEQ],
        SYSDATETIME()
    FROM deleted;
END;
GO
