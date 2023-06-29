<%@ Page Title="" Language="C#" MasterPageFile="~/Screens/SiteNavigation.master" AutoEventWireup="true" CodeBehind="ViewErrors.aspx.cs" Inherits="RQS.Screens.ViewErrors" %>

<asp:Content ID="Content1" ContentPlaceHolderID="head" runat="server">
    <script type="text/javascript">

        var m_btnUpdate = {
            0: {
                value: 'OK',
                onclick: "_modal.close();_modal=undefined;$('div', '#msg-target-data').remove(); jQuery('#report-div').hide();GetReportList();"
            }
        };

        $(document).ready(function () {
            GetReportList();
        });

        function GetReportList() {
            var request = {};

            request['request'] = 'RQS;Reports.Report;ReportList';
            isDirty(null, request);

            newMsg('Please Wait: Retrieving Report Information', false, null);
            wcfPost(g_webService, request);
        }

        function Process(data) {
            var recs = jQuery.parseJSON(data);
            var root = jQuery('#display-list');
            var row;
            var input;

            // clear old list information
            root.html('');

            $.each(recs, function (inx) {
                row = jQuery(document.createElement('div'));
                CreateReportElement('row_id', this.REQUEST_ID, row);

                input = jQuery(document.createElement('input'));
                input.attr('type', 'button');
                input.attr('class', 'btn-push btn-start');
                input.attr('onclick', "RequestReport('" + (inx + 1) + "', '" + this.REQUEST_ID + "');");
                input.appendTo(CreateReportElement('retrieve', null, row));

                input = jQuery(document.createElement('input'));
                input.attr('type', 'button');
                input.attr('class', 'btn-push btn-delete');
                input.attr('onclick', "update('" + this.REQUEST_ID + "');");
                input.appendTo(CreateReportElement('retrieve', null, row));

                CreateReportElement('rpt_desc', this.RPT_DESC, row);
                CreateReportElement('start_date', this.START_DATE, row);
                CreateReportElement('end_date', this.END_DATE, row);
                CreateReportElement('user_name', this.USER_NAME, row);
                CreateReportElement('run_dt', this.RUN_DT, row);
                CreateReportElement('status', this.STATUS, row);

                CreateReportElement('report_data_id', this.REPORT_DATA_ID, row);
                CreateReportElement('rpt_id', this.RPT_ID, row);

                row.attr('class', 'rpt-row');
                row.appendTo(root);
            });
        }

        function RequestReport(row, parmsId) {
            var info = {};
            var request = {};

            info['REPORT'] = parmsId;
            info['CONNECTION'] = g_user.CONNECTION;
            info['SITE'] = window.location.host.toLowerCase();

            request['request'] = 'RQS;Reports.Report;RetrieveReport';
            request['data'] = JSON.stringify(info);

            newMsg('Please Wait: Retrieving Error', false, null);
            wcfPost(g_webService, request);
        }

        function update(reportId) {
            var confirmed;
            var msg;
            var info = {};
            var request = {};

            if (confirm('Are you sure you want to delete record ' + reportId + '?')) {
                info['STATUS'] = '';
                info['REPORT'] = reportId;
                info['CONNECTION'] = g_user.CONNECTION;

                request['request'] = 'RQS;Reports.Report;StatusUpdate';
                request['data'] = JSON.stringify(info);

                newMsg('Please Wait: Deleting report ' + reportId, false, null);
                wcfPost(g_webService, request);
                g_messageBoxButton = m_btnUpdate;
            }
        }
    </script>
    <style type="text/css" >
        .row_id         { display: table-cell; padding:2px 1px 3px 1px; text-align:center; width:90px; }
        .retrieve       { display: table-cell; padding:2px 1px 3px 1px; text-align:center; width:60px; }
        .rpt_desc       { display: table-cell; padding:2px 1px 3px 1px; width:260px; border:0px solid black;}
        .start_date,     
        .end_date,
        .run_dt         { display: table-cell; padding:2px 1px 3px 1px; width:100px; text-align:center; }
        .user_name      { display: table-cell; padding:2px 1px 3px 5px; width:120px; border:0px solid black;}
        .status         { display: table-cell; padding:2px 1px 3px 1px; text-align:center; width:50px; }

        .report_data_id { display: none; }
        .rpt_id         { display: none; }
    </style>
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">

    <div style="margin: 10px;">
        <div class="page-heading">Retrieve / Delete Error Records</div>

        <div id="select-div" >
            <%--<input type="hidden" name="user_id" id="user_id" class="return" />
            <input type="hidden" name="connection" id="connection" class="return" />
            <input type="hidden" name="user_role" id="user_role" class="return" value="U" />--%>
            <input type="hidden" name="status" id="status" class="return" value="E" />

            <div class="rpt-heading">
                <div class="row_id">Id</div>
                <div class="retrieve">Retrieve</div>
                <div class="retrieve">Delete</div>
                <div class="rpt_desc" >Report Name</div>
                <%--<div class="start_date">Start Date</div>
                <div class="end_date">End Date</div>
                --%><div class="user_name">Requested By</div>
                <div class="run_dt">Run Date</div>
                <div class="status">Status</div>
            </div>
            <div class="box" id="display-list" style="padding: 0px;"></div>

        </div>
    </div>

</asp:Content>
