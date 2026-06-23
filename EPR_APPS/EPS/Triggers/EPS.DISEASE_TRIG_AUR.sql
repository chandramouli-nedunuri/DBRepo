-- TRIGGER: [EPS].[DISEASE_TRIG_AUR] - Oracle to Azure SQL conversion
-- Converted: AFTER UPDATE trigger with set-based INSERT...SELECT

IF OBJECT_ID('[EPS].[DISEASE_TRIG_AUR]', 'TR') IS NOT NULL
    DROP TRIGGER [EPS].[DISEASE_TRIG_AUR];
GO

CREATE TRIGGER [EPS].[DISEASE_TRIG_AUR]
ON [EPS].[DISEASE]
AFTER UPDATE
AS
BEGIN
    INSERT INTO [EPS].[DISEASE_AUDIT] (
        [CHAIN_ID],
        [ID],
        [DELETED],
        [LAST_UPDATED],
        [ID_AAL],
        [ID_AUDIT],
        [AUDIT_TIMESTAMP]
    )
    SELECT
        [CHAIN_ID],
        [ID],
        [DELETED],
        [LAST_UPDATED],
        [ID_AAL],
        NEXT VALUE FOR [EPS].[AUDIT_SEQ], SYSDATETIME()
    FROM deleted;
END;
GO
