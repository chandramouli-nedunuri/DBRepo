-- TRIGGER: [EPS].[TX_CRED_TRIG_AUR] - Oracle to Azure SQL conversion
-- Converted: AFTER UPDATE trigger with set-based INSERT...SELECT

IF OBJECT_ID('[EPS].[TX_CRED_TRIG_AUR]', 'TR') IS NOT NULL
    DROP TRIGGER [EPS].[TX_CRED_TRIG_AUR];
GO

CREATE TRIGGER [EPS].[TX_CRED_TRIG_AUR]
ON [EPS].[TX_CRED]
AFTER UPDATE
AS
BEGIN
    INSERT INTO [EPS].[TX_CRED_AUDIT] (
        [CHAIN_ID],
        [ID],
        [DELETED],
        [LAST_UPDATED],
        [NHIN_ID],
        [INITIALS],
        [ORG_PRICE],
        [ORG_QTY],
        [ORG_TX_NUM],
        [RETURNED],
        [REVERSED],
        [RX_CREDIT],
        [ID_RX_TX],
        [ID_AAL],
        [ORG_QTY_DEC],
        [ID_AUDIT],
        [AUDIT_TIMESTAMP]
    )
    SELECT
        [CHAIN_ID],
        [ID],
        [DELETED],
        [LAST_UPDATED],
        [NHIN_ID],
        [INITIALS],
        [ORG_PRICE],
        [ORG_QTY],
        [ORG_TX_NUM],
        [RETURNED],
        [REVERSED],
        [RX_CREDIT],
        [ID_RX_TX],
        [ID_AAL],
        [ORG_QTY_DEC],
        NEXT VALUE FOR [EPS].[TX_CRED_SEQ],
        SYSDATETIME()
    FROM deleted;
END;
GO
