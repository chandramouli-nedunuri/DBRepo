-- TRIGGER: [EPS].[TELEPHONE_AUR] - Oracle to Azure SQL conversion
-- Converted: AFTER UPDATE trigger with set-based INSERT...SELECT

IF OBJECT_ID('[EPS].[TELEPHONE_AUR]', 'TR') IS NOT NULL
    DROP TRIGGER [EPS].[TELEPHONE_AUR];
GO

CREATE TRIGGER [EPS].[TELEPHONE_AUR]
ON [EPS].[TELEPHONE]
AFTER UPDATE
AS
BEGIN
    INSERT INTO [EPS].[TELEPHONE_AUDIT] (
        [CHAIN_ID],
        [ID],
        [DELETED],
        [LAST_UPDATED],
        [NHIN_ID],
        [ADDRESS_KEY],
        [AREA_CODE],
        [COUNTRY_CODE],
        [LOCATION_TYPE],
        [PHONE_NUMBER],
        [ID_PATIENT],
        [ID_AAL],
        [PHONE_NUMBER_UPDATED_DATE],
        [ID_AUDIT],
        [AUDIT_TIMESTAMP]
    )
    SELECT
        [CHAIN_ID],
        [ID],
        [DELETED],
        [LAST_UPDATED],
        [NHIN_ID],
        [ADDRESS_KEY],
        [AREA_CODE],
        [COUNTRY_CODE],
        [LOCATION_TYPE],
        [PHONE_NUMBER],
        [ID_PATIENT],
        [ID_AAL],
        [PHONE_NUMBER_UPDATED_DATE],
        NEXT VALUE FOR [EPS].[AUDIT_SEQ],
        SYSDATETIME()
    FROM deleted;
END;
GO
