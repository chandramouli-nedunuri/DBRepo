-- TRIGGER: [EPS].[KP_RXNUM_REF_TRIG_AUR] - Oracle to Azure SQL conversion
-- Converted: AFTER UPDATE trigger with set-based INSERT...SELECT

IF OBJECT_ID('[EPS].[KP_RXNUM_REF_TRIG_AUR]', 'TR') IS NOT NULL
    DROP TRIGGER [EPS].[KP_RXNUM_REF_TRIG_AUR];
GO

CREATE TRIGGER [EPS].[KP_RXNUM_REF_TRIG_AUR]
ON [EPS].[KP_RXNUM_REF]
AFTER UPDATE
AS
BEGIN
    INSERT INTO [EPS].[KP_RXNUM_REF_AUDIT] (
        [CHAIN_ID],
        [ID],
        [LAST_UPDATED],
        [ID_AAL],
        [OLD_KP_RX_NUM],
        [KP_RX_NUM],
        [ACTIVE_RX_RX_NUMBER],
        [ACTIVE_RX_NHIN_ID],
        [ACTIVE_RX_FILLED],
        [ID_AUDIT],
        [AUDIT_TIMESTAMP]
    )
    SELECT
        [CHAIN_ID],
        [ID],
        [LAST_UPDATED],
        [ID_AAL],
        [OLD_KP_RX_NUM],
        [KP_RX_NUM],
        [ACTIVE_RX_RX_NUMBER],
        [ACTIVE_RX_NHIN_ID],
        [ACTIVE_RX_FILLED],
        NEXT VALUE FOR [EPS].[KP_RXNUM_REF_SEQ],
        SYSDATETIME()
    FROM deleted;
END;
GO
