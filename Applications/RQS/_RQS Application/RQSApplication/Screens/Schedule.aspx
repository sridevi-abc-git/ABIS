<%--*******************************************************************************************
//    File:         Schedule.aspx         
//    Author:       Timothy J. Lord
//    
//    Description:  
//    		 
//    $Rev: 429 $   $Date: 2020-04-28 07:23:43 -0700 (Tue, 28 Apr 2020) $
//    Modified By: $Author: TLord $
//*******************************************************************************************
//  History:
//     Date  Developer  
//----------------------------------------------------------------------------------
//  01/13/2015  TJL      Ticket 6193
//  08/18/2015  TJL	 7770  - fixed displaying office when it should be hidden
//*******************************************************************************************--%>
<%@ Page Title="Request - Schedule Reports" Language="C#" MasterPageFile="~/Screens/SiteNavigation.master" 
		 AutoEventWireup="true" CodeBehind="Schedule.aspx.cs" Inherits="RQS.Screens.Schedule" 
%>

<asp:Content ID="Content1" ContentPlaceHolderID="head" runat="server">
    <script type="text/javascript" src="../JavaScript/Schedule.js"></script>
	<style type="text/css">
		.status-columns					{ display: inline-block; padding: 2px 2px 2px 5px; border:1px solid black;}
		td								{ text-align: left; }
		#report-output-type>div			{ display:inline-block; padding-left: 10px;}
		#request-msg					{ background-color: #F1FBFD; border-radius: 10px; padding: 1em; margin: auto; }
		#request-msg>table				{ margin: auto; }
		#request-msg td					{ padding-left: .2em; }
		#request-msg td:nth-child(1)	{ width:  20px; }
		#request-msg td:nth-child(2)	{ width:  80px; text-align: right; }
		#request-msg td:nth-child(3)	{ width: 300px; }
		#request-msg td:nth-child(4)	{ width: 300px; }

		.completed					{ color: #074600; }
		.wait						{ color: #6B4100; }
		.err						{ color: #ff0000; }
		.processing					{ color: #0000ff; }
	</style>
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <div style="margin: 10px;">

		<div id="rpt-desc" class="rpt-heading" style="font-size: 16pt;">
			Request / Schedule Reports
		</div>
		<div id="input-area" class="box">
			<input type="hidden" name="email_filename" class="return" />
			<div style="padding: 5px 0px 20px 0px;" class="no-display">
				<div class="left-col">Reports:</div>
				<div class="right-col">
					<select name="report_number" onchange="initInput(m_reportControlParameters)">
						<option value="0" >Please select report</option>
					</select>
				</div>
			</div>

			<div id="input-section" class="no-display">
				<div style="padding:0em 1em 1em 1em; margin: 1em auto 0 auto; width:80%;">
					<div id="report-name" class="rpt-heading" style="font-size: 16pt;">
					</div>
					<div class="box" >
						<div style="text-align:center;">
							<h2 style="margin:0 0 .5em 0; padding:0;"> Report Parameters</h2>
						</div>

						<div class="no-display"> <%--if more than one office display report is not a group only report--%>
							<div class="left-col">Offices:</div>
							<div class="right-col">
								<select id="officeobjectid" name="officeobjectid" onchange="office_selected($(this).val())">
									<option value="0">Please select office</option>
								</select>
							</div>
						</div>

						<div class="no-display" style="margin-top: .1em;">
							<div class="left-col">
								<input type="checkbox" value="Y" name="by_office_flg" onclick="by_office_flg_onclick(this)" />
								<input type="checkbox" value="N" name="by_office_flg" hidden="hidden" checked="checked" />
							</div>
							<div class="right-col">Individual District Reports:
							</div>
						</div>

						<%--following block determine by input parametes--%>
						<div class="no-display" style="margin-top: .2em;">
							<div class="left-col">Report Date:</div>
							<div class="right-col">
								<input type="text" name="report_date" id="report_date" maxlength="10"
									placeholder="mm/dd/yyyy" style="width: 80px;" />
								(mm/dd/yyyy)
							</div>
						</div>

						<div class="no-display">
							<div class="left-col">Year:</div>
							<div class="right-col">
								<input type="text" id="year" name="year" maxlength="4" style="width: 50px;" required="required"
									placeholder="yyyy" />
							</div>
						</div>

						<div class="no-display">
							<div class="left-col">Start Date:</div>
							<div class="right-col">
								<input type="text" name="start_date" id="start_date" maxlength="10"
									placeholder="mm/dd/yyyy" style="width: 80px;" />
								(mm/dd/yyyy)
							</div>
						</div>

						<div class="no-display">
							<div class="left-col">End Date:</div>
							<div class="right-col">
								<input type="text" name="end_date" id="end_date" maxlength="10"
									placeholder="mm/dd/yyyy" style="width: 80px;" />
								(mm/dd/yyyy)
							</div>
						</div>

						<div class="no-display">
							<div class="left-col">Comment:</div>
							<div class="right-col">
								<input type="text" name="user_comment" id="user_comment" maxlength="50"
									style="width: 300px;" />
							</div>
						</div>

			            <div style="padding: 5px 0px 1px 0px;" class="no-display">
				            <div class="left-col">Counties:</div>
				            <div class="right-col">
					            <select name="counties">
						            <option value="0" >Please select report</option>
					            </select>
				            </div>
			            </div>
						<div style="padding-top: .2em;" class="no-display">
							<div class="left-col">Census Tract:</div>
							<div class="right-col">
								<input type="text" name="censustract" id="censustract" style="width: 150px;" />
							</div>
						</div>

						<div style="padding-top: .2em;">
							<div class="left-col">Email Address:</div>
							<div class="right-col">
								<input type="text" name="email_to" id="email_to" style="width: 150px;" />
								@abc.ca.gov
							</div>
						</div>
					<%--</div>--%>

<%--				</div>

	
				<div style="border: solid 1px #000000; border-radius: 10px; padding: 0 1em 1em 1em; margin: 1em auto 0 auto; width:80%;">--%>
					<hr style="margin-top: 2em;" />

					<div style="margin-bottom: 1em; text-align: center;">
						<h2 style="margin:.5em 0 .2em 0; padding:0;">Report Output Options</h2>
					</div>
					<div style="margin-top: .2em;">
						<div>
							<input type="checkbox" value="Y" name="report_wait" checked="checked"
								onclick="uncheck('schedule_rpt'); uncheck('attach_report'); jQuery('#schedule-div', '#input-section').hide();" />
							Wait for report to complete
						</div>
					</div>
					<div style="margin-top: .2em;">
						<div>
							<input type="checkbox" value="Y" name="schedule_rpt"
								onclick="uncheck('report_wait'); (this.checked) ? jQuery('#schedule-div', '#input-section').show() : jQuery('#schedule-div', '#input-section').hide();" />
							Schedule Report:
						</div>
						<div id="schedule-div" class="no-display">
							<div>
								<div class="left-col" style="width: 75px;">Date:</div>
								<div class="right-col">
									<input type="text" name="schedule_date" id="schedule_date" style="width: 80px;" />
									(mm/dd/yyyy)
								</div>
								<div class="left-col" style="width: 60px;">Time:</div>
								<div class="right-col">
									<input type="text" name="schedule_time" id="schedule_time" style="width: 50px;" />
									(hh:mm) Military Time
								</div>
							</div>
						</div>
					</div>
					<div class="no-display" style="padding-left: 25px;">
						<div>
							Report output type
						</div>
						<div id="report-output-type"> 
						</div>
					</div>

					<div style="margin-top: .2em;">
						<div>
							<input type="checkbox" value="Y" name="attach_report"
							       onclick="uncheck('report_wait'); attach_report_onclick(this)" />
							Send report as an email attachment:
						</div>
<%--						<div class="no-display" style="text-indent:1em;">
							<input type="checkbox" value="Y" name="zip_report" />
							Attached report as a ZIP file.
						</div>--%>
					</div>

					<div class="no-display" style="margin-top: .2em;">
						<div>
							<input type="checkbox" value="Y" name="export" />
							Copy report by FTP:
						</div>
						<div id="ftp-input" class="no-display">
							<div>
								<div class="left-col">
									<input type="checkbox" value="FTP" name="export_zip" />
								</div>
								<div class="right-col">Zip Report</div>
							
							</div>

							<div>
								<div class="left-col">URL/HOST</div>
								<div class="right-col">
									<input type="text" id="url" name="url" maxlength="4" style="width: 50px;" />
								</div>
							</div>
							<div>
								<div class="left-col">Port #:</div>
								<div class="right-col">
									<input type="text" name="start_date" />
								</div>
							</div>

							<div>
								<div class="left-col">User:</div>
								<div class="right-col">
									<input type="text" name="ftp_user"  />						
								</div>
							</div>

							<div>
								<div class="left-col">Password:</div>
								<div class="right-col">
									<input type="text" name="ftp_password" />
								</div>
							</div>

							<div id="user_comment-div" class="no-display1">
								<div class="left-col">Output File Name:</div>
								<div class="right-col">
									<input type="text" name="file_name" />
								</div>
							</div>
						</div>

					</div>
				</div>
				</div>
				<div style="text-align: center; padding-top: 20px;">
					<input type="button" id="btnSubmit" value="Submit Request" onclick="SubmitRequest();" />
				</div>
				


			</div>
		</div>


        <div id="wait-div" style="display:none;">
            <%--<div id="request-report"class="rpt-heading" style="font-size:16pt;"></div>--%>
            <div class="box">
                <div id="request-id"></div>
                <div id="request-msg" style="margin:auto; text-align:center;"></div>
				<div style="text-align: center; padding: 10px 0px;">
					<input type="button" name="btnCancel" value="Cancel" style="width: 30%; padding: 5px;" />
					<input class="no-display" type="button" name="btnClosed" value="Closed" 
						   style="width: 30%; padding: 5px;" onclick="DisplayReportFilter(true)" />
				</div>
			</div>
        </div>
        <div id="report-div" style="display:none">
            <div id="report-div-btn" style="padding-bottom:10px; width: 100%; text-align:center;">
				<input type="button" value="New List / Menus" style="width:30%; padding: 5px;" onclick="DisplayReportFilter(true);" />
				<input id="print-preview-btn" type="button" value="Print / Print Preview" 
					   style="width: 30%; padding: 5px; display:none;" 
					   onclick="printpreview('report-div');" />
            </div>

            <div id="report"></div>
        </div>

    </div>
</asp:Content>
