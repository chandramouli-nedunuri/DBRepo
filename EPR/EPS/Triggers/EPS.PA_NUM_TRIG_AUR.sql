-- TRIGGER: [EPS].[PA_NUM_TRIG_AUR] - Oracle to Azure SQL conversion
-- Converted: AFTER UPDATE trigger with set-based INSERT...SELECT

IF OBJECT_ID('[EPS].[PA_NUM_TRIG_AUR]', 'TR') IS NOT NULL
    DROP TRIGGER [EPS].[PA_NUM_TRIG_AUR];
GO

CREATE TRIGGER [EPS].[PA_NUM_TRIG_AUR]
ON [EPS].[PA_NUM]
AFTER UPDATE
AS
BEGIN
    INSERT INTO [EPS].[PA_NUM_AUDIT] (
        [CHAIN_ID],
        [ID],
        [DELETED],
        [LAST_UPDATED],
        [NHIN_ID],
        [COUNTER],
        [DOLLAR_RX],
        [DOLLARS],
        [EFFECTIVE],
        [EXPIRATION],
        [FILLS],
        [NUMBER_RX],
        [PA_NUMBER],
        [PROCESSED],
        [QUANTITY],
        [REPEAT],
        [TOTAL_QUANTITY],
        [TX_NUMBER],
        [PA_NUM_TYPE],
        [ID_TX_TP],
        [ID_AAL],
        [ID_AUDIT],
        [AUDIT_TIMESTAMP]
    )
    SELECT
        [CHAIN_ID],
        [ID],
        [DELETED],
        [LAST_UPDATED],
        [NHIN_ID],
        [COUNTER],
        [DOLLAR_RX],
        [DOLLARS],
        [EFFECTIVE],
        [EXPIRATION],
        [FILLS],
        [NUMBER_RX],
        [PA_NUMBER],
        [PROCESSED],
        [QUANTITY],
        [REPEAT],
        [TOTAL_QUANTITY],
        [TX_NUMBER],
        [PA_NUM_TYPE],
        [ID_TX_TP],
        [ID_AAL],
        NEXT VALUE FOR [EPS].[PA_NUM_SEQ],
        SYSDATETIME()
    FROM deleted;
END;
GO
