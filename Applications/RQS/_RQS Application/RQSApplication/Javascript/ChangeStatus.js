

var m_btnUpdate = {
    0: {
        value: 'OK',
        onclick: "_modal.close();_modal=undefined;$('div', '#msg-target-data').remove(); jQuery('#report-div').hide();GetReportList();"
    }
};

var m_ProcEnum = { 'Defs': 0, 'ReportList': 1, '': 2 };
var m_proc;

$(document).ready(function () {
    var item = {};
    item['request'] = 'Defs';
    item['data'] = JSON.stringify(g_user);

    jQuery('#start_date', '#select-div').val(getDateDaysBack(7));
    jQuery('#end_date', '#select-div').val(getDate());

	// get list of report definitions for selected user
    m_proc = m_ProcEnum.Defs;
    newMsg('Please Wait: Retrieving Reports Definitions for User', false, null);
    wcfPost(g_webService, item);

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

function Process(data) {

    switch (m_proc) {
        case m_ProcEnum.Defs:
            initReportSelection(data)
            initOfficSelection(data);
            jQuery("#select-div").show();
            break;

        case m_ProcEnum.ReportList:
            var recs = jQuery.parseJSON(data);
            var root = jQuery('#display-list');
            var action = jQuery("[name='status']");
            var row;
            var input;
            var actionValue;

            // clear old list information
            root.html('');

            action.each(function () {
                if ($(this).is(':checked')) {
                    actionValue = jQuery(this).val();
                }
            });

            // get button action to perform
            switch (actionValue) {
                case 'C':   // finalize (current status)
                    jQuery('#action-header').html('None Finalized Report List');
                    jQuery('#action').html('Finalize');
                    break;

                case 'F':  // unfinalize 
                    jQuery('#action-header').html('Finalized Report List');
                    jQuery('#action').html('Un-Finalize');
                    break;

                default:
                    jQuery('#action-header').html('Report List');
                    jQuery('#action').html('Delete');
                    break;
            }

            $.each(recs, function (inx) {
                row = jQuery(document.createElement('div'));
                errorRec = (this.STATUS == 'E');

                //CreateReportElement('request_id', this.REQUEST_ID, row);

                input = jQuery(document.createElement('input'));
                input.attr('type', 'button');

                switch (actionValue) {
                    case 'C':   // finalize (current status)
                        input.attr('class', 'btn-push btn-start');
                        input.attr('onclick', "update('" + this.REQUEST_ID + "', 'F');");
                        break;

                    case 'F':  // unfinalize 
                        input.attr('class', 'btn-push btn-delete');
                        input.attr('onclick', "update('" + this.REQUEST_ID + "', 'C');");
                        break;

                    default:
                        input.attr('class', 'btn-push btn-delete');
                        input.attr('onclick', "update('" + this.REQUEST_ID + "', '');");
                        break;
                }

                input.appendTo(CreateReportElement('retrieve', null, row));

                CreateReportElement('rpt_desc', this.RPT_DESC, row);
                CreateReportElement('office', this.OFFICE, row);
                CreateReportElement('request_id', this.REQUEST_ID, row);
                CreateReportElement('run_dt', this.RUN_DT, row);
                CreateReportElement('status', this.STATUS, row);
                CreateReportElement('user_name', this.USER_NAME, row);


                //CreateReportElement('rpt_desc', this.RPT_DESC, row);
                ////CreateReportElement('start_date', this.START_DATE, row);
                ////CreateReportElement('end_date', this.END_DATE, row);
                //CreateReportElement('user_name', this.USER_NAME, row);
                //CreateReportElement('run_dt', this.RUN_DT, row);
                //CreateReportElement('status', this.STATUS, row);

                CreateReportElement('rpt_id', this.RPT_ID, row);

                row.attr('class', (errorRec) ? 'rpt-row-error' : 'rpt-row');
                row.appendTo(root);

            });

            DisplayReportList(true);
            //jQuery('#select-div').hide();
            //jQuery('#report-list-div').show();

            break;

    }
}

function GetReportList() {
    var request = {};

    request['request'] = 'ReportList'
    isDirty(null, request);

    newMsg('Please Wait: Retrieving Report Information', false, null);
    wcfPost(g_webService, request);
    m_proc = m_ProcEnum.ReportList;

    return false;
}


function update(requestId, status) {
    var confirmed;
    var msg;
    var info = {};
    var request = {};

    switch (status) {
        case 'F':
            confirmed = confirm('Are you sure you want to finalize selected report Id: ' + requestId + '?');
            msg = 'Please Wait: Finalizing report ' + requestId;
            break;

        case 'C':
            confirmed = confirm('Are you sure you want to un-finalize selected report Id: ' + requestId + '?');
            msg = 'Please Wait: Un-Finalizing report ' + requestId;
            break;

        default:
            confirmed = confirm('Are you sure you want to delete report ' + requestId + '?');
            msg = 'Please Wait: Deleting report ' + requestId;
            break;
    }

    if (confirmed) {
        info['STATUS'] = status;
        info['REPORT'] = requestId;
        info['CONNECTION'] = g_user.CONNECTION;

        request['request'] = 'StatusUpdate';
        request['data'] = JSON.stringify(info)

        newMsg(msg, false, null);
        wcfPost(g_webService, request);
        g_messageBoxButton = m_btnUpdate;
        g_messageBoxErrorButton = m_btnUpdate; 
    }

}

//function DisplayReportList(show)
//{
//    if (show)
//    {
//        DisplayNavigation(false);
//        jQuery('#report-list-div').show();
//    }
//    else
//    {
//        jQuery('#report-list-div').hide();
//        DisplayNavigation(true);
//    }
//}





