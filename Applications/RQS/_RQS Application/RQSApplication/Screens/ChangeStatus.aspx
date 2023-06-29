<%@ Page Title="" Language="C#" MasterPageFile="~/Screens/SiteNavigation.master" AutoEventWireup="true" CodeBehind="ChangeStatus.aspx.cs" Inherits="RQS.Screens.ChangeStatus" %>

<asp:Content ID="Content1" ContentPlaceHolderID="head" runat="server">
    <script type="text/javascript" src="../JavaScript/validator.js"></script>
    <script type="text/javascript" src="../JavaScript/ChangeStatus.js"></script>
    <style type="text/css" >
        .request_id     { display: table-cell; padding:2px 1px 3px 1px; text-align:center; width:90px; }
        .retrieve       { display: table-cell; padding:2px 1px 3px 1px; text-align:center; width:90px; }
        .rpt_desc       { display: table-cell; padding:2px 1px 3px 1px; width:260px; border:0px solid black;}
        .office         { display: table-cell; padding:2px 1px 3px 1px; width:200px; border:0px solid black;}
        .run_dt         { display: table-cell; padding:2px 1px 3px 1px; width:200px; text-align:center; }
        .user_name      { display: table-cell; padding:2px 1px 3px 5px; width:120px; border:0px solid black;}
        .status         { display: table-cell; padding:2px 1px 3px 1px; text-align:center; width:50px; }

        .report_data_id { display: none; }
        .rpt_id         { display: none; }



        /*.request_id     { display: table-cell; padding:2px 1px 3px 1px; text-align:center; width:90px; }
        .retrieve       { display: table-cell; padding:2px 1px 3px 1px; text-align:center; width:80px; }
        .rpt_desc       { display: table-cell; padding:2px 1px 3px 1px; width:260px; border:0px solid black;}
        .start_date,     
        .end_date,
        .run_dt         { display: table-cell; padding:2px 1px 3px 1px; width:100px; text-align:center; }
        .user_name      { display: table-cell; padding:2px 1px 3px 5px; width:120px; border:0px solid black;}
        .status         { display: table-cell; padding:2px 1px 3px 1px; text-align:center; width:50px; }*/

        /*.report_data_id { display: none; }
        .rpt_id         { display: none; }*/
    </style>
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <div style="margin: 10px;">
        <div class="page-heading">Finalize / Delete Reports</div>
        <div id="select-div" style="display: none;">
<%--            <input type="hidden" name="user_id" id="user_id" class="return" />
            <input type="hidden" name="connection" id="connection" class="return" />
            <input type="hidden" name="user_role" id="user_role" class="return" value="U" />--%>

            <div class="rpt-heading" style="font-size: 16pt;">Report Select Filters</div>
            <div class="box">
                <div class="line">
                    <div class="left-col">
                        Action:
                    </div>
                    <div class="right-col" style="padding-right:15px;">
                        <input type="radio" value="C" name="status" checked="checked"/>
                        Finalize
                    </div>
                    <div class="right-col" style="padding-right:15px;">
                        <input type="radio" value="" name="status"/>
                        Delete
                    </div>
<%--                    <div class="right-col" style="padding-right:15px;">
                        <input type="radio" value="F" name="status"/>
                        Un-Finalized
                    </div>--%>
                </div>

                <div class="line">
                    <div class="left-col">Available Reports:</div>
                    <div id="available-reports" class="right-col">
                        <select id="ddlReports" name="select_report_id">
                        </select>
                    </div>
                    <div id="available-report" class="right-col"></div>
                </div>

                <div id="office-div"  class="no-display" style="padding: 5px 0px 20px 0px;">
                    <div class="left-col">Offices:</div>
                    <div class="right-col">
                        <select id="selected_office" name="selected_office" onchange="report_selected($(this).val())">
                        </select>
                    </div>
                </div>

<%--                <div class="line">
					<div class="left-col">Between Dates From:</div>
					<div class="right-col">
						<input type="text" name="start_date" id="start_date" maxlength="10"
							placeholder="mm/dd/yyyy" style="width: 80px;" />
						(mm/dd/yyyy)
					</div>
					<div class="left-col" style="width: 50px;">To:</div>
					<div class="right-col">
						<input type="text" name="end_date" id="end_date" maxlength="10"
							placeholder="mm/dd/yyyy" style="width: 80px;" />
						(mm/dd/yyyy)
					</div>
				</div>--%>

				<div class="line">
					<div class="left-col" style="">
						Request ID:
					</div>
					<div class="right-col">
						<input type="text" name="request_id" id="request_id" />
					</div>
				</div>

				<div class="line" style="padding-top: 10px;">
					<div class="left-col"></div>
					<div class="right-col">Retrieve Reports Taken Between the following Dates (inclusive)
					</div>
				</div>
				<div class="line">
					<div class="left-col">Start:</div>
					<div class="right-col">
						<input type="text" name="start_date" id="start_date" maxlength="10"
							placeholder="mm/dd/yyyy" style="width: 80px;" />
						(mm/dd/yyyy)
					</div>
					<div class="left-col" style="width: 50px;">End:</div>
					<div class="right-col">
						<input type="text" name="end_date" id="end_date" maxlength="10"
							placeholder="mm/dd/yyyy" style="width: 80px;" />
						(mm/dd/yyyy)
					</div>
				</div>

				<div style="text-align: center; margin-top: 10px;">
					<input type="button" id="btnSubmit" value="Continue" onclick="GetReportList();" />
                </div>
            </div>
        </div>


          <div id="report-list-div" style="margin:10px 10px; display: none;">
<%--            <div class="page-heading">
                Finalize / DeleteReports
            </div>--%>
            <div style="text-align: center; padding-bottom: 20px; ">
                <input type="button" value="New List / Menus"  style="width:30%; padding: 5px;" onclick="DisplayReportFilter(true);" />
            </div>

            <div class="rpt-heading">
                <div id="action" class="retrieve">Finialize Report</div>
                <%--<div class="finalize">Finialize Report</div>--%>
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
            <div class="box" id="display-list" style="padding: 0px; min-height:20px;"></div>
        </div>


<%--        <div id="report-list-div" style="display:none;">
            <div style="text-align: right; padding-bottom: 10px;">
                <input type="button" value="New List" onclick="jQuery('#report-list-div').hide(); jQuery('#select-div').show();" />
            </div>
           
            <div class="rpt-heading">
                <div class="request_id">Id</div>
                <div id="action" class="retrieve">Retrieve</div>
                <div class="rpt_desc" >Report Name</div>--%>
                <%--<div class="start_date">Start Date</div>
                <div class="end_date">End Date</div>
                --%><%--<div class="user_name">Requested By</div>
                <div class="run_dt">Run Date</div>
                <div class="status">Status</div>
            </div>
            <div class="box" id="display-list" style="padding: 0px;"></div>
        </div>--%>
    </div>
</asp:Content>
