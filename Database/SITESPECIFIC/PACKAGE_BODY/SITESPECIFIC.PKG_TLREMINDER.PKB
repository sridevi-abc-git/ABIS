CREATE OR REPLACE PACKAGE BODY SITESPECIFIC.PKG_TLREMINDER AS
-- ****************************************************************************
-- File:        PKG_TLREMINDER.pkb  
-- Author:      Timothy J. Lord
--
-- $Rev: 2510 $  
-- $Date: 2016-03-20 15:50:16 -0700 (Sun, 20 Mar 2016) $
-- Last Changed By:  $Author: tlord $
--
-- Description: PKG_TLEMAI package specifications   
--
-- 
-- History:
-------------------------------------------------------------------------------
--    Date            Comment
-- 01/03/2014 TJL  Initial File created  
-- 03/17/2016 TJL  9242  Changed SYSDATE +2 to +5 and added filter to remove 
--                         Records with out email addresses 
-- ****************************************************************************
PROCEDURE SendReminders(p_reminderDate IN DATE DEFAULT SYSDATE + 5) IS
-- t_EmailId          API.PKG_DEFINITION.udt_Id;
 
    BEGIN
        -- get list of classes to send email reminders
        FOR r_student IN 
                (SELECT sr.emailaddress,
                        sr.fromemailaddress,
                        sr.reminderemailsubject,
                        sr.reminderemailbody
                   FROM query.o_Tl_Studentregistration sr
                   JOIN api.relationships r ON r.FromObjectId = sr.objectid
                   JOIN query.o_Tl_Leadclassinfo lc ON lc.ObjectId = r.ToObjectId
                  WHERE lc.classcancelled = 'N'
                    AND TRUNC(lc.trainingdate) = TRUNC((p_reminderDate))
                    AND sr.emailaddress IS NOT NULL
                )
        LOOP
            -- Send emails
            sitespecific.pkg_tlemail.sendemail(p_fromaddress   => r_student.fromemailaddress,
                                               p_toaddress     => r_student.emailaddress,
                                               p_subject       => r_student.reminderemailsubject,
                                               p_body          => r_student.reminderemailbody);
        END LOOP; 
    
    END SendReminders;
    
END PKG_TLREMINDER;
/
