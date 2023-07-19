//*******************************************************************************************
//  File:			SiteNavigation.js         
//  Author:			Timothy J. Lord
//  
//  Description:	Contains javascript methods for controling navigation menus 
//  
//	Methods:		DisplayNavigation()
//
//  $Rev: 51 $   $Date: 2018-09-01 12:02:56 -0700 (Sat, 01 Sep 2018) $
//  Modified By: $Author: TLord $
//
//*******************************************************************************************
//  History:
//     Date  Developer  
//----------------------------------------------------------------------------------
//  01/14/2015  TJL      Ticket 6197
//*******************************************************************************************

$(document).ready(function ()
{
	// display navigation menus
	DisplayNavigation(true);
});

function DisplayNavigation(show)
{
	var userRoll;

	if (show)
	{
		// show navigation left panel
		jQuery('#page-left').show();
		jQuery('#page-right').css('width', '80%');

		// check if admin menus should be displayed
		if (g_user.USER_ROLE_IND != 'U')
		{
			jQuery('#admin-options').show();
		}
	}
	else
	{
		// hide navigation left panel
		jQuery('#page-left').hide();
		jQuery('#page-right').css('width', '100%');

	}
}

