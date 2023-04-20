CREATE OR REPLACE PACKAGE ABC.PKG_PRICE_POSTINGS AS
-- ****************************************************************************
-- File:        PKG_PRICE_POSTINGS.pks        
-- Author:      Ning Wong
--
-- Description: Create a Master Licensee File and email to pps@abc.ca.gov   
--
-- 
-- History:
-------------------------------------------------------------------------------
--    Date                      Comment
-- 05/28/2021 NW            Price Posting Licensees data export
--
-- ****************************************************************************

PROCEDURE LOAD_LICENSEES; 

PROCEDURE GET_LICENSEES (	
  p_clob    OUT CLOB,                   -- the report data
  p_count   OUT NUMBER,                 -- count of licensees                  
  p_message OUT VARCHAR                 -- message returned       
);

PROCEDURE SEND_EMAIL ( 
  p_to          IN VARCHAR2,
  p_from        IN VARCHAR2,
  p_subject     IN VARCHAR2,
  p_text_msg    IN VARCHAR2 DEFAULT NULL,
  p_attach_name IN VARCHAR2 DEFAULT NULL,
  p_attach_mime IN VARCHAR2 DEFAULT NULL,
  p_attach_clob IN CLOB     DEFAULT NULL   
);

PROCEDURE LICENSEES_JOB;

END PKG_PRICE_POSTINGS;
/
