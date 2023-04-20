CREATE OR REPLACE PACKAGE SITESPECIFIC.utl_dbws
AS
    -- **************************************************************************
    -- File:        UTL_DBWS.PKS
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

    -------------------------------------------
    -------------------------------------------
    ---                                     ---
    --- Handling of qualified names (QName) ---
    ---                                     ---
    -------------------------------------------
    -------------------------------------------


    SUBTYPE qname IS VARCHAR2(4096);

    TYPE qname_list IS TABLE OF qname
        INDEX BY BINARY_INTEGER;

    -- Construct a qualified name
    --   namespaceURI - Namespace URI for the QName, null if none.
    --      localPart - Local part of the QName
    FUNCTION to_qname(name_space VARCHAR2, name VARCHAR2)
        RETURN qname;

    -- Return the namespace URI of a qualified name, null if none.
    FUNCTION get_namespace_uri(name qname)
        RETURN VARCHAR2;

    -- Return the local part of a qualified name
    FUNCTION get_local_part(name qname)
        RETURN VARCHAR2;

    -- The following is a list of predefined namespaces that may be
    -- used in the name_Space parameter of to_QName
    -- 'NSURI_SCHEMA_XSD','xsd'        - Namespace URI for XML Schema XSD
    -- 'NSURI_SCHEMA_XSI','xsi'        - Namespace URI for XML Schema XSI
    -- 'NSURI_SOAP_ENCODING','soapenc' - Namespace URI for SOAP 1.1 Encoding
    -- 'NSURI_SOAP_ENVELOPE','soapenv' - Namespace URI for SOAP 1.1 Envelope
    -- 'NSURI_SOAP_NEXT_ACTOR'         - Namespace URI for SOAP 1.1 next actor role


    -------------------------------------------
    -------------------------------------------
    ---                                     ---
    --- Service instantiation based on WSDL ---
    ---                                     ---
    -------------------------------------------
    -------------------------------------------

    SUBTYPE service IS NUMBER;

    -- Create a Service instance.
    --   serviceName - QName for the service
    --   Returns a handle to the Service instance.
    FUNCTION create_service(service_name qname)
        RETURN service;

    -- Create a Service instance.
    --   wsdlDocumentLocation - URL for the WSDL document location for the service
    --   serviceName - QName for the service
    --   Returns a handle to the Service instance.
    FUNCTION create_service(wsdl_document_location URITYPE,
                            service_name    qname)
        RETURN service;

    -- List the qualified names of all of the ports in a service.
    --    service_Handle - Service instance whose ports are returned
    FUNCTION get_ports(service_handle service)
        RETURN qname_list;

    -- List the qualified names of all of the operations on a particular
    --    service port.
    --    service_Handle - Service instance whose operations are returned
    --    port           - Qualified name of a service port. NULL if the
    --                     first port of the service is to be used.
    FUNCTION get_operations(service_handle service, port qname)
        RETURN qname_list;

    -- Release a particular Service instance. This will implicitly
    -- release all Call instances that have been created for this
    -- service instance.
    --    service_Handle - Service instance that is to be released
    PROCEDURE release_service(service_handle service);

    -- Release all Service instances.
    PROCEDURE release_all_services;


    ---------------------------------------------
    ---------------------------------------------
    ---                                       ---
    --- Call instantiation based on a service ---
    ---     port and an operation name        ---
    ---                                       ---
    ---------------------------------------------
    ---------------------------------------------

    SUBTYPE call IS NUMBER;

    TYPE anydata_list IS TABLE OF ANYDATA
        INDEX BY BINARY_INTEGER;

    -- Set the proxy address
    --   proxy - the http proxy address, e.g., www-proxy.us.acme.com:80
    PROCEDURE set_http_proxy(httpproxy VARCHAR2);

    -- Create a Call instance.
    --   serviceHandle - the service instance that is to be called.
    FUNCTION create_call(service_handle service)
        RETURN call;

    -- Create a Call instance.
    --   serviceHandle - the service instance that is to be called.
    --   portName - qualified name for the port. Use first port if this is NULL.
    --   operationName - qualified name for the operation
    FUNCTION create_call(service_handle  service,
                         port_name       qname,
                         operation_name  qname)
        RETURN call;

    -- Release a particular Call instance.
    --    call_Handle - Call instance that is to be released
    PROCEDURE release_call(call_handle call);

    -- Set the value of a particular property on a Call.
    --   callHandle - the instance of the call
    --   endpoint   - the endpoint for the call
    PROCEDURE set_target_endpoint_address(call_handle     call,
                                          endpoint        VARCHAR2);


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
        RETURN VARCHAR2;

    -- Set the value of a particular property on a Call.
    --   callHandle - the instance of the call
    --   key        - the key for the property
    --   value      - the value for the property
    PROCEDURE set_property(call_handle call, key VARCHAR2, VALUE VARCHAR2);

    -- Clear the value of a particular property on a Call.
    --   callHandle - the instance of the call
    --   key        - the key for the property
    PROCEDURE remove_property(call_handle call, key VARCHAR2);

    -------------------------------------------------------------------
    -------------------------------------------------------------------
    -- The following list describes the supported XML types
    --
    -- XML Type                       SQL Type
    -------------------------------------------------------------------
    --
    -- xsd:string                     VARCHAR2
    -- soapenc:string
    --
    -- xsd:int, xsd:long, xsd:short,  NUMBER (no NULL permitted)
    -- xsd:float, xsd:double,         and related SQL types
    -- xsd:boolean
    -- soapenc:boolean, soapenc:float,
    -- soapenc:double, soapenc:int,
    -- soapenc:short, soapenc:byte,
    --
    -- xsd:integer, xsd:decimal,      NUMBER (NULL permitted)
    -- soapenc:decimal                and related SQL types
    --
    -- xsd:QName                      VARCHAR2
    --
    -- xsd:dateTime                   DATE, TIMESTAMP,
    --                                TIMESTAMP WITH TIMEZONE
    --                                TIMESTAMP WITH LOCAL TIMEZONE
    --
    -- xsd:base64Binary,              RAW
    -- xsd:hexBinary,
    -- soapenc:base64
    --
    -------------------------------------------------------------------
    -------------------------------------------------------------------

    -- List the XML type that is returned by the given call.
    --    call_Handle - Service instance whose return type is returned.
    FUNCTION get_return_type(call_handle call)
        RETURN qname;

    -- List the XML type of the input parameters of the given call.
    --    call_Handle - Service instance whose input types are returned.
    FUNCTION get_in_parameter_types(call_handle call)
        RETURN qname_list;

    -- List the XML type of the output parameters of the given call.
    --    call_Handle - Service instance whose output types are returned.
    FUNCTION get_out_parameter_types(call_handle call)
        RETURN qname_list;

    -- Invokes a document style operation using a synchronous
    -- request-response- interaction mode.
    --   callHandle - the instance of the call
    --   request - the request for this invocation.
    --   Returns the response or null.
    FUNCTION invoke(call_handle call, request SYS.XMLTYPE)
        RETURN SYS.XMLTYPE;

    -- Invokes a specific operation using a synchronous request-response
    -- interaction mode.
    --   callHandle - the instance of the call
    --   inputParams - The input parameters for this invocation.
    --   Returns the return value or null.
    FUNCTION invoke(call_handle call, input_params anydata_list)
        RETURN ANYDATA;

    -- Obtain the output arguments after a call invocation
    --   callHandle - the instance of the call
    --   Returns the output arguments in order.
    FUNCTION get_output_values(call_handle call)
        RETURN anydata_list;

    -- Set the type of a parameter of a Call.
    --   callHandle - the instance of the call
    --   xml_name - the xml name of the parameter type
    --   q_name - the QNAME for the parameter type
    --   mode - the ParameterMode mode constant
    PROCEDURE ADD_PARAMETER(call_handle     call,
                            xml_name        VARCHAR2,
                            q_name          qname,
                            p_mode          VARCHAR2);

    -- Set the return type of a Call.
    --   callHandle - the instance of the call
    --   retType - the qname of the return type
    PROCEDURE set_return_type(call_handle call, ret_type qname);

    -- set webservices client trace log level
    PROCEDURE set_logger_level(LEVEL VARCHAR2);
END utl_dbws;
/


GRANT EXECUTE ON SITESPECIFIC.UTL_DBWS TO PUBLIC;
