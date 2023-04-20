CREATE OR REPLACE PROCEDURE ABC.gen_active0222_notice(
    a_duedate       DATE DEFAULT NULL,
    a_maildate      DATE DEFAULT NULL,
    a_firstnotice   VARCHAR2 DEFAULT NULL)                      -- ('Y' , 'N')
AS
    -- **************************************************************************
    -- File:        GEN_ACTIVE0222_NOTICE.PRC
    -- Author:      Ning Wong
    --
    -- $Rev$
    -- $Date$
    -- Last Changed By:  $Author$
    --
    -- Description:
    --  This procedure is invoked by the First/Second Notice (Letter) report.
    --  It updates the ABC.ACTIVE0222_RPT fields with the MailDate, DueDate, and FirstNotice.
    --  Firstnotice will be uppercase 'Y' or 'N'. Data Entry Validation has not been done at the User Prompt Level!
    --
    --
    --  The original letter would run the GEN_ACTIVE02222_RPT procedure that takes over an hour. This was
    --  redundant processing when the only fields that were different was the Mail Date, Due Date,
    --  and firstnotice fields.
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 11/17/2016 NW          Initial procedure created
    -- 01/22/2018 NW          Switch parameter order and put duedate ahead of maildate
    -- 02/29/2018 NW          Modified update to not update FIRSTNOTICE
    -- 08/20/2018 TJL         Initial Check-in
    -- **************************************************************************

    t_maildate      DATE := TRUNC(NVL(a_maildate, CURRENT_DATE));
    t_duedate       DATE := TRUNC(NVL(a_duedate, CURRENT_DATE));
    t_firstnotice   VARCHAR2(1) := NVL(UPPER(a_firstnotice), 'Y');
BEGIN
    UPDATE abc.active0222_rpt
       SET maildate = t_maildate, duedate = t_duedate;

    COMMIT;
END;                                             -- GEN_ACTIVE0222_1ST_NOTICE;
/


GRANT EXECUTE ON ABC.GEN_ACTIVE0222_NOTICE TO PUBLIC;
