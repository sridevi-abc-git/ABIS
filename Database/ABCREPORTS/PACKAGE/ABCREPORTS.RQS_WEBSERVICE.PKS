CREATE OR REPLACE PACKAGE ABCREPORTS.RQS_WEBSERVICE AS
-- ****************************************************************************
-- File:        rqs_webservice_v2.pks  
-- Author:      Timothy J. Lord
--
-- $Rev$  
-- $Date$
-- Last Changed By:  $Author$
--
-- Description:    
--
-- 
-- History:
-------------------------------------------------------------------------------
--    Date                  Comment
-- 09/20/2015 TJL       Initial File created  
-- ****************************************************************************
PROCEDURE request(p_parms         IN OUT  t_parameters,
                  p_status_msg    OUT VARCHAR2,
                  p_error         OUT BOOLEAN);

                  
END RQS_WEBSERVICE;
/


CREATE OR REPLACE PUBLIC SYNONYM RQS_WEBSERVICE FOR ABCREPORTS.RQS_WEBSERVICE;


GRANT EXECUTE ON ABCREPORTS.RQS_WEBSERVICE TO ABCREPORTS_ROLE;
