<%--
*******************************************************************************************
//    File:         Default.aspx         
//    Author:       Timothy J. Lord
//    
//    Description:  
//    		 
//    $Rev: 398 $   $Date: 2020-01-23 07:11:17 -0800 (Thu, 23 Jan 2020) $
//    Modified By: $Author: TLord $
//*******************************************************************************************
//  History:
//     Date  Developer  
//----------------------------------------------------------------------------------
//  005/04/2015  TJL      Ticket 7203 - cleaning up display
//*******************************************************************************************	 
--%>

<%@ Page Title="" Language="C#" MasterPageFile="~/Screens/Site.Master" AutoEventWireup="true" CodeBehind="Default.aspx.cs" 
         Inherits="RQS.Default" %>

<%@ MasterType VirtualPath="~/Screens/Site.Master" %>

<asp:Content ID="Content1" ContentPlaceHolderID="head" runat="server">
    <script type="text/javascript" src="Javascript/validator.js"></script>
    <script type="text/javascript">

        var m_btn = {
            0: {
                value: 'OK',
                onclick: "_modal.close();_modal=undefined;$('div', '#msg-target-data').remove();jQuery(\"[id$='user']\").focus().select();"
            }
        };


        $(document).ready(function () {
            var dsp      = true;
            var response = jQuery("[id$='hdnResults']").val();

            if (response.length > 0)
            {
                var data = jQuery.parseJSON(response);
                if (typeof data === 'object') {
                    $.each(data, function (key, value) {
                        switch (key.toLowerCase()) {
                            case "url":
                                window.location.assign(value);
                                break;

                            case "err":
                                m_removeMessage = newMsg(value, true, g_messageBoxErrorButton);
                                break;

                            case "msg":
                                m_removeMessage = newMsg(value, false, g_messageBoxButton);
                                break;

                            case "db":
                                dsp = true;
                                break;
                            case "data":
                            default:
                                window.location = '/Screens/Home.aspx?' + encode(getDateTime() + '|' + encode(value));
                                break;
                        }
                    });
                }

            }

            //if (dsp)
            {
                jQuery("[id$='select-div']").show();
        	    jQuery("[id$='user']").focus();
        	    jQuery("[name='tnsname']").val(jQuery("[id$='hdnTnsname']").val());


        	    jQuery("[id$='user']").validation('add', {
        		    required: true, message: {
        			    REQUIRED: 'You must enter your user id.'
        		    }
        	    });
            }
        });


        function ValidateUser() {
            var values = {};

            values['request'] = 'UserInfo'

            // make sure user id and password are entered
            if ((jQuery("[id$='user']")[0].value.length == 0) && (jQuery("[id$='password']")[0].value.length == 0)) {
                alert('You must enter user id and password.');
                jQuery("[id$='user']").focus();
                return false;
            }

            if (jQuery("[id$='user']")[0].value.length == 0) {
                alert('You must enter your user id.');
                jQuery("[id$='user']").focus();
                return false;
            }

            if (jQuery("[id$='password']")[0].value.length == 0) {
                alert('You must enter your password.');
                jQuery("[id$='password']").focus();
                return false;
            }

            getValues("select-div", values);

            newMsg('Please Wait: Validating User Id and Password', false, null);
            g_messageBoxButton = m_btn;
            wcfPost(g_webUser, values);
            return false;
        }

        function Process(response) {
            //var userInfo;
            //var userData;

            //userInfo = jQuery.parseJSON(response);
            //userData = encode(JSON.stringify(userInfo));

            // go home screen
            window.location = '/Screens/Home.aspx?' + encode(getDateTime() + '|' + encode(response));
        }
	</script>
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
        <asp:Label runat="server" ID="lbinfo" />
    
    <div id="select-div" style="width:500px; padding:0; margin:20px auto;" hidden="hidden">
        <asp:HiddenField ID="hdnResults" runat="server" ViewStateMode="Disabled" />
		<input type="hidden" name="tnsname" class="return" />
		<fieldset class="shadow" style="margin:0; padding:0;">
			<header>
				Log In
			</header>
			<div class="line" style="margin-top:20px; ">
				<div class="left-col" >
					ABIS User Id:
				</div>
				<div class="right-col">
					<input type="text" name="user" id="user" size="20" />
				</div>
			</div>
			<div class="line">
				<div class="left-col" >
					Password:
				</div>
				<div class="right-col">
					<input type="password" name="password" id="password" size="21" />
				</div>
			</div>
			<div style="text-align:center;padding:20px 0;">
				<input type="submit" name="btnSelect" value="Continue" 
						onclick="return ValidateUser();" />
			</div>
		</fieldset>
	</div>
</asp:Content>
