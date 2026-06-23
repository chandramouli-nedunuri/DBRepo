-- TRIGGER: [EPS].[MOD_PCM_TRIG_AUR] - Oracle to Azure SQL conversion
-- Converted: AFTER UPDATE trigger with set-based INSERT...SELECT

IF OBJECT_ID('[EPS].[MOD_PCM_TRIG_AUR]', 'TR') IS NOT NULL
    DROP TRIGGER [EPS].[MOD_PCM_TRIG_AUR];
GO

CREATE TRIGGER [EPS].[MOD_PCM_TRIG_AUR]
ON [EPS].[MOD_PCM]
AFTER UPDATE
AS
BEGIN
    INSERT INTO [EPS].[MOD_PCM_AUDIT] (
        [CHAIN_ID],
        [ID],
        [DELETED],
        [LAST_UPDATED],
        [NHIN_ID],
        [LABEL1A],
        [LABEL2A],
        [LABEL3A],
        [LABEL4A],
        [LABEL5A],
        [LABEL6A],
        [LABEL7A],
        [LABEL8A],
        [LABEL1B],
        [LABEL2B],
        [LABEL3B],
        [LABEL4B],
        [LABEL5B],
        [LABEL6B],
        [LABEL7B],
        [LABEL8B],
        [ID_AAL],
        [ARCHIVE_DATE],
        [ID_AUDIT],
        [AUDIT_TIMESTAMP]
    )
    SELECT
        [CHAIN_ID],
        [ID],
        [DELETED],
        [LAST_UPDATED],
        [NHIN_ID],
        [LABEL1A],
        [LABEL2A],
        [LABEL3A],
        [LABEL4A],
        [LABEL5A],
        [LABEL6A],
        [LABEL7A],
        [LABEL8A],
        [LABEL1B],
        [LABEL2B],
        [LABEL3B],
        [LABEL4B],
        [LABEL5B],
        [LABEL6B],
        [LABEL7B],
        [LABEL8B],
        [ID_AAL],
        [ARCHIVE_DATE],
        NEXT VALUE FOR [EPS].[MOD_PCM_SEQ],
        SYSDATETIME()
    FROM deleted;
END;
GO
