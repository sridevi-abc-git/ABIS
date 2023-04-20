CREATE OR REPLACE PACKAGE BODY ABCLQS.lqs_covid19
AS
    -- **************************************************************************
    -- File:        LQS_COVID19.PKB
    -- Author:      Timothy J.Lord
    --
    -- Description:
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 02/03/2021 TJL        Package Created
    -- 07/01/2021 TJL 25562 Change how to determine what fees will be returned
    -- 07/06/2021 TJL 25624 Add testing for expiring licenses
    -- 08/31/2021 PK 26145  Online waiver submission issue Fixed expired date
    -- 09/14/2021 PK WO 26240
    -- 02/25/2022 PK WO27619 Added exp date and payment batch to fix WO 27619
    -- 05/03/2022 PK WO28238 Online Waiver System Issue regarding renewal expiration dates that end on the weekend
    -- 05/26/2022 NW Added Issue Date (Elligible if issued prior to 1/1/2021) 
    --               Rolled back Current Status, Active between 3/1/2022 through 12/31/2022 
    --
    -- **************************************************************************

------------------------------
PROCEDURE covid19(
------------------------------
  a_parameters IN XMLTYPE, 
  a_reportdata OUT BLOB, 
  a_message OUT VARCHAR
)
IS
BEGIN
  CASE
  WHEN a_parameters.EXISTSNODE('/ROOT/REQUEST') = 1 THEN
      abclqs.lqs_covid19.get_fees(a_parameters => a_parameters,
                                  a_reportdata => a_reportdata,
                                  a_message   => a_message);
  WHEN a_parameters.EXISTSNODE('/ROOT/UPDATE') = 1 THEN
      abclqs.lqs_covid19.upd_cert(a_parameters => a_parameters,
                                  a_reportdata => a_reportdata,
                                  a_message   => a_message);
  ELSE
      a_message   := 'Invalid Parameter Node';
  END CASE;
END;

------------------------------
PROCEDURE get_fees(
------------------------------
  a_parameters IN XMLTYPE, 
  a_reportdata OUT BLOB, 
  a_message OUT VARCHAR
)
IS
  t_relieflicensetypes   VARCHAR2(400) := api.pkg_constantquery.VALUE('COVID19RELIEFLICENSETYPES');
  t_startincludedate     DATE := TO_DATE('01-MAR-20');

  t_licensenumber        VARCHAR2(10);
  t_lblob                BLOB;
  t_lxml                 XMLTYPE;
  t_validlicno           VARCHAR2(1) := 'N';
  t_fees                 VARCHAR2(1);
  t_expired              VARCHAR2(1);
  t_issued               VARCHAR2(1);
  t_sqlerrm              VARCHAR2(4000);
  t_backtrace            VARCHAR2(4000);
  t_sqlcode              NUMBER;
  t_message              VARCHAR2(4000);
  t_validActive          VARCHAR2(1):='Y';        -- Check for valid active range between 3/1/2021 - 12/31/2022
  t_validStatus          VARCHAR2(1):='Y';        -- Check to see if currently active, or if suspended after 3/1/2020 
  t_validIssueDate       VARCHAR2(1):='Y';        -- Check to see if license was issued prior to 1/1/2021 

BEGIN

  SELECT TRIM(EXTRACTVALUE(a_parameters, '/ROOT/REQUEST/LICENSE')) INTO t_licensenumber FROM DUAL;

-- check for valid license number
-- 07/01/2021 TJL 25562
  BEGIN
    SELECT 'Y'
    INTO t_validlicno
    FROM abclqs.all_licenses l
    WHERE l.licenseno = t_licensenumber
    AND ROWNUM = 1;

    SELECT 
      CASE SUM(NVL2(ri.paid, 0, 1)) WHEN 0 THEN 'N' ELSE 'Y' END, 
      CASE SUM(NVL2(ri.issued, 0, 1)) WHEN 0 THEN 'Y' ELSE 'N' END, --- 09/14/2021 PK WO 26240
      --CASE WHEN MAX(ri.expirationdate) < trunc(SYSDATE) THEN 'Y' ELSE 'N' END  -- 07/06/2021 TJL 25624 08/31/2021 PK 26145
      CASE WHEN MAX(ri.RenewalDate) < trunc(SYSDATE) THEN 'Y' ELSE 'N' END  -- 05/03/2022 PK WO28238 PK 26145--trunc(SYSDATE)
    INTO t_fees, t_issued, t_expired
    FROM abclqs.renewal_info ri
    WHERE ri.licensenumber = t_licensenumber;

    
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
    NULL;
  END;

  dbms_output.put_line('expired: ' || t_expired);

  t_message  :=
  CASE
    WHEN t_validlicno = 'N' THEN
      'Invalid License Number'
    WHEN t_fees = 'N' OR t_issued = 'Y' THEN
      'No Renewal Fees Due'
    WHEN t_expired = 'Y' THEN
      'License Expired'
/*      
    WHEN t_validActive = 'N' THEN
      'Ineligible License'
    WHEN  t_validStatus ='N' THEN
      'License is not currently active'
*/      
    ELSE
      NULL

  END;

IF (t_validlicno = 'Y') THEN
  SELECT DISTINCT
    XMLELEMENT(
      "ROOT",
      XMLAGG(
        XMLELEMENT(
          "RESULT",
          XMLFOREST(
            al.licensenumber,
            al.licensee,
            ( 
              SELECT SUM(feeamount)
              FROM abclqs.renewal_info ri2
              WHERE ri2.licensenumber = al.licensenumber and ri2.expirationdate  >= LAST_DAY( ADD_MONTHS(SYSDATE , - 11 ))and ri2.PAYMENTBATCH is null
            ) AS "TOTALRENEWAL",-- added exp date and payment batch to fix WO 27619
            t_message AS "MESSAGE",
            XMLAGG(
              XMLELEMENT(
                "FEE",
                XMLFOREST(
                  ri.licensetypecode,
                  ri.licensetypedescription,
                  CASE
                  WHEN ri.primarysecondary = 'P' THEN
                    'M' || 
                    CASE
                      WHEN ri.secondarycount > 0 THEN
                        '-' || TO_CHAR(ri.secondarycount, 'FM000')
                      ELSE
                        NULL
                    END
                  WHEN ri.primarysecondary != 'P' THEN
                    '-' || TO_CHAR(ri.secondarycount, 'FM000')
                  ELSE
                    NULL
                  END quantity,
                  ri.feeamount,
                  TO_CHAR(ri.expirationdate, 'DD-MON-YYYY') expirationdate,
                  ri.status,
                  TO_CHAR(ri.statusdate, 'DD-MON-YYYY') statusdate,

                  CASE NVL(sc.eligible, 'N')
                    WHEN 'Y' THEN TO_CHAR(sc.certificationdate, 'DD-MON-YYYY')
                    ELSE NULL
                  END certificationdate,

                  -- 6/2/2022 NW added ISSUE DATE and WASACTIVE
                  TO_CHAR(ri.IssueDate, 'DD-MON-YYYY') ISSUEDATE, -- NW 6/2/2022
                  (
                    SELECT 
                      CASE 
                      WHEN count(1) > 0 THEN 'Y'
                      ELSE 'N'
                      END 
                    FROM extension.jobStatusChange SC
                    WHERE SC.jobid = RI.jobid 
                      AND StatusName IN ('ACTIVE') 
                      AND NOT ( effectiveStartDate > '31-DEC-2020' OR NVL(effectiveEndDate,TRUNC(SYSDATE)) < '1-MAR-2020' )
                  ) WASACTIVE
                )
              )
            ORDER BY 1
          )
          fees))))
  INTO t_lxml
  FROM (
    SELECT DISTINCT 
      l.licenseno licensenumber,
      l.primarylicensee licensee,
      l.type_status_code status,
      l.premaddressline1 || ' ' || l.premaddressline2 address,
      l.premcity || ', '|| premstate || '. ' || premzip citystzip
    FROM abclqs.all_licenses l
    WHERE l.licenseno = t_licensenumber and l.APP_OR_LIC = 'LIC'
  ) al -- and l.APP_OR_LIC = 'LIC' Added by Pawan on 1/21/2022 
  LEFT OUTER JOIN abclqs.renewal_info ri ON (
    al.licensenumber = ri.licensenumber AND 
    t_issued = 'N' AND t_fees = 'Y' AND ( NVL(ri.paid, 'N') = 'N'  )
  ) 
  LEFT OUTER JOIN abc.self_certification sc ON (
    sc.licensenumber = ri.licensenumber AND 
    sc.licensetypecode = ri.licensetypecode AND 
    sc.expirationdate = ri.expirationdate
  )
  GROUP BY 
    al.licensenumber,
    al.status,
    al.licensee,
    al.address,
    al.citystzip;
ELSE
  SELECT XMLELEMENT("ROOT", XMLELEMENT("RESULT", XMLELEMENT("MESSAGE", t_message))) INTO t_lxml FROM DUAL;
END IF;

  a_reportdata   := abclqs.lqs.clob2blob(t_lxml.getclobval());
EXCEPTION
WHEN OTHERS THEN
  t_sqlcode     := SQLCODE;
  t_sqlerrm     := SQLERRM;
  t_backtrace   := DBMS_UTILITY.format_error_backtrace;

  a_message     := 'Error Processing Request';
END get_fees;

-------------------
PROCEDURE upd_cert(
-------------------
  a_parameters IN XMLTYPE, 
  a_reportdata OUT BLOB, 
  a_message OUT VARCHAR
)

IS
CURSOR upd(p_parameters IN XMLTYPE)
IS
  SELECT 
    x.licensenumber,
    x.expirationdate,
    x.licensetypecode,
    x.phonenumber,
    x.emailaddress,
    x.sname,
    x.eligible,
    x.rangevalue
  FROM (
    SELECT *
    FROM XMLTABLE(
      '/ROOT/UPDATE'
      PASSING p_parameters
      COLUMNS 
        licensenumber VARCHAR2(10) PATH 'LICENSE',
        phonenumber VARCHAR2(20) PATH 'PHONENUMBER',
        emailaddress VARCHAR2(500) PATH 'EMAILADDRESS',
        sname VARCHAR2(100) PATH 'SNAME',
        fees XMLTYPE PATH 'FEES'
    ) p,
    XMLTABLE(
      'FEES/FEE'
      PASSING p.fees
      COLUMNS 
        licensetypecode VARCHAR2(3) PATH 'LICENSETYPECODE',
        expirationdate DATE PATH 'EXPIRATIONDATE',
        eligible VARCHAR2(1) PATH 'ELIGIBLE',
        rangevalue VARCHAR2(20) PATH 'RANGEVALUE'
    ) c
  ) x
  JOIN abclqs.renewal_info ri
    ON x.licensenumber = ri.licensenumber
    AND x.licensetypecode = ri.licensetypecode
    AND x.expirationdate = ri.expirationdate;

  t_licensenumber     VARCHAR2(10);
  t_licensetypecode   VARCHAR2(3);
  t_sqlerrm           VARCHAR2(4000);
  t_backtrace         VARCHAR2(4000);
  t_sqlcode           NUMBER;
  t_count             NUMBER := 0;
  t_first             BOOLEAN := TRUE;

BEGIN
  FOR recs IN upd(a_parameters)
  LOOP
    t_licensenumber     := recs.licensenumber;
    t_licensetypecode   := recs.licensetypecode;

    INSERT INTO  /*+ IGNORE_ROW_ON_DUPKEY_INDEX(abc.self_certification, self_certification_pk) */
    abc.self_certification(
      licensenumber,
      expirationdate,
      licensetypecode,
      phonenumber,
      emailaddress,
      sname,
      certificationdate,
      eligible,
      rangevalue
    )
    VALUES (
      recs.licensenumber,
      recs.expirationdate,
      recs.licensetypecode,
      SUBSTR(REGEXP_REPLACE(recs.phonenumber, '[^[:digit:]]+'), 1, 10),
      recs.emailaddress,
      recs.sname,
      CASE WHEN NVL(recs.eligible, 'N') = 'Y' THEN SYSDATE ELSE NULL END,
      recs.eligible,
      CASE recs.licensetypecode WHEN '02' THEN recs.rangevalue ELSE NULL END
    )

    LOG ERRORS INTO abc.err$_self_certification
    ('INSERT')
    REJECT LIMIT UNLIMITED;

    t_count := SQL%ROWCOUNT;

    IF (t_count = 0) THEN
      INSERT INTO abclqs.packet_log pl(
        licensenumber,
        licensetypecode,
        packetdata,
        SQLERRM,
        backtrace
      )
      VALUES (
        recs.licensenumber,
        recs.licensetypecode,
        a_parameters.getclobval(),
        'self_certification table not updated',
        NULL
      );

      a_message   := 'Unable to Certify License ';
    END IF;
  END LOOP;

  COMMIT;

  IF (a_message IS NULL AND t_count > 0) THEN
      a_message   := 'License Certified';
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    t_sqlcode     := SQLCODE;
    t_sqlerrm     := SQLERRM;
    t_backtrace   := DBMS_UTILITY.format_error_backtrace;

    INSERT INTO abc.err$_self_certification e(e.ora_err_number$, e.ora_err_mesg$, e.backtrace)
    VALUES (t_sqlcode, SUBSTR(t_sqlerrm, 1, 2000), SUBSTR(t_backtrace, 1, 4000));

    INSERT INTO abclqs.packet_log pl(
      licensenumber,
      licensetypecode,
      packetdata,
      SQLERRM,
      backtrace
    )
    VALUES (
      t_licensenumber,
      t_licensetypecode,
      a_parameters.getclobval(),
      SUBSTR(t_sqlerrm, 1, 4000),
      SUBSTR(t_backtrace, 1, 4000)
    );

    COMMIT;
    a_message     := 'Error Processing Request';
    
END upd_cert;
END;
/
