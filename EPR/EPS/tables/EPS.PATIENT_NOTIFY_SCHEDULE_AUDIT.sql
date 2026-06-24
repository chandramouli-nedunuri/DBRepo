-- ============================================================
-- Azure SQL Schema Conversion for EPS.PATIENT_NOTIFY_SCHEDULE_AUDIT
-- Source: Oracle EPS database
-- Target: Azure SQL Server 2019+
-- Conversion Date: 2026-05-28
-- ============================================================

-- TABLE: EPS.PATIENT_NOTIFY_SCHEDULE_AUDIT
-- Type: Composite Partitioned Audit Table (Notification Preferences)
-- Oracle Partitions: LIST by CHAIN_ID + RANGE by AUDIT_TIMESTAMP
-- Purpose: Audit trail for patient notification/SMS schedule preferences

CREATE TABLE [EPS].[PATIENT_NOTIFY_SCHEDULE_AUDIT] (
    [CHAIN_ID] [int] NULL,
    [ID] [numeric](38, 0) NULL,
    [ID_PATIENT] [int] NULL,
    [MESSAGE_TYPE] [varchar](1) NULL,
    [DAY_OF_WEEK] [varchar](9) NULL,
    [START_TIME] [varchar](5) NULL,
    [END_TIME] [varchar](5) NULL,
    [PATIENT_TIME_ZONE] [varchar](40) NULL,
    [LAST_UPDATED] [datetime2](6) NULL,
    [ID_AAL] [numeric](22, 0) NULL,
    [ID_AUDIT] [numeric](38, 0) NULL,
    [AUDIT_TIMESTAMP] [datetime2](6) NOT NULL
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- INDEXES
-- ============================================================
-- Audit Timestamp Range (notification audit analysis)
CREATE NONCLUSTERED INDEX [IX_PATIENT_NOTIFY_SCHEDULE_AUDIT_TIMESTAMP] 
ON [EPS].[PATIENT_NOTIFY_SCHEDULE_AUDIT] ([AUDIT_TIMESTAMP], [CHAIN_ID])
INCLUDE ([ID], [ID_PATIENT], [MESSAGE_TYPE], [DAY_OF_WEEK])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- Patient Notification Schedule History
CREATE NONCLUSTERED INDEX [IX_PATIENT_NOTIFY_SCHEDULE_AUDIT_PATIENT] 
ON [EPS].[PATIENT_NOTIFY_SCHEDULE_AUDIT] ([ID_PATIENT], [AUDIT_TIMESTAMP], [CHAIN_ID])
INCLUDE ([ID], [MESSAGE_TYPE], [DAY_OF_WEEK], [START_TIME], [END_TIME])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- COMPRESSION
-- ============================================================
-- PAGE compression for audit table
ALTER TABLE [EPS].[PATIENT_NOTIFY_SCHEDULE_AUDIT] 
SET (COMPRESSION = PAGE);

-- ============================================================
-- POST-DEPLOYMENT ACTIONS
-- ============================================================
/*
[COMPOSITE_PARTITIONING] Oracle: LIST by CHAIN_ID + RANGE by AUDIT_TIMESTAMP
  Recommendation: Post-migration monthly RANGE partitioning:
  
  CREATE PARTITION FUNCTION [PF_PATIENT_NOTIFY_SCHEDULE_AUDIT_MONTHLY](datetime2)
  AS RANGE RIGHT FOR VALUES ('2024-07-01', '2024-08-01', ... '2026-09-01');

[PATIENT_NOTIFICATION_PREFERENCES]
  Pharmacy sends notifications via SMS/email for:
  - Rx ready for pickup notification
  - Refill appointment reminders
  - Medication adherence reminders (chronic conditions)
  - Vaccination appointment reminders
  - Lab result notifications
  
  Patient preferences captured in this table:
  - [MESSAGE_TYPE]: Type of notification (refill, appointment, reminder, etc.)
  - [DAY_OF_WEEK]: Patient prefers notifications on which days
  - [START_TIME]: Do not notify before (e.g., 8:00 AM)
  - [END_TIME]: Do not notify after (e.g., 9:00 PM)
  - [PATIENT_TIME_ZONE]: Patient's time zone (EST, CST, MST, PST, etc.)
  
  Purpose: Respect patient preferences + reduce opt-out complaints

[DAY_OF_WEEK_PREFERENCES]
  Examples:
    "Monday" = Notification on Monday acceptable
    "Monday,Wednesday,Friday" = MWF only
    "Monday-Friday" = Weekdays only (not weekend)
  
  Business use: Skip weekend notifications (patient may not check pharmacy)

[TIME_WINDOW_PREFERENCES]
  [START_TIME]: '08:00' (8 AM) = do not send before 8 AM
  [END_TIME]:   '21:00' (9 PM) = do not send after 9 PM
  
  Logic:
    IF CONVERT(TIME, GETDATE()) < START_TIME THEN queue notification
    IF CONVERT(TIME, GETDATE()) > END_TIME THEN queue notification for next day
  
  Purpose: Avoid disturbing patient during sleep hours (early morning, late night)

[PATIENT_TIME_ZONE_CRITICAL]
  [PATIENT_TIME_ZONE]: Registered time zone ('America/New_York', 'America/Chicago', etc.)
  
  Notification scheduling logic:
    1. Generate notification at system time (server UTC)
    2. Convert to patient's time zone
    3. Check if within patient's preferred START_TIME / END_TIME window
    4. If yes, send; if no, queue for next eligible time window
  
  Critical: Incorrect time zone = sending notifications at wrong time
  Example: Patient in PST (UTC-8) receives notification at 10 PM PST thinking it's 1 AM (server time UTC)

[MESSAGE_TYPE_CODES] (hypothesis):
  Values likely: '0'=email, '1'=SMS, '2'=push notification, '3'=combined
  
  Each MESSAGE_TYPE can have separate schedule preferences:
    - Patient accepts SMS refill alerts (MESSAGE_TYPE='1') anytime
    - But only wants email appointment reminders (MESSAGE_TYPE='0') on weekdays 9-5
  
  Validate: Business rules for each MESSAGE_TYPE

[SIZE_ESTIMATE] ~50-100 MB (lightweight preferences, few records per patient)

[AUDIT_TRAIL_USE_CASES]
  Compliance: "Patient opted out of SMS notifications" (proof in audit table)
  Debugging: "Why wasn't patient notified of Rx ready?" (check preferences on that date)
  Dispute: "Patient claims never consented to notifications" (audit shows opt-in date)
  Analytics: "What % of patients prefer SMS vs. email?" (aggregate preferences over time)

[DATA_QUALITY_VALIDATION]
  ✓ ID_PATIENT references valid PATIENT record
  ✓ DAY_OF_WEEK valid (Monday, Tuesday, ... Sunday or range like Monday-Friday)
  ✓ START_TIME valid format HH:MM (00:00 to 23:59)
  ✓ END_TIME valid format HH:MM (00:00 to 23:59)
  ✓ START_TIME < END_TIME (start before end)
  ✓ PATIENT_TIME_ZONE valid IANA time zone name (America/New_York, etc.)
  ✓ MESSAGE_TYPE in valid list (0, 1, 2, 3, etc. based on business rules)
  ✓ AUDIT_TIMESTAMP NOT NULL and chronological

[TIME_ZONE_CONVERSION_STRATEGY]
  Post-migration validation:
    1. Load sample patient with PATIENT_TIME_ZONE = 'America/Los_Angeles'
    2. Current server time: 12/15/2026 5:00 PM UTC
    3. Patient time: 12/15/2026 9:00 AM PST (UTC-8)
    4. Patient preferences: START_TIME='09:00', END_TIME='21:00'
    5. Expected: Notification eligible (9:00 <= 9:00 AM PST <= 21:00)
    6. Execute notification, verify time zone conversion accurate

[NOTIFICATION_SCHEDULING_QUEUE]
  Workflow:
    1. Pharmacy creates Rx ready notification (batch nightly)
    2. For each patient: Lookup PATIENT_NOTIFY_SCHEDULE_AUDIT
    3. Check preferred MESSAGE_TYPE (SMS, email, push)
    4. Check DAY_OF_WEEK (if today eligible)
    5. Check START_TIME / END_TIME (convert to patient time zone)
    6. Queue notification for immediate or next eligible time window
    7. Execute queue (send SMS/email at appropriate time)
    8. Log notification sent (audit trail: who, what, when, how)

[OPT_OUT_HANDLING]
  If patient opts out completely:
    [MESSAGE_TYPE] might be NULL or deleted from PATIENT_NOTIFY_SCHEDULE
    Audit table still retains historical preference (opt-out evidence)
  
  Reporting: "Patient opted out date: AUDIT_TIMESTAMP when last record deleted/deactivated"

[INTERNATIONAL_SUPPORT]
  If pharmacy expands internationally:
    PATIENT_TIME_ZONE supports any IANA time zone
      Examples: 'Europe/London', 'Asia/Tokyo', 'Australia/Sydney'
  
  SMS routing: May also support international country codes
    Recommendation: Extend START_TIME/END_TIME to support SMS gateway restrictions

[GDPR_COMPLIANCE] (if EU patients):
  Patient notification preferences = explicit consent record
  Audit table = proof of consent (AUDIT_TIMESTAMP = opt-in date)
  
  GDPR requirement: Demonstrate patient consent + ability to withdraw
  This table satisfies: "Can you prove patient consented to notifications?"

[POST_MIGRATION_CHECKLIST]
  □ Validate sample patient time zones (conversion accuracy)
  □ Confirm MESSAGE_TYPE codes match business rules
  □ Load sample notification queue (simulate nightly job)
  □ Verify SMS/email actually sent to test patient
  □ Audit trail intact (preferences changes tracked)
  □ GDPR consent audit (if applicable)

[NEXT_STEPS_BATCH9]
  Complete PATIENT_NOTES_AUDIT and PATIENT_NOTES conversion
  Both use standard 13-chain partition set
  Complete all 8 Batch 9 files (6 more files created, 2 duplicates skipped)
*/
