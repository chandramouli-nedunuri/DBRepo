-- TRIGGER: [EPS].[EMAIL_TRIG_AUR] - Oracle to Azure SQL conversion
-- Converted: AFTER UPDATE trigger with set-based INSERT...SELECT

IF OBJECT_ID('[EPS].[EMAIL_TRIG_AUR]', 'TR') IS NOT NULL
    DROP TRIGGER [EPS].[EMAIL_TRIG_AUR];
GO

CREATE TRIGGER [EPS].[EMAIL_TRIG_AUR]
ON [EPS].[EMAIL]
AFTER UPDATE
AS
BEGIN
    INSERT INTO [EPS].[EMAIL_AUDIT] (
        [CHAIN_ID],
        [ID],
        [DELETED],
        [LAST_UPDATED],
        [NHIN_ID],
        [EMAIL_ADDRESS],
        [IN_ACTIVE],
        [LOCATION_TYPE],
        [ID_PATIENT],
        [ID_AAL],
        [SERVICE_VENDOR],
        [AUTH_CODE],
        [TERMS_OF_SERVICE_DATE],
        [ID_AUDIT],
        [AUDIT_TIMESTAMP]
    )
    SELECT
        [CHAIN_ID],
        [ID],
        [DELETED],
        [LAST_UPDATED],
        [NHIN_ID],
        [EMAIL_ADDRESS],
        [IN_ACTIVE],
        [LOCATION_TYPE],
        [ID_PATIENT],
        [ID_AAL],
        [SERVICE_VENDOR],
        [AUTH_CODE],
        [TERMS_OF_SERVICE_DATE],
        NEXT VALUE FOR [EPS].[EMAIL_SEQ],
        SYSDATETIME()
    FROM deleted;
END;
GO
