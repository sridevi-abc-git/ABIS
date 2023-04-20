CREATE OR REPLACE FUNCTION ABCLQS.clob2blob 
( p_clob IN CLOB ) 
RETURN BLOB IS

l_blob          BLOB            := NULL;
ln_pos          PLS_INTEGER     := 1;
buffer          RAW( 32767 );
ln_lob_len      PLS_INTEGER;
ln_len          NUMBER          := 32000;

BEGIN
    IF p_clob IS NOT NULL THEN
        ln_lob_len := DBMS_LOB.getlength( p_clob );
            
        DBMS_LOB.createtemporary( l_blob, TRUE );
        DBMS_LOB.open( l_blob, DBMS_LOB.lob_readwrite );

        LOOP
            buffer := UTL_RAW.cast_to_raw( DBMS_LOB.SUBSTR( p_clob, ln_len, ln_pos ) );

            IF UTL_RAW.LENGTH( buffer ) > 0 THEN
                DBMS_LOB.writeappend( l_blob, UTL_RAW.LENGTH( buffer ), buffer );
            END IF;

            ln_pos := ln_pos + ln_len;
            EXIT WHEN ln_pos > ln_lob_len;
        END LOOP;
    END IF;

  null;
  RETURN l_blob;
END clob2blob;
/
