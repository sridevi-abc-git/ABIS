

var m_btnClose = {
    0: {
        value: 'OK',
        onclick: "_modal.close();_modal=undefined;$('div', '#msg-target-data').remove();  DisplayReportFilter(true)"
    }
};

var m_btnErr = {
    0: {
        value: 'OK',
        onclick: "_modal.close();_modal=undefined;$('div', '#msg-target-data').remove(); DisplayReportFilter(true);"
    }
};

var m_ProcEnum = { 'Defs': 0, 'StatusCheck': 1, 'ProcessStatusCheck': 2, 'ProcessReportData' : 3 };
var m_timeoutId;
var m_disableTimeout = false;
var m_cnt;
var m_current_request_id;
var m_proc;
var m_infodata;
var m_val;

var m_reportControlParameters;
var m_inputFields;

$(document).ready(function () {
    var request = {};

    request['request'] = 'GetControlParameter';
    request['data'] = JSON.stringify(g_user);

    // get list of report definitions for selected user
    m_proc = m_ProcEnum.Defs;
    newMsg('Please Wait: Retrieving Reports Definitions for User', false, null);
    wcfPost(g_webService, request);

    jQuery('[name="officeobjectid"]', '#input-area').validation('add', {
            required: true, message: {
            REQUIRED: 'Please select an Office.'
        }
    });

    jQuery('#report_date', '#input-area').validation('add', {
        validator: VAL_DATEPATTERNSTANDARD, required: true, message: {
            REQUIRED: 'Please enter valid end date.',
            INVALID: 'Invalid date entered.'
        }
    });

    jQuery('#year', '#input-area').validation('add', {
        validator: VAL_YEAR, required: true, message: {
            REQUIRED: 'Please enter report year.',
            INVALID: 'Please enter a valid report year.'
        }
    });

    jQuery('#start_date', '#input-area').validation('add', {
        validator: VAL_DATEPATTERNSTANDARD, required: true, message: {
            REQUIRED: 'Please enter valid start date.',
            INVALID: 'Invalid date entered.'
        }
    });

    jQuery('#end_date', '#input-area').validation('add', {
        validator: VAL_DATEPATTERNSTANDARD, required: true, message: {
            REQUIRED: 'Please enter valid end date.',
            INVALID: 'Invalid date entered.'
        }
    });

    jQuery('#schedule_date', '#input-area').validation('add', {
        validator: VAL_DATEPATTERNSTANDARD, required: true, message: {
            REQUIRED: 'Please enter valid date.',
            INVALID: 'Invalid date entered.'
        }
    });

    jQuery('#schedule_time', '#input-area').validation('add', {
        validator: VAL_TIME24, required: true, message: {
            REQUIRED: 'Please enter valid Military time.',
            INVALID: 'Invalid Military time entered.'
        }
    });

    jQuery('#email_to', '#input-area').validation('add', {
        validator: VAL_EMAIL_SHORT, required: true, message: {
            REQUIRED: 'Please enter valid email address.',
            INVALID: 'Invalid email address entered.'
        }
    });
});

function uncheck(name)
{
	jQuery("[name='" + name + "']", '#input-section').prop('checked', false);
}

function Process(data)
{
    switch (m_proc)
    {
        case m_ProcEnum.Defs:
        	var reportCnt;

        	m_reportControlParameters = jQuery.parseJSON(data);

        	reportCnt = initReportSelection(m_reportControlParameters)
        	initOfficSelection(m_reportControlParameters);
        	initCountySelection(m_reportControlParameters);

			// initialize input area if only one report is available
        	if (reportCnt == 1)
        	{
        		initInput(m_reportControlParameters);
        	}
        	else
        	{
        		jQuery("[name='report_number']", '#input-area').parent().parent().show();
        	}
            break;

        case m_ProcEnum.StatusCheck:
            StatusCheck(data);
            break;

    	case m_ProcEnum.ProcessStatusCheck:
    		if (m_disableTimeout) break;
    		DisplayWaitArea(true);
    		if (processStatus(data))
    		{
    			// all reports completed for jobid
    			jQuery("[name='btnCancel']", '#wait-div').hide();
    			jQuery("[name='btnClosed']", '#wait-div').show();
    		}
    		else
    		{
    			// set timer for next status check
    			m_timeoutId = setTimeout(function () { StatusCheck(m_current_request_id) }, 1000);
    			if (m_cnt == 1)
    			{
    				jQuery('#request-id').text('Processing job id - ' + m_current_request_id + '');

    				jQuery("[name='btnCancel']", '#wait-div').show();
    				jQuery("[name='btnClosed']", '#wait-div').hide();

    				// setup cancel button
    				jQuery("[name='btnCancel']").unbind("click");
    				jQuery("[name='btnCancel']").bind("click", function ()
    				{
    					var select = document.getElementById('ddlReports');
    					StatusUpdate(m_current_request_id);
    				});
				}
    		}

            break;

        case m_ProcEnum.ProcessReportData:
        	var info = jQuery.parseJSON(data);

        	m_removeMessage = true;

        	switch (info.output_type.toLowerCase())
        	{
        		case "html-print":
        			// display print preview button
        			m_infodata = info.file.substring(0);
        			document.getElementById("print-preview-btn").style.display = 'inline-block';

        		case "html":
        			DisplayHTML(info.file);
        			break;

        		case "excel":
        			DisplayExcel(info.file);
        			break;

        		case "pdf":
        			DisplayPDF(info.file);
        			break;

        		default:
        			DisplayReportFilter(true);
        			break;
        	}
            break;
    }

}

function RequestReport(seq)
{
	var values = {};
	var request = {};
	var x = this;

	values['SEQ'] = seq;
	values['CONNECTION'] = g_user.CONNECTION;
	//values['SITE'] = window.location.host.toLowerCase();

	request['request'] = 'RetrieveReport'
	request['data'] = JSON.stringify(values);

	m_proc = m_ProcEnum.ProcessReportData;

	newMsg('Please Wait: Retrieving Report', false, null);
	wcfPost(g_webService, request);
}


//"[{\"SEQ\":\"22\",\"OFFICENAME\":\"SACRAMENTO\",\"STEP_IND\":\"Q\",\"ORA_STATUS\":\"\",\"WEB_STATUS\":\"\",\"RETRY_CNT\":\"0\"},
//  {\"SEQ\":\"23\",\"OFFICENAME\":\"SACRAMENTO\",\"STEP_IND\":\"Q\",\"ORA_STATUS\":\"\",\"WEB_STATUS\":\"\",\"RETRY_CNT\":\"0\"}]"
function processStatus(data)
{
	var statusData;
	var finishedCnt = 0;
	var stepInd;
	var tbl;
	var section;
	var row;
	var column;
	var value;

	if (data.length == 0) return false;

	statusData = jQuery.parseJSON(data);

	tbl = jQuery(document.createElement('table'));

	column = jQuery(document.createElement('caption'))
	column.text(jQuery("[name='report_number'] option:selected", '#input-area').text());
	column.appendTo(tbl);

	section = jQuery(document.createElement('thead'));
	section.appendTo(tbl);
	row = jQuery(document.createElement('tr'));
	row.appendTo(section);

	column = jQuery(document.createElement('th'));
	column.appendTo(row);

	column = jQuery(document.createElement('th'))
	column.text('Id');
	column.appendTo(row);

	column = jQuery(document.createElement('th'));
	column.text('Office');
	column.appendTo(row);

	column = jQuery(document.createElement('th'));
	column.text('Status');
	column.appendTo(row);

	section = jQuery(document.createElement('tbody'));
	section.appendTo(tbl);

	for (var inx = 0; inx < statusData.length; inx++)
	{
		stepInd = statusData[inx].STEP_IND;
		if ((stepInd == 'C') || (stepInd == 'E')) finishedCnt++;

		switch (stepInd)
		{
			case 'C': value = 'Report Completed'; break;
			case 'E': value = 'Error: Report not generated'; break;
			case 'Q': value = 'Report Waiting to process'; break;
			case 'P': value = 'Report being processed'; break;
			case 'W': value = 'Report being formated'; break;
			case 'F': value = 'Report being copied to remote server'; break;
			case 'S': value = 'Email notification being sent'; break;
			case 'R': value = 'Report Queued for reprocessing'; break;
			case 'X': value = 'Report was canceled'; break;
			default: value = 'Uknown Status'; break;
		}

		// format record display
		row = jQuery(document.createElement('tr'));
		row.attr('style', 'border:1px solid black;');
		row.appendTo(section)

		column = jQuery(document.createElement('td'));
//		column.attr('class', 'status-column');
		column.text(stepInd)
		column.appendTo(row);

		column = jQuery(document.createElement('td'));
		column.text(statusData[inx].SEQ);
		column.css({'text-align':'right','padding-right':'20px'});
		column.appendTo(row);

		column = jQuery(document.createElement('td'));
		column.text(statusData[inx].OFFICENAME);
//		column.attr('class', 'status-column');
		column.appendTo(row);

		column = jQuery(document.createElement('td'));
		column.text(value);
//		column.attr('class', 'status-column');
		column.appendTo(row);

		switch (stepInd)
		{
			case 'C': row.attr('class', 'completed');	break;
			case 'E': row.attr('class', 'err');			break;
			case 'Q': row.attr('class', 'wait');		break;
			default:  row.attr('class', 'processing');	break;
		}
	}

	if (finishedCnt == statusData.length)
	{
		tbl.find('tbody tr').each(function (i, el)
		{
			var statusInd = jQuery(this).find('td:nth-child(1)').text();
			var seq = jQuery(this).find('td:nth-child(2)').text();

			if (statusInd == 'C')
			{
				jQuery(this).attr('onclick', "RequestReport('" + seq + "');");
				jQuery(this).css('cursor', 'pointer');

				if (finishedCnt == 1)
				{
					// get report when only one is being request
					RequestReport(seq)
					m_removeMessage = false;

				}

			}
		});
	}

	jQuery('#request-msg', '#wait-div').html(tbl);
	return (finishedCnt == statusData.length);
}


//jQuery.parseJSON(data).REPORTS[13].REPORT_NUMBER
function initReportSelection(data)
{
	var recs = data.REPORTS;
	var select = jQuery("[name='report_number']", '#input-area');
	var option;
	var outParams;

	jQuery(select).empty();		// clear any items in drop down box

	// create first option to be displayed
	option = document.createElement("option");
	option.text = 'Select Report ...';
	option.value = '';
	select[0].appendChild(option);

	for (var inx = 0; inx < recs.length; inx++)
	{
		// create option for each record
		option = document.createElement("option");
		option.text = recs[inx].REPORT_NAME;
		option.value = recs[inx].REPORT_NUMBER;

		if (recs.length == 1)
		{
			// select report as selected report
			option.selected = true;

			// hide drop down
			select.parent().parent().hide();
		}

		select[0].appendChild(option);

	}

	return recs.length;
}

function initCountySelection(data) {
    var recs = data.COUNTIES;
    var select = jQuery("[name='counties']", '#input-area');
    var option;
    var outParams;

    jQuery(select).empty();		// clear any items in drop down box

    // create first option to be displayed
    option = document.createElement("option");
    option.text = 'Select County ...';
    option.value = '';
    select[0].appendChild(option);

    for (var inx = 0; inx < recs.length; inx++) {
        // create option for each record
        option = document.createElement("option");
        option.text = recs[inx].COUNTYNAME;
        option.value = recs[inx].COUNTYCODE;

        //if (recs.length == 1) {
        //    // select report as selected report
        //    option.selected = true;

        //    // hide drop down
        //    select.parent().parent().hide();
        //}

        select[0].appendChild(option);

    }

    return recs.length;
}




function initInput(data)
{
	var recs			= data.REPORTS;
	var select			= jQuery("[name='report_number']   option:selected", '#input-area');
	var name;
	var reportNumber	= select.val();
	var reportTypesCnt	= 0;
	var item;
	var section;
	var officeobjectid = jQuery("[name='officeobjectid']", '#input-area');
	var reportname	   = jQuery("[id$='report-name']", '#input-area');

	if (officeobjectid[0].length > 2) officeobjectid.val('');
	reportname.text(select.text());

	// hide all input field in selected area
	jQuery('.no-display', '#input-section').hide();
	jQuery("[id$='officeobjectid_err']", '#input-area').hide();
	officeobjectid.css({ 'color': '', 'background-color': '' });

	jQuery("[type='checkbox']", '#input-section').prop('checked', false);
	jQuery("[name='report_wait']", '#input-section').prop('checked', true);
	jQuery("[name='report_date']", '#input-area').val('');
	jQuery("[name='start_date']", '#input-area').val('');

	for (var inx = 0; inx < recs.length; inx++)
	{
		if (recs[inx].REPORT_NUMBER != reportNumber) continue;

		m_inputFields = recs[inx].INPUT_FIELDS;

		jQuery("[name='email_filename']", '#input-area').val(recs[inx].REPORT_NAME);
		if (recs[inx].BY_OFFICE_FLG == 'Y')
		{
			if (officeobjectid[0].length > 2) officeobjectid.parent().parent().show();
		}
		else
		{
			jQuery("[name='officeobjectid']", '#input-area').val(g_user.OFFICEOBJECTID);
		}

		for (name in recs[inx].INPUT_FIELDS)
		{
			switch (name)
			{
				case 'REPORT_TYPES':
					section = jQuery("#report-output-type", '#input-area');
					section.text("");

					jQuery.each(recs[inx].INPUT_FIELDS[name].split(','), function (index, value)
					{
						var input;

						item = jQuery(document.createElement('div'));

						input = jQuery(document.createElement('input'));
						input.attr('type', 'radio');
						input.attr('value', value);
						input.attr('name', 'output_type');
						if (index == 0) input.attr('checked', 'checked');

						input.appendTo(item);
						item.append(value);
						item.appendTo(section);
						reportTypesCnt++;
					});

					if (reportTypesCnt > 1)
					{
						section.parent().show();
					}
					break;

				default:
					jQuery("[id$='" + name.toLowerCase() + "_err']", '#input-area').hide();
					item = jQuery("[name='" + name.toLowerCase() + "']", '#input-area');
					if (item.length > 0)
					{
						item.val(recs[inx].INPUT_FIELDS[name])
						item.css({ 'color': '', 'background-color': '' });
						item.parent().parent().show();
					}
				break;


			}
		}

		// setup up other defaults for input page
		jQuery("[name='schedule_date']", '#input-area').val(getDate());
		jQuery("[name='schedule_time']", '#input-area').val(getTime());
		jQuery("[name='email_to']", '#input-area').val(g_user.EMAIL_TO);

		jQuery("#input-section").show();
		break;
	}



	return true;
}

function schedule_onclick(ctrl) {
    var item = jQuery('#schedule-div');

    if (ctrl.checked)
    {
        var addr = g_user.EMAIL_ADDRESS;
        if (addr.length > 0) addr = addr.substring(0, addr.indexOf('@'));

        // setup default values for schedule 
        jQuery("[name='schedule_date']", '#input-area').val(getDate());
        jQuery("[name='schedule_time']", '#input-area').val(getTime());
        jQuery('#email_address').val(addr);

        item.show();
        jQuery('#schedule_date').focus().select();
    }
    else
    {
    	jQuery("[name='schedule_date']", '#input-area').val('');
        jQuery("[name='schedule_time']", '#input-area').val('');
        jQuery('#email_address').val('');
        item.hide();
    }
}


function SubmitRequest() {
    var item = {};
    var select;
    var webRequest;

    m_current_request_id = null;
    if (getValues('input-area', item))
    {
    	if (ValInput())
    		//    {
    		//    if (val_select(null, item))
    	{
    		//        select = document.getElementById('ddlReports');
    		item['request'] = 'Schedule';//select.options[select.value].attributes['SERVICE'] + ';Schedule'

    		m_proc = m_ProcEnum.StatusCheck;
    		newMsg('Please Wait: Requesting report', false, null);
    		wcfPost(g_webService, item);
    		m_cnt = 0;
    		m_disableTimeout = false;
    	}
    }
}

function ValInput()
{
	var valid = true;
	var name;
	var item;
	var officeobjectid = jQuery("[name='officeobjectid']", '#input-area');

	for (name in m_inputFields)
	{
		switch (name)
		{
			case 'REPORT_TYPES':
				break;

			default:
				item = jQuery("[name='" + name.toLowerCase() + "']", '#input-area');
				if (item.length > 0)
				{
					valid &= item.validation('val')
				}
				break;
		}
	}

	// validate standard input used for all reports
	valid &= (officeobjectid.validation('val'));
	valid &= jQuery("[name='email_to']", '#input-area').validation('val');
	valid &= jQuery("[name='schedule_date']", '#input-area').validation('val');
	valid &= jQuery("[name='schedule_time']", '#input-area').validation('val');

	return valid;
}


function StatusCheck(requestId) {
    var info = {};
    var request = {};
    var select;
    var webRequest;
    var getStatus;

    m_cnt++;
    m_current_request_id = requestId;

    getStatus = (Math.floor(m_cnt / 30) == 0) ? true :
                    (m_cnt % (Math.floor((m_cnt < 150 ? m_cnt: 150) / 30) * 2) == 0);

    if (getStatus)
    {
        select = document.getElementById('ddlReports');

        info['JOB_ID'] = requestId;
        info['CONNECTION'] = g_user.CONNECTION;
    
        request['request'] = 'GetStatus';
        request['data'] = JSON.stringify(info);

        m_proc = m_ProcEnum.ProcessStatusCheck;
        wcfPost(g_webService, request);

    }
    else
    {
        // call ProcessStatusCheck to update screen every second with new count
        m_proc = m_ProcEnum.ProcessStatusCheck;
        Process('');
    }

}


function StatusUpdate(jobid) {
	var select = document.getElementById('ddlReports')
	var info = {};
    var request = {};
    var msg;

    // stop status check timer
    clearTimeout(m_timeoutId);
    m_disableTimeout = true;

    info['JOBID'] = jobid;
    info['CONNECTION'] = g_user.CONNECTION;

    msg = 'Please Wait: Canceling Report';

    request['request'] = 'CancelReports';
    request['data'] = JSON.stringify(info);

    g_messageBoxButton = m_btnErr;
    g_messageBoxErrorButton = m_btnErr;
    newMsg(msg, false, null);
    wcfPost(g_webService, request);
    m_removeMessage = false;
}



function office_selected(officeobjectid)
{
	var recs = m_reportControlParameters.OFFICE.OFFICE_LIST;
	var item = jQuery("[name='by_office_flg']", '#input-area');

    	item.prop("checked", false);
		jQuery("[name='by_office_flg'][hidden='hidden']", '#input-area').prop("checked", true);

    for (var inx = 0; inx < recs.length; inx++)
    {
    	if (recs[inx].OFFICEOBJECTID != officeobjectid) continue;

		if (recs[inx].ISDISTRICT == 'Y')
		{
			item.parent().parent().hide();
		}
		else
		{
			item.parent().parent().show();
		}

		break;
    }
}

function by_office_flg_onclick(item)
{
	if (item.checked)
	{
		jQuery("[name='by_office_flg'][hidden='hidden']", '#input-area').prop("checked", false);
	}
	else
	{
		jQuery("[name='by_office_flg'][hidden='hidden']", '#input-area').prop("checked", true);
	}
}

function attach_report_onclick(item)
{
	(item.checked) ? jQuery("[name='zip_report']", '#input-section').parent().show() :
					 jQuery("[name='zip_report']", '#input-section').parent().hide(); 

}


function DisplayReportFilter(show)
{
    if (show)
    {
        DisplayWaitArea(false);
        DisplayReportArea(false);

        DisplayNavigation(true);
        jQuery('#input-area').show();
    }
    else
    {
    	jQuery('#input-area').hide();
    }
}

function DisplayWaitArea(show)
{
    if (show)
    {
        DisplayReportFilter(false);
        DisplayReportArea(false)
        DisplayNavigation(false);

        jQuery('#wait-div').show();
    }
    else
    {
        jQuery('#wait-div').hide();
    }
}

function DisplayReportArea(show)
{
    if (show)
    {
        DisplayWaitArea(false);
        DisplayReportFilter(false);
        DisplayNavigation(false);

        jQuery('#report-div').show();
    }
    else
    {
        jQuery('#report-div').hide();
    }
}