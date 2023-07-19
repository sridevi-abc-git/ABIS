
<%@ Page Title="" Language="C#" MasterPageFile="~/Screens/SiteNavigation.master" AutoEventWireup="true" CodeBehind="JobManager.aspx.cs" Inherits="RQS.Screens.JobManager" %>
<asp:Content ID="Content1" ContentPlaceHolderID="head" runat="server">
    <script type="text/javascript" src="../JavaScript/jobmanager.js"></script>
    <style type="text/css" >
        .start-delete   { display: table-cell; padding:2px 1px 3px 1px; text-align:center; width:45px; }
        .job_name       { display: table-cell; padding:2px 1px 3px 1px; text-align:center; width:110px; border:0px solid black; }
        /*.request_id     { display: table-cell; padding:2px 1px 3px 1px; text-align:center; width:90px; }*/
        /*.retrieve       { display: table-cell; padding:2px 1px 3px 1px; text-align:center; width:90px; }*/
        .rpt_desc       { display: table-cell; padding:2px 1px 3px 1px; width:260px; border:0px solid black;}
        .office         { display: table-cell; padding:2px 1px 3px 1px; width:200px; border:0px solid black;}
        .schedule_date  { display: table-cell; padding:2px 1px 3px 1px; width:170px; text-align:center;  border:0px solid black;}
        .job_creator      { display: table-cell; padding:2px 1px 3px 5px; width:120px; border:0px solid black;}
        .state         { display: table-cell; padding:2px 1px 3px 1px; text-align:center; width:140px; }

        .rpt_id         { display: none; }


        /*.start-delete   { display: table-cell; padding:2px 1px 3px 1px; text-align:center; width:45px; }
        .job_name       { display: table-cell; padding:2px 1px 3px 1px; text-align:center; width:110px; border:0px solid black; }
        .rpt_desc       { display: table-cell; padding:2px 1px 3px 1px; width:260px; border:0px solid black;}
        .job_creator    { display: table-cell; padding:2px 1px 3px 5px; width:130px; border:0px solid black;}
        .state          { display: table-cell; padding:2px 1px 3px 1px; text-align:center; width:140px; }
        .state-info     { display: block; padding:0px 1px 1px 1px; text-align:center; width:140px; }
        .start_date,     
        .end_date       { display: table-cell; padding:2px 1px 3px 1px; width:90px; text-align:center; }*/
    </style>
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
<%--    <input type="hidden" name="user_id" id="user_id" class="return" />
    <input type="hidden" name="user_role" id="user_role" class="return" runat="server" />
    <input type="hidden" name="connection" id="connection" class="return" />--%>


          <div id="report-list-div" style="margin:10px 10px; display: none;">
            <div class="page-heading">
                Manage Scheduled Jobs
            </div>
            <div style="text-align: center; padding-bottom: 20px; ">
                <input type="button" value="Menus"  style="width:30%; padding: 5px;" onclick="DisplayReportList(false);" />
            </div>

            <div class="rpt-heading">
                <div class="start-delete">Start Stop Job</div>
                <div class="start-delete">Delete Job</div>
                <div class="job_name">Job Name</div>
                <%--<div class="finalize">Finialize Report</div>--%>
                <%--<div class="retrieve">Retrieve</div>--%>
                <div class="rpt_desc" >Report Name</div>
                <div class="office">Office</div>
                <%--<div class="request_id">Id</div>--%>
                <%--<div class="start_date">Start Date</div>
                <div class="end_date">End Date</div>--%>
                <div class="state">Status</div>
                <div class="schedule_date">Schedule Date</div>
                <div class="job_creator">Requested By</div>
            </div>
            <div class="box" id="display-list" style="padding: 0px; min-height:20px;"></div>
        </div>


<%--    <div id="job-list-div" style="display:none;">
        <div style="margin:10px 10px;">
            <div class="page-heading">
                Manage Scheduled Jobs
            </div>
            <div class="rpt-heading">
                <div class="start-delete">Start Stop Job</div>
                <div class="start-delete">Delete Job</div>
                <div class="job_name">Job Name</div>
                <div class="rpt_desc" style="text-align:center;">Report Name</div>
                --%><%--<div class="start_date">Start Date</div>
                <div class="end_date">End Date</div>
                --%><%--<div class="job_creator" style="text-align:center;">Requested By</div>
                <div class="state">State</div>
            </div>
            <div class="box" id="display-list" style="padding: 0px;"></div>
        </div>
    </div>--%>
</asp:Content>
