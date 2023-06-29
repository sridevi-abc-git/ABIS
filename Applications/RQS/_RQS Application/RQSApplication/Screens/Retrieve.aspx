<%@ Page Title="" Language="C#" MasterPageFile="~/Screens/SiteNavigation.master" AutoEventWireup="true" CodeBehind="Retrieve.aspx.cs" Inherits="RQS.Screens.Retrieve" %>

<asp:Content ID="Content1" ContentPlaceHolderID="head" runat="server">
    <script type="text/javascript" src="../JavaScript/validator.js"></script>
    <script type="text/javascript" src="../JavaScript/Retrieve.js"></script>
    <style type="text/css" >
        .job_id         { display: table-cell; padding:2px 15px 3px 1px; text-align: right;  width: 60px;}
        .request_id     { display: table-cell; padding:2px 1px 3px 1px; text-align:center; width:90px; }
        .retrieve       { display: table-cell; padding:2px 1px 3px 1px; text-align:center; width:90px; }
        .report_name    { display: table-cell; padding:2px 1px 3px 10px; width:350px; border:0px solid black;}
        .office         { display: table-cell; padding:2px 1px 3px 1px; width:200px; border:0px solid black;}
        .start_date,     
        .end_date,
        .report_date    { display: table-cell; padding:2px 1px 3px 1px; width:200px; text-align:center; }
        .user_name      { display: table-cell; padding:2px 1px 3px 5px; width:120px; border:0px solid black;}
        .status         { display: table-cell; padding:2px 1px 3px 1px; text-align:center; width:50px; }
        .user_comment   { display: table-cell; padding:2px 1px 3px 1px; text-align:left; width:150px; }
        .seq            { display: none; }
    </style>

</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <div style="margin: 10px;">
        <div class="page-heading">Retrieve Reports</div>

        <div id="input-area" style="display: none;">
            <div class="rpt-heading">Retrieve Reports</div>
            <div class="box">

<%--                <div class="line">
                    <div class="left-col">
                        Report Status Types:
                    </div>
                    <div class="right-col" style="padding-right:15px;">
                        <input type="radio" value="" name="status" checked="checked"/>
                        All
                    </div>
                    <div class="right-col" style="padding-right:15px;">
                        <input type="radio" value="F" name="status"/>
                        Finalized
                    </div>
                    <div class="right-col" style="padding-right:15px;">
                        <input type="radio" value="C" name="status"/>
                        Non-Finalized
                    </div>
                    <div class="right-col" style="padding-right:15px;">
                        <input type="radio" value="S" name="status"/>
                        Pending
                    </div>
                    <div class="right-col" style="padding-right:15px;">
                        <input type="radio" value="E" name="status"/>
                        Errors
                    </div>
                </div>--%>

                <div class="line">
                    <div class="left-col">Available Reports:</div>
                    <div id="available-reports" class="right-col">
                        <select name="report_number">
                        </select>
                    </div>
                    <div id="available-report" class="right-col"></div>
                </div>

                <div style="padding: 5px 0px 10px 0px;">
                    <div class="left-col">Offices:</div>
                    <div class="right-col">
                        <select name="officeobjectid" onchange="report_selected($(this).val())">
                        </select>
                    </div>
                </div>

                <div class="line">
                    <div class="left-col" style="">
                        Job ID:
                    </div>
                    <div class="right-col">
                        <input type="text" name="job_id" />
                    </div>
                </div>

                <div class="line">
                    <div class="left-col" style="">
                        Request ID:
                    </div>
                    <div class="right-col">
                        <input type="text" name="report_id" />
                    </div>
                </div>

                <div class="line" style="padding-top: 10px;">
                    <div class="left-col"></div>
					<div class="right-col">Retrieve Reports Taken Between the following Dates (inclusive)</div>
				</div>	
				<div class="line">
                    <div class="left-col">Start:</div>
                    <div class="right-col">
                        <input type="text" name="start_date" id="start_date" maxlength="10"
                                placeholder="mm/dd/yyyy" style="width:80px;" /> (mm/dd/yyyy)
                    </div>
                    <div class="left-col" style="width:50px;">End:</div>
                    <div class="right-col">
                        <input type="text" name="end_date" id="end_date" maxlength="10" 
                                placeholder="mm/dd/yyyy" style="width:80px;" /> (mm/dd/yyyy)
                    </div>
                </div>

                <div style="text-align:center; margin-top:10px;">
                    <input type="button" id="btnSubmit" value="Continue" onclick="GetReportList();" />
                </div>
            </div>
        </div>

        <div id="report-list-div" style="display:none;">
            <div style="text-align: center; padding-bottom: 20px; ">
                <input type="button" value="New List / Menus"  style="width:30%; padding: 5px;" onclick="DisplayReportFilter(true);" />
            </div>
            <div class="rpt-heading" id="rpt-heading">
<%--                <div class="retrieve">Retrieve</div>
                <div class="job_id" style="text-align:center;">Auto Run Id</div>
                <div class="rpt_desc" >Report Name</div>
                <div class="office">Office</div>
                <div class="request_id">Id</div>
                <div class="run_dt">Run Date</div>
                <div class="status">Status</div>
                <div class="user_name">Requested By</div>--%>
            </div>
            <div class="box" id="display-list" style="padding: 0px; min-height:20px;"></div>
        </div>

        <div id="report-div" style="display:none">
            <div style="text-align: center; padding-bottom:10px;">
                <input type="button" name="btnBack" value="Report List" style="width:20%; padding: 5px;" onclick="DisplayReportList(true);" />
                <input type="button" value="New List / Menus" style="width:20%; padding: 5px;" onclick="DisplayReportFilter(true);" />
                <input id="print-report-btn" type="button" value="Print Report" style="width:20%; padding: 5px;" onclick="printdiv('report');" />
<%--                <input type="button" value="New List" onclick="jQuery('#report-list-div').hide(); jQuery('#report-div').hide(); jQuery('#select-div').show(); DisplayNavigation(true);" />--%>
				<input id="print-preview-btn" type="button" value="Print / Print Preview"
						style="width: 20%; padding: 5px; display: none;"
						onclick="printpreview('report-div');" />
			</div>

            <div id="report"></div>

            <%--<div id="btns-div" style="text-align:center; padding:10px 0px;">
                <input type="button" id="btnExport" name="btnExport" value="Export to Excel" onclick="getExcel(currRow);"  />--%>
                <%--<a href="#" download="data.csv" id="btnExport">Export data into Excel</a>--%>
            <%--</div>--%>

        </div>
<%--        <div>
            <input type="button" value="Print" onclick="printdiv('report');" />
        </div>--%>
    </div>

<%--    <table border="1" style="margin:0px;">
        <thead>
            <tr>
                <th>
                    District Name
                </th>
                <th>
                    Number
                </th>
            </tr>
        </thead>
        <tbody>
            <tr>
                <td>
                    xyz
                </td>
                <td>
                    25
                </td>
            </tr>
        </tbody>
    </table>
--%>
</asp:Content>
