CREATE OR REPLACE PACKAGE BODY SITESPECIFIC.utl_dbws
IS
    -- **************************************************************************
    -- File:        UTL_DBWS.PKB
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
    -- 08/20/2018 TJL         Initial Check-in
    -- **************************************************************************

    --- Forward Declarations ---

    FUNCTION invoke_proxy
        RETURN VARCHAR2;

    FUNCTION invoke_proxy(request SYS.XMLTYPE)
        RETURN SYS.XMLTYPE;

    FUNCTION get_services_proxy(wsdl_document_location VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION create_service_proxy(wsdl_document_location VARCHAR2,
                                  service_name    VARCHAR2)
        RETURN service;

    FUNCTION get_ports_proxy(service_handle service)
        RETURN VARCHAR2;

    FUNCTION get_operations_proxy(service_handle service, port qname)
        RETURN VARCHAR2;

    FUNCTION get_return_proxy(call_handle call)
        RETURN VARCHAR2;

    FUNCTION get_in_parameters_proxy(call_handle call)
        RETURN VARCHAR2;

    FUNCTION get_out_parameters_proxy(call_handle call)
        RETURN VARCHAR2;

    PROCEDURE set_call(call_handle call);

    FUNCTION output_values(call_handle call)
        RETURN VARCHAR2;

    FUNCTION get_any(ch VARCHAR2)
        RETURN ANYDATA;

    FUNCTION get_char
        RETURN VARCHAR2;

    FUNCTION get_number
        RETURN NUMBER;

    FUNCTION get_raw
        RETURN RAW;

    FUNCTION get_date
        RETURN DATE;

    FUNCTION get_timestamp
        RETURN TIMESTAMP;

    FUNCTION get_timestamp_tz
        RETURN TIMESTAMP WITH TIME ZONE;

    FUNCTION get_timestamp_ltz
        RETURN TIMESTAMP WITH LOCAL TIME ZONE;

    FUNCTION get_boolean
        RETURN NUMBER;

    FUNCTION get_byte
        RETURN NUMBER;

    FUNCTION get_short
        RETURN NUMBER;

    FUNCTION get_integer
        RETURN NUMBER;

    FUNCTION get_long
        RETURN NUMBER;

    FUNCTION get_float
        RETURN NUMBER;

    FUNCTION get_double
        RETURN NUMBER;

    FUNCTION get_clob
        RETURN CLOB;

    FUNCTION get_blob
        RETURN BLOB;

    FUNCTION get_bfile
        RETURN BFILE;

    FUNCTION get_rowid
        RETURN ROWID;

    FUNCTION get_xmltype
        RETURN XMLTYPE;

    PROCEDURE set_any(obj ANYDATA);

    PROCEDURE set_null;

    PROCEDURE set_null(c VARCHAR2);

    PROCEDURE set_char(c VARCHAR2);

    PROCEDURE set_number(n NUMBER);

    PROCEDURE set_raw(r RAW);

    PROCEDURE set_date(d DATE);

    PROCEDURE set_boolean(b NUMBER);

    PROCEDURE set_blob(b BLOB);

    PROCEDURE set_clob(c CLOB);

    PROCEDURE set_bfile(b BFILE);

    PROCEDURE set_rowid(r ROWID);

    PROCEDURE set_timestamp(d TIMESTAMP);

    PROCEDURE set_timestamp_tz(d TIMESTAMP WITH TIME ZONE);

    PROCEDURE set_timestamp_ltz(d TIMESTAMP WITH LOCAL TIME ZONE);

    PROCEDURE set_xmltype(x XMLTYPE);

    --- End Forward Declarations ---


    -------------------------------------------
    -------------------------------------------
    ---                                     ---
    --- Handling of qualified names (QName) ---
    ---                                     ---
    -------------------------------------------
    -------------------------------------------

    -- Construct a qualified name
    --   namespaceURI - Namespace URI for the QName, null if none.
    --      localPart - Local part of the QName
    FUNCTION to_qname(name_space VARCHAR2, name VARCHAR2)
        RETURN qname
    IS
    BEGIN
        IF name_space IS NULL
        OR name_space = '' THEN
            RETURN name;
        ELSIF name_space = 'xsd'
           OR name_space = 'NSURI_SCHEMA_XSD' THEN
            RETURN '{http://www.w3.org/2001/XMLSchema}' || name;
        ELSIF name_space = 'xsi'
           OR name_space = 'NSURI_SCHEMA_XSI' THEN
            RETURN '{http://www.w3.org/2001/XMLSchema-instance}' || name;
        ELSIF name_space = 'soapenc'
           OR name_space = 'NSURI_SOAP_ENCODING' THEN
            RETURN '{http://schemas.xmlsoap.org/soap/encoding/}' || name;
        ELSIF name_space = 'soapenv'
           OR name_space = 'NSURI_SOAP_ENVELOPE' THEN
            RETURN '{http://schemas.xmlsoap.org/soap/envelope/}' || name;
        ELSIF name_space = 'NSURI_SOAP_NEXT_ACTOR' THEN
            RETURN '{http://schemas.xmlsoap.org/soap/actor/next}' || name;
        ELSE
            RETURN '{' || name_space || '}' || name;
        END IF;
    END to_qname;

    -- Return the namespace URI of a qualified name, null if none.
    FUNCTION get_namespace_uri(name qname)
        RETURN VARCHAR2
    IS
        pos   INTEGER;
    BEGIN
        pos   := INSTR(name, '}');

        IF pos = 0 THEN
            RETURN NULL;
        ELSE
            RETURN SUBSTR(name, 2, pos - 1);
        END IF;
    END get_namespace_uri;

    -- Return the local part of a qualified name
    FUNCTION get_local_part(name qname)
        RETURN VARCHAR2
    IS
        pos   INTEGER;
    BEGIN
        pos   := INSTR(name, '}');

        IF pos = 0 THEN
            RETURN name;
        ELSE
            RETURN SUBSTR(name, pos + 1);
        END IF;
    END get_local_part;

    -- The following is a list of predefined namespaces that may be
    -- used in the nameSpace parameter of to_QName
    -- 'NSURI_SCHEMA_XSD', 'xsd'        - Namespace URI for XML Schema XSD
    -- 'NSURI_SCHEMA_XSI', 'xsi'        - Namespace URI for XML Schema XSI
    -- 'NSURI_SOAP_ENCODING', 'soapenc' - Namespace URI for SOAP 1.1 Encoding
    -- 'NSURI_SOAP_ENVELOPE', 'soapenv' - Namespace URI for SOAP 1.1 Envelope
    -- 'NSURI_SOAP_NEXT_ACTOR'          - Namespace URI for SOAP 1.1 next actor role

    -- Split a string into a list of QNAMES using ";" as separator.
    --    string - the string to be split
    FUNCTION split_string(s VARCHAR2)
        RETURN qname_list
    IS
        res    qname_list;
        pos    INTEGER;
        idx    BINARY_INTEGER;
        strg   VARCHAR2(8128);
    BEGIN
        strg   := s;

        pos    := INSTR(strg, ';');
        idx    := 1;

        WHILE (pos > 0)
        LOOP
            res(idx)   := SUBSTR(strg, 1, pos - 1);
            idx        := idx + 1;
            strg       := SUBSTR(strg, pos + 1);
            pos        := INSTR(strg, ';');
        END LOOP;

        IF strg IS NOT NULL THEN
            res(idx)   := strg;
        END IF;

        RETURN res;
    END split_string;

    -- Set the proxy address
    --   proxy - the http proxy address, e.g., www-proxy.us.acme.com:80
    PROCEDURE set_http_proxy(httpproxy VARCHAR2)
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.setHttpProxy(java.lang.String)' ;

    -------------------------------------------
    -------------------------------------------
    ---                                     ---
    --- Service instantiation based on WSDL ---
    ---                                     ---
    -------------------------------------------
    -------------------------------------------

    -- List the qualified names of all the services in a WSDL document
    --   wsdlDocumentLocation - URL for the WSDL document
    FUNCTION get_services(wsdl_document_location URITYPE)
        RETURN qname_list
    IS
    BEGIN
        RETURN split_string(
                   get_services_proxy(wsdl_document_location.geturl()));
    END get_services;

    FUNCTION get_services_proxy(wsdl_document_location VARCHAR2)
        RETURN VARCHAR2
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.getServices(java.lang.String) return java.lang.String' ;


    -- Create a Service instance.
    --   serviceName - QName for the service
    --   Returns a handle to the Service instance.
    FUNCTION create_service(service_name qname)
        RETURN service
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.createService(java.lang.String) return long' ;

    -- Create a Service instance.
    --   wsdlDocumentLocation - URL for the WSDL document location for the service
    --   serviceName - QName for the service
    --   Returns a handle to the Service instance.
    FUNCTION create_service(wsdl_document_location URITYPE,
                            service_name    qname)
        RETURN service
    IS
    BEGIN
        RETURN create_service_proxy(wsdl_document_location.geturl(),
                                    service_name);
    END create_service;

    FUNCTION create_service_proxy(wsdl_document_location VARCHAR2,
                                  service_name    VARCHAR2)
        RETURN service
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.createService(java.lang.String,java.lang.String) return long' ;


    -- List the qualified names of all of the ports in a service.
    --    service_Handle - Service instance whose ports are returned
    FUNCTION get_ports(service_handle service)
        RETURN qname_list
    IS
    BEGIN
        RETURN split_string(get_ports_proxy(service_handle));
    END get_ports;

    FUNCTION get_ports_proxy(service_handle service)
        RETURN VARCHAR2
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.getPorts(long) return java.lang.String' ;

    FUNCTION get_operations(service_handle service, port qname)
        RETURN qname_list
    IS
        res   qname_list;
    BEGIN
        RETURN split_string(get_operations_proxy(service_handle, port));
        RETURN res;
    END get_operations;

    FUNCTION get_operations_proxy(service_handle service, port qname)
        RETURN VARCHAR2
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.getOperations(long,java.lang.String) return java.lang.String' ;


    -- Release a particular Service instance. This will implicitly
    -- release all Call instances that have been created for this
    -- service instance.
    --    service_Handle - Service instance that is to be released
    PROCEDURE release_service(service_handle service)
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.releaseService(long)' ;

    -- Release all Service instances.
    PROCEDURE release_all_services
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.releaseAllServices()' ;

    ---------------------------------------------
    ---------------------------------------------
    ---                                       ---
    --- Call instantiation for document style ---
    ---                                       ---
    ---------------------------------------------
    ---------------------------------------------

    -- Create a Call instance.
    --   serviceHandle - the service instance that is to be called.
    FUNCTION create_call(service_handle service)
        RETURN call
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.createCall(long) return long' ;


    ---------------------------------------------
    ---------------------------------------------
    ---                                       ---
    --- Call instantiation based on a service ---
    ---     port and an operation name        ---
    ---                                       ---
    ---------------------------------------------
    ---------------------------------------------

    -- Create a Call instance.
    --   serviceHandle - the service instance that is to be called.
    --   portName - qualified name for the port. Use first port if this is NULL.
    --   operationName - qualified name for the operation
    FUNCTION create_call(service_handle  service,
                         port_name       qname,
                         operation_name  qname)
        RETURN call
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.createCall(long,java.lang.String,java.lang.String) return long' ;

    -- Release a particular Call instance.
    --    call_Handle - Call instance that is to be released
    PROCEDURE release_call(call_handle call)
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.releaseCall(long)' ;

    -- Set the value of a particular property on a Call.
    --   callHandle - the instance of the call
    --   endpoint   - the endpoint for the call
    PROCEDURE set_target_endpoint_address(call_handle     call,
                                          endpoint        VARCHAR2)
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.setTargetEndpointAddress(long,java.lang.String)' ;


    -- Manipulation of call properties. The following are supported keys
    -- and default settings for standard Call properties.
    --
    -- Key                 - Explanation of Value, Default value.
    -- 'USERNAME'          - User name for authentication
    -- 'PASSWORD'          - Password for authentication
    -- 'ENCODINGSTYLE_URI' - Encoding style specified as a namespace URI.
    --                       The default value is the SOAP 1.1 encoding
    --                       'http://schemas.xmlsoap.org/soap/encoding/'
    -- 'OPERATION_STYLE'   - Standard property for operation style.
    --                       Set to 'rpc' if the operation style is rpc;
    --                       'document' if the operation style is document.
    -- 'SESSION_MAINTAIN'  - This boolean property is used by a service client to indicate whether or
    --                       not it wants to participate in a session with a service endpoint.
    --                       If this property is set to 'true', the service client indicates that it
    --                       wants the session to be maintained. If set to 'false', the session is
    --                       not maintained. The default value for this property is 'false'.
    -- 'SOAPACTION_USE'    - This boolean property indicates whether or not SOAPAction
    --                       is to be used. The default value of this property is 'false'.
    -- 'SOAPACTION_URI'    - Indicates the SOAPAction URI if the SOAPACTION_USE property
    --                       is set to 'true'.

    -- Return the value of a particular property on a Call.
    --   callHandle - the instance of the call
    --   key        - the key for the property
    --   Returns the value of the property or null if not set.
    FUNCTION get_property(call_handle call, key VARCHAR2)
        RETURN VARCHAR2
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.getProperty(long,java.lang.String) return java.lang.String' ;


    -- Set the value of a particular property on a Call.
    --   callHandle - the instance of the call
    --   key        - the key for the property
    --   value      - the value for the property
    PROCEDURE set_property(call_handle call, key VARCHAR2, VALUE VARCHAR2)
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.setProperty(long,java.lang.String,java.lang.String)' ;

    -- Clear the value of a particular property on a Call.
    --   callHandle - the instance of the call
    --   key        - the key for the property
    PROCEDURE remove_property(call_handle call, key VARCHAR2)
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.removeProperty(long,java.lang.String,java.lang.String)' ;

    -- Return the XML type of the call's return value
    --   callHandle - the instance of the call
    FUNCTION get_return_type(call_handle call)
        RETURN qname
    IS
    BEGIN
        RETURN get_return_proxy(call_handle);
    END get_return_type;

    FUNCTION get_return_proxy(call_handle call)
        RETURN VARCHAR2
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.getReturnTypeProxy(long) return java.lang.String' ;

    -- Return the XML types of the call's input parameters
    --   callHandle - the instance of the call
    FUNCTION get_in_parameter_types(call_handle call)
        RETURN qname_list
    IS
    BEGIN
        RETURN split_string(get_in_parameters_proxy(call_handle));
    END get_in_parameter_types;

    FUNCTION get_in_parameters_proxy(call_handle call)
        RETURN VARCHAR2
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.getInParametersProxy(long) return java.lang.String' ;

    -- Return the XML types of the call's output parameters
    --   callHandle - the instance of the call
    FUNCTION get_out_parameter_types(call_handle call)
        RETURN qname_list
    IS
    BEGIN
        RETURN split_string(get_out_parameters_proxy(call_handle));
    END get_out_parameter_types;

    FUNCTION get_out_parameters_proxy(call_handle call)
        RETURN VARCHAR2
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.getOutParametersProxy(long) return java.lang.String' ;

    -- Invokes a specific operation using a synchronous request-response
    -- interaction mode.
    --   callHandle - the instance of the call
    --   inputParams - The input parameters for this invocation.
    --   Returns the return value or null.
    FUNCTION invoke(call_handle call, input_params anydata_list)
        RETURN ANYDATA
    IS
        idx   BINARY_INTEGER;
    BEGIN
        set_call(call_handle);

        IF input_params.COUNT != 0 THEN
            idx   := input_params.FIRST;
            set_any(input_params(idx));

            WHILE idx != input_params.LAST
            LOOP
                idx   := input_params.NEXT(idx);
                set_any(input_params(idx));
            END LOOP;
        END IF;

        RETURN get_any(invoke_proxy);
    END invoke;

    FUNCTION invoke_proxy
        RETURN VARCHAR2
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.invokeProxy() return java.lang.String' ;


    -- Invokes a Document-style webservices in a synchronous
    -- request-response interaction mode.
    --   callHandle - the instance of the call
    --   request - a SOAPElement request
    --   Returns a SOAPElement response
    FUNCTION invoke(call_handle call, request SYS.XMLTYPE)
        RETURN SYS.XMLTYPE
    IS
    BEGIN
        set_call(call_handle);
        RETURN invoke_proxy(request);
    END invoke;

    FUNCTION invoke_proxy(request SYS.XMLTYPE)
        RETURN SYS.XMLTYPE
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.invokeProxy(oracle.xdb.XMLType) return oracle.xdb.XMLType' ;


    -- Obtain the output arguments after a call invocation
    --   callHandle - the instance of the call
    --   Returns the output arguments in order.
    FUNCTION get_output_values(call_handle call)
        RETURN anydata_list
    IS
        res    anydata_list;
        len    INTEGER;
        cnt    INTEGER;
        outs   VARCHAR2(4096);
        ch     VARCHAR2(1);
    BEGIN
        cnt    := 1;
        outs   := output_values(call_handle);
        len    := LENGTH(outs);

        WHILE cnt <= len
        LOOP
            ch         := SUBSTR(outs, len, 1);
            res(cnt)   := get_any(ch);
            cnt        := cnt + 1;
        END LOOP;

        RETURN res;
    END get_output_values;

    FUNCTION get_any(ch VARCHAR2)
        RETURN ANYDATA
    IS
    BEGIN
        IF (ch = NULL)
        OR (ch = 'Z') THEN
            RETURN NULL;
        ELSIF ch = 'N' THEN
            RETURN anydata.convertnumber(get_number());
        ELSIF ch = 'C' THEN
            RETURN anydata.convertvarchar2(get_char());
        ELSIF ch = 'D' THEN
            RETURN anydata.convertdate(get_date());
        ELSIF ch = 'R' THEN
            RETURN anydata.convertraw(get_raw());
        ELSIF ch = 'B' THEN
            RETURN anydata.convertblob(get_blob());
        ELSIF ch = 'L' THEN
            RETURN anydata.convertclob(get_clob());
        ELSIF ch = 'F' THEN
            RETURN anydata.convertbfile(get_bfile());
        ELSIF ch = 'Y' THEN
            RETURN anydata.convertnumber(get_byte());
        ELSIF ch = 'S' THEN
            RETURN anydata.convertnumber(get_short());
        ELSIF ch = 'I' THEN
            RETURN anydata.convertnumber(get_integer());
        ELSIF ch = 'G' THEN
            RETURN anydata.convertnumber(get_long());
        ELSIF ch = 'O' THEN
            RETURN anydata.convertnumber(get_float());
        ELSIF ch = 'P' THEN
            RETURN anydata.convertnumber(get_double());
        /*
        elsif ch = 'O'
           then return ANYDATA.ConvertObject(get_object());
        elsif ch = '^'
           then return ANYDATA.ConvertRef(get_ref());
        elsif ch = '@'
           then return ANYDATA.ConvertCollection(get_collection());
        */
        END IF;

        RETURN NULL;                            -- Should throw an exception?!
    END get_any;

    PROCEDURE set_any(obj ANYDATA)
    IS
        nr     NUMBER;
        v2     VARCHAR2(32767);
        de     DATE;
        rw     RAW(32767);
        bb     BLOB;
        cb     CLOB;
        be     BFILE;
        cr     CHAR;
        vr     VARCHAR(32767);
        name   VARCHAR2(32767);
    BEGIN
        IF obj IS NULL THEN
            set_null;
        ELSE
            name   := obj.gettypename;

            IF name = 'SYS.NUMBER' THEN
                set_number(obj.accessnumber);
            ELSIF name = 'SYS.VARCHAR2' THEN
                set_char(obj.accessvarchar2);
            ELSIF name = 'SYS.DATE' THEN
                set_date(obj.accessdate);
            ELSIF name = 'SYS.RAW' THEN
                set_raw(obj.accessraw);
            ELSIF name = 'SYS.BLOB' THEN
                set_blob(obj.accessblob);
            ELSIF name = 'SYS.CLOB' THEN
                set_clob(obj.accessclob);
            ELSIF name = 'SYS.BFILE' THEN
                set_bfile(obj.accessbfile);
            ELSIF name = 'SYS.CHAR' THEN
                set_char(obj.accesschar);
            ELSIF name = 'SYS.VARCHAR' THEN
                set_char(obj.accessvarchar);
            ELSE
                set_null(name);
            /*
            elsif name = <OBJECT>
              then
            elsif name = <REF>
              then
            elsif name = <COLLECTION>
              then
            */
            END IF;
        END IF;
    END set_any;

    FUNCTION output_values(call_handle call)
        RETURN VARCHAR2
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.outputValues(long) return java.lang.String' ;

    -- Set the type of a parameter of a Call.
    --   callHandle - the instance of the call
    --   xml_name - the xml name of the parameter type
    --   q_name - the QNAME for the parameter type
    --   mode - the ParameterMode mode constant
    PROCEDURE ADD_PARAMETER(call_handle     call,
                            xml_name        VARCHAR2,
                            q_name          qname,
                            p_mode          VARCHAR2)
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.addParameter(long,java.lang.String, java.lang.String,java.lang.String)' ;

    -- Set the return type of a Call.
    --   callHandle - the instance of the call
    --   retType - the qname of the return type
    PROCEDURE set_return_type(call_handle call, ret_type qname)
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.setReturnType(long,java.lang.String)' ;

    --------------------
    -- Initialization --
    --------------------

    PROCEDURE set_call(call_handle call)
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.setCall(long)' ;

    -------------
    -- Setters --
    -------------

    PROCEDURE set_null
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.setNull()' ;

    PROCEDURE set_null(c VARCHAR2)
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.setNull(java.lang.String)' ;

    PROCEDURE set_char(c VARCHAR2)
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.setChar(java.lang.String)' ;

    PROCEDURE set_number(n NUMBER)
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.setBigDecimal(java.math.BigDecimal)' ;

    PROCEDURE set_raw(r RAW)
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.setRaw(byte[])' ;

    PROCEDURE set_date(d DATE)
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.setDate(oracle.sql.DATE)' ;

    PROCEDURE set_boolean(b NUMBER)
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.setBoolean(int)' ;

    PROCEDURE set_blob(b BLOB)
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.setBlob(oracle.sql.BLOB)' ;

    PROCEDURE set_clob(c CLOB)
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.setClob(oracle.sql.CLOB)' ;

    PROCEDURE set_bfile(b BFILE)
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.setBfile(oracle.sql.BFILE)' ;

    PROCEDURE set_rowid(r ROWID)
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.setRowid(oracle.sql.ROWID)' ;

    PROCEDURE set_timestamp(d TIMESTAMP)
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.setTimestamp(oracle.sql.TIMESTAMP)' ;

    PROCEDURE set_timestamp_tz(d TIMESTAMP WITH TIME ZONE)
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.setTimestampTZ(oracle.sql.TIMESTAMPTZ)' ;

    PROCEDURE set_timestamp_ltz(d TIMESTAMP WITH LOCAL TIME ZONE)
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.setTimestampLTZ(oracle.sql.TIMESTAMPLTZ)' ;

    PROCEDURE set_xmltype(x XMLTYPE)
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.setXmltype(oracle.sql.OPAQUE)' ;

    -------------
    -- Getters --
    -------------
    FUNCTION get_char
        RETURN VARCHAR2
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.getChar() return java.lang.String' ;

    FUNCTION get_number
        RETURN NUMBER
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.getBigDecimal() return java.math.BigDecimal' ;

    FUNCTION get_raw
        RETURN RAW
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.getRaw() return byte[]' ;

    FUNCTION get_date
        RETURN DATE
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.getDate() return oracle.sql.DATE' ;

    FUNCTION get_timestamp
        RETURN TIMESTAMP
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.getTimestamp() return oracle.sql.TIMESTAMP' ;

    FUNCTION get_timestamp_tz
        RETURN TIMESTAMP WITH TIME ZONE
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.getTimestampTZ() return oracle.sql.TIMESTAMPTZ' ;

    FUNCTION get_timestamp_ltz
        RETURN TIMESTAMP WITH LOCAL TIME ZONE
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.getTimestampLTZ() return oracle.sql.TIMESTAMPLTZ' ;

    FUNCTION get_boolean
        RETURN NUMBER
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.getBoolean() return int' ;

    FUNCTION get_byte
        RETURN NUMBER
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.getByte() return Byte' ;

    FUNCTION get_short
        RETURN NUMBER
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.getShort() return Short' ;

    FUNCTION get_integer
        RETURN NUMBER
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.getInteger() return Integer' ;

    FUNCTION get_long
        RETURN NUMBER
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.getLong() return Long' ;

    FUNCTION get_float
        RETURN NUMBER
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.getFloat() return Float' ;

    FUNCTION get_double
        RETURN NUMBER
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.getDouble() return Double' ;


    FUNCTION get_blob
        RETURN BLOB
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.getBlob() return oracle.sql.BLOB' ;

    FUNCTION get_clob
        RETURN CLOB
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.getClob() return oracle.sql.CLOB' ;

    FUNCTION get_bfile
        RETURN BFILE
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.getBfile() return oracle.sql.BFILE' ;

    FUNCTION get_rowid
        RETURN ROWID
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.getRowid() return oracle.sql.ROWID' ;

    FUNCTION get_xmltype
        RETURN XMLTYPE
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.getXmltype() return oracle.sql.OPAQUE' ;

    PROCEDURE set_logger_level(LEVEL VARCHAR2)
    AS
        LANGUAGE JAVA
        NAME 'oracle.jpub.runtime.dbws.DbwsProxy.setLoggerLevel(java.lang.String)' ;
END utl_dbws;
/


GRANT EXECUTE ON SITESPECIFIC.UTL_DBWS TO PUBLIC;
