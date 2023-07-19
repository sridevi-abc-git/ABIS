


var m_btnClose = {
	0: {
		value: 'OK',
		onclick: "_modal.close();_modal=undefined;$('div', '#msg-target-data').remove();  DisplayUserSearch(true)"
	}
};

var m_btnUpdate = {
	0: {
		value: 'OK',
		onclick: "_modal.close();_modal=undefined;$('div', '#msg-target-data').remove(); accept('user-information');"
	}
};


var m_ProcEnum = { 'Defs': 0, 'UserList': 1, 'RetrieveReportList': 2 };
var m_proc;
var m_results;
var m_selected_inx;

$(document).ready(function ()
{
	var request = {};

	if (g_user.ISDISTRICT == 'Y')
	{
		request['request'] = 'RQS;Reports.Report;Defs';
		request['data'] = JSON.stringify(g_user);

		jQuery('#start_date', '#select-div').val(getDateDaysBack(7));
		jQuery('#end_date', '#select-div').val(getDate());

		// get list of report definitions for selected user
		m_proc = m_ProcEnum.Defs;
		newMsg('Please Wait: Retrieving Office Information', false, null);
		wcfPost(g_webUser, request);
	}

	jQuery("[id$='connection']", "user-maintenance").val(g_user.CONNECTION);
	jQuery("[id$='user_role']", "user-maintenance").val(g_user.USER_ROLE);
	jQuery("[id$='office_id']").val(g_user.OFFICE_ID);

	jQuery("[name=user_name]", "#user-search").focus();
});

function GetUser()
{
	var request = {};
	var select;

	request['request'] = 'Search'
	getValues('user-maintenance', request);
	m_proc = m_ProcEnum.UserList;

	newMsg('Please Wait: Looking up user information', false, null);
	wcfPost(g_webUser, request);

	return false;
}

function UserReports(inx)
{
	var values = {};
	var request = {};
	var item = m_results[inx];
	
	m_selected_inx = inx; // save index to selected user

	jQuery("#t_name", "#user-information").text(item.USER_NAME); 
	jQuery("#t_user_id", "#user-information").text(item.ORACLELOGONID);
	jQuery("#t_email_address", "#user-information").text(item.EMAILADDRESS);
	jQuery("#t_office", "#user-information").text(item.OFFICE_NAME);
	jQuery("#t_user_role", "#user-information").val((item.USER_ROLE_IND.length == 0)? 'U' : item.USER_ROLE_IND);

	jQuery("[name='add-update']", "#user-information")
			.attr('value', (item.USER_ROLE_IND.length == 0 ? 'Add' : 'Update'));

	(item.USER_ROLE_IND.length == 0)?
		jQuery("[name='delete']", "#user-information").hide() :
		jQuery("[name='delete']", "#user-information").show();

	if (g_user.USER_ROLE_IND == 'I') jQuery('#tr_user_role', "#user-information").show();

	DisplayUserInfo(true);

	values['USEROBJECTID'] = item.USERID;
	values['CONNECTION'] = g_user.CONNECTION;
	values['SITE'] = window.location.host.toLowerCase();

	request['request'] = 'AvailableReports'
	request['data'] = JSON.stringify(values);

	m_proc = m_ProcEnum.RetrieveReportList;

	newMsg('Please Wait: Retrieving User Reports', false, null);
	wcfPost(g_webUser, request);

}

function UserUpdate(btn)
{
	var items = {};
	var values = {};
	var request = {};
	var role;
	var xml;
	var userId = m_results[m_selected_inx].USERID;
	var userRole = jQuery("#t_user_role", "#user-information")[0];
	var isChanged = false;

	if (btn.name == 'add-update')
	{
		// check if user role is not empty
		if (userRole.value.length == 0) return alert('Please select a user role.')
		$(userRole).find('option').each(function ()
		{
			isChanged = (this.selected == this.defaultSelected ? isChanged : true);
		});

		if (!isDirty('user-information', items) && !isChanged) return alert('No changes found to update.');
	}
	else
	{
		jQuery(userRole).val('');
	}

	items = jQuery(':checkbox', "#user-information");

	values['CONNECTION'] = g_user.CONNECTION;
	values['USEROBJECTID'] = userId;
	values['USER_ROLE'] = userRole.value;

	xml = '<REPORTS>';
	for (var inx = 0; inx < items.length; inx++)
	{
		// check if changed
		if (items[inx].checked == items[inx].defaultChecked) continue;

		xml += '<REPORT>';
		xml += '<REPORT_NUMBER>' + items[inx].name.substring(1) + '</REPORT_NUMBER>'
		xml += '<USEROBJECTID>' + userId + '</USEROBJECTID>';
		xml += '<DELETE_RPT>' + (items[inx].checked ? 'N' : 'Y') + '</DELETE_RPT>';
		xml += "</REPORT>";
	}
	xml += '</REPORTS>';

	values['REPORTS'] = xml;

	// call web service to update user
	request['request'] = 'Update'
	request['data'] = JSON.stringify(values);

	g_messageBoxButton = (userRole.value.length == 0)? m_btnClose : m_btnUpdate;

	newMsg('Please Wait: ' + (btn.value == "Add" ? "Adding " : "Updating ") + 'User', false, null);
	wcfPost(g_webUser, request);


}


function Process(data)
{

	switch (m_proc)
	{
		case m_ProcEnum.Defs:
			if (data.err == null)
			{
				initOfficSelection(data);
			}
			else
			{
				m_removeMessage = newMsg(data.err, false, g_messageBoxErrorButton);
			}
			break;

		case m_ProcEnum.UserList:
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

					CreateElement('td', this.USER_ROLE_IND, row);
					CreateElement('td', this.USER_NAME, row);
					CreateElement('td', this.OFFICE_NAME, row);
					CreateElement('td', this.EMAILADDRESS, row);

					row.attr('onclick', "UserReports('" + inx + "');");
					row.appendTo(root);
				}
			});

			if ((m_results.length == 1) && (m_results[0].USERID != g_user.USERID))
			{
				jQuery("[name='user-list']", "#user-information").hide();
				
				// this process must complete before requset for reports can
				setTimeout(function () { UserReports(0) }, 10);
			}
			else
			{
				if (m_results.length > 1)
				{
					jQuery("[name='user-list']", "#user-information").show();
					DisplayUserList(true);
				}
				else
				{
					alert('No users found');
				}
			}

			break;

		case m_ProcEnum.RetrieveReportList:
			var info = jQuery.parseJSON(data);
			var root = jQuery('#report-list');
			var row;
			var cell;
			var checkbox;

			// clear old list information
			root.html('');

			$.each(info, function (inx)
			{

				row = jQuery(document.createElement('tr'));

				CreateElement('td', this.REPORT_NAME, row);
				cell = CreateElement('td', null, row);

				checkbox = jQuery(document.createElement('input'));
				checkbox.attr('type', 'checkbox');
				checkbox.attr('name', 'R' + this.REPORT_NUMBER);
				jQuery(checkbox).hide();

				if (this.ACCESS == 'Y')
				{
					checkbox.attr('checked', 'checked');
					CreateElement('div', 'Enabled', cell);
				}
				else
				{
					CreateElement('div', '', cell);
				}
				checkbox.appendTo(cell);

				row.click(function ()
				{
					var item = $(this).find('input')[0];
					var text = $(this).find('div')[0];

					if (item.checked)
					{
						item.checked = false;
						text.innerText = '';
					}
					else
					{
						item.checked = true;
						text.innerText = 'Enabled';
					}
				}); 
				
				row.appendTo(root);
			});
			accept('user-information');

			break;
	}
}

	function CreateElement(element, value, parent)
	{
		var cell;

		cell = jQuery(document.createElement(element));
		cell.html(value);
		cell.appendTo(parent);

		return cell;
	}

	function DisplayUserSearch(show)
	{
		if (show)
		{
			DisplayUserList(false);
			DisplayUserInfo(false);

			//DisplayNavigation(true);
			jQuery('#user-search').show();
			jQuery('#info').hide();
		}
		else
		{
			jQuery('#user-search').hide();
		}
	}

	function DisplayUserList(show)
	{
		if (show)
		{
			DisplayUserSearch(false);
			DisplayUserInfo(false);
			//DisplayNavigation(false);

			jQuery('#user-list').show()
		}
		else
		{
			jQuery('#user-list').hide();
		}
	}

	function DisplayUserInfo(show)
	{
		if (show)
		{
			DisplayUserSearch(false);
			DisplayUserList(false);
			//DisplayNavigation(false);

			jQuery('#user-information').show();
		}
		else
		{
			jQuery('#user-information').hide();
		}
	}




