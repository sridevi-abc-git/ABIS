CREATE OR REPLACE FUNCTION ABCREPORTS.NonReciptedPayments(p_parms      IN OUT t_parameters,
                                               p_status_ind IN OUT VARCHAR2) 
              RETURN BLOB IS

-- ****************************************************************************
-- File:        NonReciptedPayments.fnc  
-- Author:      Timothy J. Lord
--
-- $Rev: 3044 $  
-- $Date: 2016-09-27 15:06:25 -0700 (Tue, 27 Sep 2016) $
-- Last Changed By:  $$
--
-- Description:      
--
-- Parameters: 
--
-- History:
-------------------------------------------------------------------------------
--    Date         Ticket     Comment
-- 12/15/2015 TJL   8479    Original file created
-- 07/26/2016 TJL   9995    Change displaying check amount to payment amount
-- 09/27/2016 TJL   7213    Changed output from CLOB to BLOB  
-- ****************************************************************************

--*****************************************************************************
--      (Main Process)
--*****************************************************************************
    BEGIN
        DECLARE
            lv_msg              VARCHAR2(12000) := NULL;
            ln_return_code      NUMBER;
            offices_id          t_officeobject;
            lblob               BLOB;
            lxml                XMLTYPE;
            lv_report_heading   VARCHAR2(200);
            lxml_pi             XMLTYPE;
            lxml_tmp            XMLTYPE;
            lxml_payments       XMLTYPE;
            
        BEGIN 
            -- get office id(s)
            offices_id := rqs_utils.BuildOfficeList(p_parms.get_value('OFFICEOBJECTID'),
                                                    lv_msg);

            SELECT XMLELEMENT("ROOT",
                               XMLATTRIBUTES(TO_CHAR(SYSDATE, 'MM/DD/YYYY') AS "REPORT_TAKEN", 
                                             NVL(p_parms.get_value('REPORT_NAME'),'unknown') AS "REPORT_NAME"))
            INTO lxml                                  
            FROM DUAl;
            
            FOR rec IN
                (SELECT objectid, officename 
                FROM query.o_office o
                            WHERE objectid IN (SELECT officeobjectid 
                                                 FROM TABLE(offices_id)))
            LOOP 
                SELECT XMLAGG(XMLELEMENT("OFFICE",
                                         XMLATTRIBUTES(rec.officename as "NAME")))
                  INTO lxml_tmp
                  FROM DUAL;
            
                SELECT APPENDCHILDXML(lxml_tmp, '/OFFICE',
                                      (SELECT XMLAGG(XMLELEMENT("PAYMENTS",
                                                             XMLFOREST(p.payeename,
                                                                       p.licensenumber,
                                                                       TO_CHAR(p.paymentamount, '99999.00') chkamount,
                                                                       TO_CHAR(p.paymentdate, 'MM/DD/YYYY') paymentdate))
                                                  ORDER BY p.objectid DESC)
                                      FROM query.o_payment p
                                     WHERE p.objectid IN (SELECT paymentobjectid
                                                            FROM query.r_paymentoffice x
                                                           WHERE x.officeobjectid = rec.objectid)
                                       AND p.receiptnumber IS NULL
                                       AND p.isvoidedflag = 'N')    
                                     )
                  INTO lxml_tmp
                  FROM DUAL;

                SELECT APPENDCHILDXML(lxml, '/ROOT', lxml_tmp)
                  INTO lxml
                  FROM DUAL;
            
            END LOOP;

            -- add processing instruction to xml  
            SELECT XMLPI(NAME "xml-stylesheet", 'href="../Formats/NonReciptedPayments.xslt" type="text/xsl"') INTO lxml_pi FROM DUAL;
              
            lblob := rqs_utils.clob2blob(lxml_pi.GETCLOBVAL() || lxml.GETCLOBVAL());
            p_status_ind := 'F';
              
            RETURN lblob;

         EXCEPTION
            WHEN OTHERS THEN
                rqs_utils.log(p_log_type          =>  'E',
                              p_job_id            =>  p_parms.get_value('JOB_ID'),
                              p_seq               =>  TO_NUMBER(p_parms.get_value('SEQ')),
                              p_source            =>  'NonReciptedPayments',
                              p_msg               =>  SQLERRM,
                              p_error_trace       =>  dbms_utility.format_error_backtrace);             

                p_status_ind := 'E';
                RETURN utl_raw.cast_to_raw('ERROR: ' || SQLERRM || CHR(10) || CHR(13) ||
                                           'TRACE: ' || dbms_utility.format_error_backtrace);
        END;            
    END NonReciptedPayments;
/
