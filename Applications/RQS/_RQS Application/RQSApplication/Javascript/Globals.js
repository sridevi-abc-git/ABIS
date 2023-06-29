//*****************************************************************************
//  File:           Globals.js
//  Author:         Timothy J. Lord
//
//  Date:           06/26/2014
//
//  Description:    Globals.js file contains all the global variables used in
//                  Report Query System Web Application.  All global variables
//                  will be prefixed with g_
//      
//*****************************************************************************
//    $Rev: 51 $   $Date: 2018-09-01 12:02:56 -0700 (Sat, 01 Sep 2018) $
//    $Author: TLord $
//*****************************************************************************
var m_defaultButton = {
    0: {
        value: 'OK',
        onclick: "_modal.close();_modal=undefined;$('div', '#msg-target-data').remove();"
    }
};

var g_webService;
var g_webUser;
var g_user;
var g_messageBoxButton = m_defaultButton;
var g_messageBoxErrorButton = m_defaultButton;
var g_reportRecords = {};
var g_outputRecords = {};
var g_officeRecords = {};
