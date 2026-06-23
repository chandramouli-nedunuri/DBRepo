-- TRIGGER: [EPS].[SIGNATURE_TRIG_AUR] - Oracle to Azure SQL conversion
-- Converted: AFTER UPDATE trigger with set-based INSERT...SELECT

IF OBJECT_ID('[EPS].[SIGNATURE_TRIG_AUR]', 'TR') IS NOT NULL
    DROP TRIGGER [EPS].[SIGNATURE_TRIG_AUR];
GO

CREATE TRIGGER [EPS].[SIGNATURE_TRIG_AUR]
ON [EPS].[SIGNATURE]
AFTER UPDATE
AS
BEGIN
    INSERT INTO [EPS].[SIGNATURE_AUDIT] (
        [CHAIN_ID],
        [ID],
        [SIGNATURE_NUMBER],
        [STORE_LAST_UPDATED],
        [ORIGINAL_NHIN_ID],
        [DOCUMENT_CODE],
        [DOCUMENT_VERSION],
        [STATE],
        [LANG],
        [DOCUMENT_NAME],
        [ACQUIRED_STORE_ID],
        [ACQUIRED_DATE],
        [REVOKED_AT_STORE],
        [REVOKE_DATE],
        [EXPIRATION_DATE],
        [STATUS],
        [LOCATION],
        [ID_PATIENT],
        [ID_AAL],
        [LAST_UPDATED],
        [DELETED],
        [ID_AUDIT],
        [AUDIT_TIMESTAMP]
    )
    SELECT
        [CHAIN_ID],
        [ID],
        [SIGNATURE_NUMBER],
        [STORE_LAST_UPDATED],
        [ORIGINAL_NHIN_ID],
        [DOCUMENT_CODE],
        [DOCUMENT_VERSION],
        [STATE],
        [LANG],
        [DOCUMENT_NAME],
        [ACQUIRED_STORE_ID],
        [ACQUIRED_DATE],
        [REVOKED_AT_STORE],
        [REVOKE_DATE],
        [EXPIRATION_DATE],
        [STATUS],
        [LOCATION],
        [ID_PATIENT],
        [ID_AAL],
        [LAST_UPDATED],
        [DELETED],
        NEXT VALUE FOR [EPS].[SIGNATURE_SEQ],
        SYSDATETIME()
    FROM deleted;
END;
GO
