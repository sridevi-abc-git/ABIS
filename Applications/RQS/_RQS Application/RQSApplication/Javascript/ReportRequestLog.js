//*****************************************************************************
//    File:         ReportRequestLog.js         
//    Author:       Timothy J. Lord
//    
//    Description:  
//    		 
//    $Rev: 51 $   $Date: 2018-09-01 12:02:56 -0700 (Sat, 01 Sep 2018) $
//    Modified By: $Author: TLord $
//*****************************************************************************
//  History:
//     Date  Developer  Ticket		Comment
//-----------------------------------------------------------------------------
//  06/16/2015  TJL      7454	  Initial file created
//*****************************************************************************
var m_proc;
var m_ProcEnum = { 'LogList': 0 };

$(document).ready(function ()
{
	jQuery('#start_date', '#user-search').val(getDateDaysBack(7));
	jQuery('#end_date', '#user-search').val(getDate());

	// setup input validators
	jQuery('#start_date', '#select-div').validation('add', {
		validator: VAL_DATEPATTERNSTANDARD, required: false, message: {
			INVALID: 'Invalid date entered.'
		}
	});

	jQuery('#end_date', '#select-div').validation('add', {
		validator: VAL_DATEPATTERNSTANDARD, required: false, message: {
			INVALID: 'Invalid date entered.'
		}
	});

});


function GetLogs()
{
	var request = {};
	var select;

	request['request'] = 'RQS;Reports.User;RequestLogs'
	isDirty('user-log', request);
	m_proc = m_ProcEnum.LogList;

	newMsg('Please Wait: Looking up user(s) request logs', false, null);
	wcfPost(g_webService, request);

	return false;
}


function Process(data)
{

	switch (m_proc)
	{
		case m_ProcEnum.LogList:
			var root = jQuery('#tbody_results');
			var row;

			// clear old list information
			root.html('');
			m_results = jQuery.parseJSON(data);

			$.each(m_results, function (inx)
			{
				if (this.USERID != g_user.USERID)
				{
					row = jQuery(document.createElement('tr'));

					CreateElement('td', this.RETRIEVED_BY, row);
					CreateElement('td', this.RPT_DESC, row);
					CreateElement('td', this.REQUESTED_DATE, row);
					CreateElement('td', this.REQUEST_ID, row);
					CreateElement('td', this.RPT_ID, row);
					CreateElement('td', this.ORDERED_BY, row);

					row.appendTo(root);
				}
			});

				if (m_results.length > 0)
				{
					DisplayUserSearch(false);
				}
				else
				{
					alert('No users logs found');
				}

			break;
	}
}

function DisplayUserSearch(show)
{
	if (show)
	{
		jQuery('#user-search').show();
		jQuery('#user-log-results').hide();
	}
	else
	{
		jQuery('#user-search').hide();
		jQuery('#user-log-results').show();
	}
}



