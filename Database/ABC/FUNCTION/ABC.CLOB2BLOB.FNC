CREATE OR REPLACE FUNCTION ABC.clob2blob(p_clob IN CLOB)
    RETURN BLOB
IS
    -- **************************************************************************
    -- File:        CLOB2BLOB.FNC
    -- Author:      CX
    --
    -- $Rev$
    -- $Date$
    -- Last Changed By:  $Author$
    --
    -- Description:
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 08/21/2018 TJL         Initial Check-in
    -- **************************************************************************

    l_blob       BLOB := NULL;
    ln_pos       PLS_INTEGER := 1;
    buffer       RAW(32767);
    ln_lob_len   PLS_INTEGER;
    ln_len       NUMBER := 32000;
BEGIN
    IF p_clob IS NOT NULL THEN
        ln_lob_len   := dbms_lob.getlength(p_clob);

        dbms_lob.createtemporary(l_blob, TRUE);
        dbms_lob.open(l_blob, dbms_lob.lob_readwrite);

        LOOP
            buffer   :=
                utl_raw.cast_to_raw(dbms_lob.SUBSTR(p_clob, ln_len, ln_pos));

            IF utl_raw.LENGTH(buffer) > 0 THEN
                dbms_lob.writeappend(l_blob, utl_raw.LENGTH(buffer), buffer);
            END IF;

            ln_pos   := ln_pos + ln_len;
            EXIT WHEN ln_pos > ln_lob_len;
        END LOOP;
    END IF;

    NULL;
    RETURN l_blob;
END clob2blob;
/
