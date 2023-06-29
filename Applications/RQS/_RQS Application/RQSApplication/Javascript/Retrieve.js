

var m_ProcEnum = {'Defs' : 0, 'ReportList' : 1, 'RetrieveReport' : 2};
var m_proc;
var m_reportId;
var m_report_type;
var m_infodata;

var m_reportControlParameters;

$(document).ready(function () {
    var request = {};

    request['request'] = 'GetControlParameter';
    request['data'] = JSON.stringify(g_user);

    jQuery('#start_date', '#input-area').val(getDateDaysBack(7));
    jQuery('#end_date', '#input-area').val(getDate());

    // get list of report definitions for selected user
    m_proc = m_ProcEnum.Defs;
    newMsg('Please Wait: Retrieving Reports Definitions for User', false, null);
    wcfPost(g_webService, request);

    // setup input validators
    jQuery('#start_date', '#input-area').validation('add', {
        validator: VAL_DATEPATTERNSTANDARD, required: false, message: {
            INVALID: 'Invalid date entered.'
        }
    });

    jQuery('#end_date', '#input-area').validation('add', {
        validator: VAL_DATEPATTERNSTANDARD, required: false, message: {
            INVALID: 'Invalid date entered.'
        }
    });

    jQuery('#request_id', '#input-area').validation('add', {
        validator: '^RPT[0-9]*$', required: false, message: {
            INVALID: 'Invalid Job Id entered.'
        }
    });
});


function GetReportList() {
    var request = {};
    var select;

    request['request'] = 'RetrieveReportList'
    getValues('input-area', request);
    m_proc = m_ProcEnum.ReportList;

    newMsg('Please Wait: Retrieving Report Information', false, null);
    wcfPost(g_webService, request);

    return false;
}

function RequestReport(requestId, reportId, displayMessage) {
    var values = {};
    var request = {};
    var x = this;

    values['SEQ'] = requestId;
    values['CONNECTION'] = g_user.CONNECTION;

    request['request'] = 'RetrieveReport'
    request['data'] = JSON.stringify(values);

    m_proc = m_ProcEnum.RetrieveReport;

    if (displayMessage) newMsg('Please Wait: Retrieving Report', false, null);
    wcfPost(g_webService, request);
    m_reportId = reportId;
}


function Process(data) {
    
    switch (m_proc)
    {
        case m_ProcEnum.Defs:
        	var reportCnt;

        	m_reportControlParameters = jQuery.parseJSON(data);

 //       	if (data.err == null)
            {
            	reportCnt = initReportSelection(m_reportControlParameters);

        		initOfficSelection(m_reportControlParameters);

                //initReportSelection(data, false)
                //initOfficSelection(data);

        		jQuery("#input-area").show();

            }
            //else
            //{
            //	m_removeMessage = newMsg(data.err, false, g_messageBoxErrorButton);
            //}
            break;

        case m_ProcEnum.ReportList:
            var recs = jQuery.parseJSON(data);
            var head = jQuery('#rpt-heading');
            var root = jQuery('#display-list');
            var row;
            var head_row;

            // clear old list information
            head.html('');
            root.html('');

            $.each(recs, function (inx)
            {
                if (inx == 0) head_row = jQuery(document.createElement('div'));
                row = jQuery(document.createElement('div'));

                if (inx == 0) CreateReportElement('report_name', 'Report Name', head_row);
                CreateReportElement('report_name', (this.USER_COMMENT.length > 0) ?
                                                    this.REPORT_NAME + ' (' + this.USER_COMMENT + ')' : this.REPORT_NAME, row);

                if (inx == 0) CreateReportElement('office', 'Office', head_row);
                CreateReportElement('office', this.OFFICENAME, row);

                //if (inx == 0) CreateReportElement('job_id', 'Id', head_row);
                //CreateReportElement('job_id', this.REQUEST_ID, row);

                if (inx == 0) CreateReportElement('user_name', 'Requested By', head_row);
                CreateReportElement('user_name', this.USER_NAME, row);

                //if (inx == 0) CreateReportElement('status', 'Status', head_row);
                //CreateReportElement('status', (this.STATUS == 'F'? 'Final':' '), row);

                if (inx == 0) CreateReportElement('seq', '', head_row);
                CreateReportElement('seq', this.SEQ, row);

                if (inx == 0) CreateReportElement('report_date', 'Run Date', head_row);
                CreateReportElement('report_date', this.REPORT_DATE, row);

                if (inx == 0) CreateReportElement('job_id', 'Report Job', head_row);
                CreateReportElement('job_id', this.JOB_ID, row);

                row.attr('class', 'rpt-row');
                row.attr('onclick', "RequestReport('" + this.SEQ + "','" + this.SEQ + "',true);");
                row.attr('test', 'abcd');
                if (inx == 0) head_row.appendTo(head);
                row.appendTo(root);
            });
            if (recs.length == 1)
            {
            	RequestReport(recs[0].SEQ, recs[0].SEQ, false);
            }
            else
            {
				DisplayReportList(true);
            }
            break;

    	case m_ProcEnum.RetrieveReport:
    		var info = jQuery.parseJSON(data);

    		switch (info.output_type.toLowerCase())
            {
    			case "html-print":
    				// display print preview button
    				m_infodata = info.file.substring(0);
    				document.getElementById("print-preview-btn").style.display = 'inline-block';
    				document.getElementById("print-report-btn").style.display = 'none';

    			case "html":
    				var wnd = window.open("about:blank", "");
    				wnd.document.write(info.file);
                    //jQuery('#report').html(info.file);
                    //DisplayReportArea(true);
                    //DisplayNavigation(false);
                    break;

            	case "excel":
            		DisplayExcel(info.file);
            		break;

    			case "pdf":
    				DisplayPDF(info.file);
    				break;

                default:
                    break;
            }

            break;
    }


}

function DisplayReportFilter(show)
{
    if (show)
    {
        DisplayReportList(false);
        DisplayReportArea(false);

        DisplayNavigation(true);
        jQuery('#input-area').show();
    }
    else
    {
    	jQuery('#input-area').hide();
    }
}

function DisplayReportList(show)
{
    if (show)
    {
        DisplayReportFilter(false);
        DisplayReportArea(false);
        DisplayNavigation(false);

        jQuery('#report-list-div').show()
    }
    else
    {
        jQuery('#report-list-div').hide();
    }
}

function DisplayReportArea(show)
{
    if (show)
    {
        DisplayReportFilter(false);
        DisplayReportList(false);
        DisplayNavigation(false);

        jQuery('#report-div').show();
    }
    else
    {
        jQuery('#report-div').hide();
    }
}

