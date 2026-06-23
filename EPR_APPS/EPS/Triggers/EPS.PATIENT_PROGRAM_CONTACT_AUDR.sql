-- TRIGGER: [EPS].[PATIENT_PROGRAM_CONTACT_AUDR] - Oracle to Azure SQL conversion
-- Converted: AFTER UPDATE or DELETE trigger

IF OBJECT_ID('[EPS].[PATIENT_PROGRAM_CONTACT_AUDR]', 'TR') IS NOT NULL
    DROP TRIGGER [EPS].[PATIENT_PROGRAM_CONTACT_AUDR];
GO

CREATE TRIGGER [EPS].[PATIENT_PROGRAM_CONTACT_AUDR]
ON [EPS].[PATIENT_PROGRAM_CONTACT]
AFTER UPDATE, DELETE
AS
BEGIN
    -- Handle UPDATE events
    IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT INTO [EPS].[PATIENT_PROGRAM_CONTACT_AUDIT] (
            [CHAIN_ID],
            [PATIENT_PROGRAM_ID],
            [SEQUENCE_NUMBER],
            [CONTACT_PREF],
            [ID_AAL],
            [DML_TYPE],
            [ID_AUDIT],
            [AUDIT_TIMESTAMP]
        )
        SELECT
            d.[CHAIN_ID],
            d.[PATIENT_PROGRAM_ID],
            d.[SEQUENCE_NUMBER],
            d.[CONTACT_PREF],
            d.[ID_AAL],
            'U',
            NEXT VALUE FOR [EPS].[AUDIT_SEQ],
            SYSDATETIME()
        FROM deleted d;
    END;

    -- Handle DELETE events
    IF EXISTS (SELECT 1 FROM deleted WHERE NOT EXISTS (SELECT 1 FROM inserted))
    BEGIN
        INSERT INTO [EPS].[PATIENT_PROGRAM_CONTACT_AUDIT] (
            [CHAIN_ID],
            [PATIENT_PROGRAM_ID],
            [SEQUENCE_NUMBER],
            [CONTACT_PREF],
            [ID_AAL],
            [DML_TYPE],
            [ID_AUDIT],
            [AUDIT_TIMESTAMP]
        )
        SELECT
            d.[CHAIN_ID],
            d.[PATIENT_PROGRAM_ID],
            d.[SEQUENCE_NUMBER],
            d.[CONTACT_PREF],
            d.[ID_AAL],
            'D',
            NEXT VALUE FOR [EPS].[AUDIT_SEQ],
            SYSDATETIME()
        FROM deleted d;
    END;
END;
GO
