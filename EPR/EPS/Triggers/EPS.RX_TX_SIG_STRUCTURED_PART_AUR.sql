-- TRIGGER: [EPS].[RX_TX_SIG_STRUCTURED_PART_AUR] - Oracle to Azure SQL conversion
-- Converted: AFTER UPDATE trigger with set-based INSERT...SELECT

IF OBJECT_ID('[EPS].[RX_TX_SIG_STRUCTURED_PART_AUR]', 'TR') IS NOT NULL
    DROP TRIGGER [EPS].[RX_TX_SIG_STRUCTURED_PART_AUR];
GO

CREATE TRIGGER [EPS].[RX_TX_SIG_STRUCTURED_PART_AUR]
ON [EPS].[RX_TX_SIG_STRUCTURED_PART]
AFTER UPDATE
AS
BEGIN
    INSERT INTO [EPS].[RTSSP_AUDIT] (
        [CHAIN_ID],
        [ID],
        [ID_RX_TX],
        [LAST_UPDATED],
        [ID_AAL],
        [SEQUENCE_NUMBER],
        [CODE],
        [TEXT],
        [PLURAL_TEXT],
        [TYPE],
        [PER_DOSE],
        [PER_DAY],
        [CONVERSION_FACTOR],
        [SNOMED_CODE],
        [TIME_FRAME],
        [TIME_FRAME_TYPE],
        [FREQUENCY_RATE],
        [DOSE_MULTIPLIER],
        [ID_AUDIT],
        [AUDIT_TIMESTAMP]
    )
    SELECT
        [CHAIN_ID],
        [ID],
        [ID_RX_TX],
        [LAST_UPDATED],
        [ID_AAL],
        [SEQUENCE_NUMBER],
        [CODE],
        [TEXT],
        [PLURAL_TEXT],
        [TYPE],
        [PER_DOSE],
        [PER_DAY],
        [CONVERSION_FACTOR],
        [SNOMED_CODE],
        [TIME_FRAME],
        [TIME_FRAME_TYPE],
        [FREQUENCY_RATE],
        [DOSE_MULTIPLIER],
        NEXT VALUE FOR [EPS].[RX_TX_SIG_STRUCTURED_PART_SEQ],
        SYSDATETIME()
    FROM deleted;
END;
GO
