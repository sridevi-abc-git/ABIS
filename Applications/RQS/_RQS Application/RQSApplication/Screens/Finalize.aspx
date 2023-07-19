<%@ Page Title="" Language="C#" MasterPageFile="~/Screens/SiteNavigation.master" AutoEventWireup="true" CodeBehind="Finalize.aspx.cs" Inherits="RQS.Screens.Finalize" %>

<asp:Content ID="Content1" ContentPlaceHolderID="head" runat="server">
    <script type="text/javascript">

        var m_btnUpdate = {
            0: {
                value: 'OK',
                onclick: "_modal.close();_modal=undefined;$('div', '#msg-target-data').remove(); getList();"
            }
        };

        $(document).ready(function () {
            getList();
        });

        function getList() {
            var request = {};

            request['request'] = 'RQS;Reports.Report;ReportList';
            isDirty(null, request);

            newMsg('Please Wait: Retrieving Report Information', false, null);
            wcfPost(g_webService, request);
        }

        function finalize(requestId, status) {
            var confirmed;
            var msg;
            var btn;
            var info = {};
            var request = {};

            if (confirm('Are you sure you want to finalize selected report Id: ' + requestId + '?')) {
                info['STATUS'] = status;
                info['REPORT'] = requestId;
                info['CONNECTION'] = g_user.CONNECTION;

                request['request'] = 'RQS;Reports.Report;StatusUpdate';
                request['data'] = JSON.stringify(info);

                newMsg('Please Wait: Finalizing report', false, null);
                wcfPost(g_webService, request);

                g_messageBoxButton = m_btnUpdate;
                g_messageBoxErrorButton = m_btnUpdate;
            }
        }


        function Process(data) 
        {
            var recs = jQuery.parseJSON(data);
            var root = jQuery('#display-list');
            var row;
            var input;

            // clear old list information
            root.html('');

            $.each(recs, function (inx) {
                row = jQuery(document.createElement('div'));

                CreateReportElement('request_id', this.REQUEST_ID, row);

                input = jQuery(document.createElement('input'));
                input.attr('type', 'button');
                input.attr('class', 'btn-push btn-start');
                input.attr('onclick', "finalize('" + this.REQUEST_ID + "', 'F', '" + (inx + 1) + "');");

                // add start job end job values
                input.appendTo(CreateReportElement('finalize', null, row));

                CreateReportElement('rpt_desc', this.RPT_DESC, row);
                CreateReportElement('office', this.OFFICE, row);
                CreateReportElement('request_id', this.REQUEST_ID, row);
                CreateReportElement('run_dt', this.RUN_DT, row);
                CreateReportElement('status', this.STATUS, row);
                CreateReportElement('user_name', this.USER_NAME, row);

                CreateReportElement('rpt_id', this.RPT_ID, row);

                //row.attr('class', (errorRec) ? 'rpt-row-error' : 'rpt-row');
                //row.appendTo(root);



                //CreateReportElement('rpt_desc', this.RPT_DESC, row);
                ////CreateReportElement('start_date', this.START_DATE, row);
                ////CreateReportElement('end_date', this.END_DATE, row);
                //CreateReportElement('user_name', this.USER_NAME, row);
                //CreateReportElement('run_dt', this.RUN_DT, row);

                row.attr('class', 'rpt-row');
                row.appendTo(root);
            });

            DisplayReportList(true);
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


	</script>
    <style type="text/css" >

        /*.request_id     { display: table-cell; padding:2px 1px 3px 1px; text-align:center; width:90px; }*/
        .finalize       { display: table-cell; padding:2px 1px 3px 1px; text-align:center; width:90px; }
        /*.rpt_desc       { display: table-cell; padding:2px 1px 3px 1px; width:260px; border:0px solid black;}*/
        /*.start_date,     
        .end_date,
        .run_dt         { display: table-cell; padding:2px 1px 3px 1px; width:100px; text-align:center; }*/
        /*.user_name      { display: table-cell; padding:2px 1px 3px 5px; width:160px; border:0px solid black;}*/

        .request_id     { display: table-cell; padding:2px 1px 3px 1px; text-align:center; width:90px; }
        /*.retrieve       { display: table-cell; padding:2px 1px 3px 1px; text-align:center; width:90px; }*/
        .rpt_desc       { display: table-cell; padding:2px 1px 3px 1px; width:260px; border:0px solid black;}
        .office         { display: table-cell; padding:2px 1px 3px 1px; width:200px; border:0px solid black;}
        .run_dt         { display: table-cell; padding:2px 1px 3px 1px; width:200px; text-align:center; }
        .user_name      { display: table-cell; padding:2px 1px 3px 5px; width:120px; border:0px solid black;}
        .status         { display: table-cell; padding:2px 1px 3px 1px; text-align:center; width:50px; }

        .rpt_id         { display: none; }



    </style>
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <div id="list-div">
        <input type="hidden" name="status" id="status" class="return" value="C" />

          <div id="report-list-div" style="margin:10px 10px; display: none;">
            <div class="page-heading">
                Finalize Reports
            </div>
            <div style="text-align: center; padding-bottom: 20px; ">
                <input type="button" value="Menus"  style="width:30%; padding: 5px;" onclick="DisplayReportList(false);" />
            </div>

            <div class="rpt-heading">
                <div class="finalize">Finialize Report</div>
                <%--<div class="retrieve">Retrieve</div>--%>
                <div class="rpt_desc" >Report Name</div>
                <div class="office">Office</div>
                <div class="request_id">Id</div>
                <%--<div class="start_date">Start Date</div>
                <div class="end_date">End Date</div>--%>
                <div class="run_dt">Run Date</div>
                <div class="status">Status</div>
                <div class="user_name">Requested By</div>
            </div>
            <div class="box" id="display-list" style="padding: 0px;"></div>
        </div>

<%--        <div style="margin:10px 10px;">
            <div class="page-heading">
                Finalize Reports
            </div>
            <div class="rpt-heading">
                <div class="request_id">Id</div>
                <div class="finalize">Finialize Report</div>
                <div class="rpt_desc" >Report Name</div>
                <%--<div class="start_date">Start Date</div>
                <div class="end_date">End Date</div>
                --%><%--<div class="user_name">Requested By</div>
                <div class="run_dt">Run Date</div>
            </div>
            <div class="box" id="display-list" style="padding: 0px;">
            </div>
        </div>--%>
    </div>
</asp:Content>
