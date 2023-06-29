
var m_btnUpdate = {
    0: {
        value: 'OK',
        onclick: "_modal.close();_modal=undefined;$('div', '#msg-target-data').remove(); jQuery('#report-div').hide();GetJobList();"
    }
};


$(document).ready(function () {
    GetJobList();
});

function GetJobList()
{
    request = {};

    request['request'] = 'RQS;Reports.Report;JobList';
    request['data'] = JSON.stringify(g_user);

    newMsg('Please Wait: Retrieving Jobs', false, null);
    wcfPost(g_webService, request);
}

function Process(data)
{
    var recs = jQuery.parseJSON(data);
    var root = jQuery('#display-list');
    var row;
    var cell;
    var inputStart;
    var inputDelete;

    // clear old list information
    root.html('');

    $.each(recs, function (inx) {
        row = jQuery(document.createElement('div'));

        inputStart = jQuery(document.createElement('input'));
        inputStart.attr('type', 'button');

        inputDelete = jQuery(document.createElement('input'));
        inputDelete.attr('type', 'button');

        switch (this.STATE)
        {
            case 'RUNNING':
                inputStart.attr('class', 'btn-push btn-stop');
                inputStart.attr('onclick', "job_update('" + this.JOB_NAME + "', 'S');");
                inputDelete.attr('class', 'btn-push btn-disabled');
                break;

            case 'SCHEDULED':
                inputStart.attr('class', 'btn-push btn-start');
                inputStart.attr('onclick', "job_update('" + this.JOB_NAME + "', 'R');");

                inputDelete.attr('class', 'btn-push btn-delete');
                inputDelete.attr('onclick', "job_update('" + this.JOB_NAME + "', 'D');");
                break;

            case 'DISABLED':
                inputStart.attr('class', 'btn-push btn-disabled');
                inputDelete.attr('class', 'btn-push btn-delete');
                inputDelete.attr('onclick', "job_update('" + this.JOB_NAME + "', 'D');");
                break;

            default:
                break;
        }

        inputStart.appendTo(CreateReportElement('start-delete', null, row));
        inputDelete.appendTo(CreateReportElement('start-delete', null, row));

        CreateReportElement('job_name', this.JOB_NAME, row);
        CreateReportElement('rpt_desc', this.RPT_DESC, row);
        CreateReportElement('office', this.OFFICE, row);
        //CreateReportElement('request_id', this.REQUEST_ID, row);
        //CreateReportElement('run_dt', this.RUN_DT, row);
        CreateReportElement('state', this.STATE, row);
        //CreateReportElement('user_name', this.USER_NAME, row);
        //CreateReportElement('state_info', this.STATE, row);
        CreateReportElement('schedule_date', this.SCHEDULE_DATE, row);
        CreateReportElement('job_creator', this.JOB_CREATOR, row);

        CreateReportElement('rpt_id', this.RPT_ID, row);



        //CreateReportElement('rpt_desc', this.RPT_DESC, row);
        ////CreateReportElement('start_date', this.START_DATE, row);
        ////CreateReportElement('end_date', this.END_DATE, row);
        //CreateReportElement('job_creator', this.JOB_CREATOR, row);

        //cell = CreateReportElement('state', '', row);
        //CreateReportElement('state-info', this.STATE, cell);
        //CreateReportElement('schedule-date', this.SCHEDULE_DATE, cell);

        row.attr('class', 'rpt-row');
        row.appendTo(root);
    });

    //jQuery('#report-list-div').show();
    DisplayReportList(true);

}


function job_update(jobName, action)
{
    var confirmed;
    var msg;
    var btn;
    var info = {};
    var request = {};

    switch (action)
    {
        case 'D':
            confirmed = confirm('Are you sure you want to delete job ' + jobName + '?');
            msg = 'Please Wait: Deleting job ' + jobName;
            break;

        case 'R':
            confirmed = confirm('Are you sure you want to start job ' + jobName + '?');
            msg = 'Please Wait: Starting ' + jobName;
            break;

        case 'S':
            confirmed = confirm('Are you sure you want to stop job ' + jobName + '?');
            msg = 'Please Wait: Stopping ' + jobName;
            break;
    }

    if (confirmed)
    {
        info['ACTION'] = action;
        info['JOB_NAME'] = jobName;
        info['CONNECTION'] = jQuery("[id$='connection']").val();

        request['request'] = 'RQS;Reports.Report;UpdateJob';
        request['data'] = JSON.stringify(info);

        newMsg(msg, false, null);
        g_messageBoxButton = m_btnUpdate;
        g_messageBoxErrorButton = m_btnUpdate;
        wcfPost(g_webService, request);
    }
}

function DisplayReportList(show)
{
    if (show)
    {
        DisplayNavigation(false);
        jQuery('#report-list-div').show();
    }
    else
    {
        jQuery('#report-list-div').hide();
        DisplayNavigation(true);
    }
}

