<%--*******************************************************************************************
//    File:         ReportRequestLog.aspx         
//    Author:       Timothy J. Lord
//    
//    Description:  
//    		 
//    $Rev: 51 $   $Date: 2018-09-01 12:02:56 -0700 (Sat, 01 Sep 2018) $
//    Modified By: $Author: TLord $
//*******************************************************************************************
//  History:
//     Date  Developer  Ticket		Comment
//----------------------------------------------------------------------------------
//  06/16/2015  TJL      7454	  Initial file created
//*******************************************************************************************--%>

<%@ Page Title="Report Request Log" Language="C#" MasterPageFile="~/Screens/SiteNavigation.master" 
		 AutoEventWireup="true" CodeBehind="ReportRequestLog.aspx.cs" 
		 Inherits="RQS.Screens.RequestReportsLog" 
%>
<asp:Content ID="Content1" ContentPlaceHolderID="head" runat="server">
	<script type="text/javascript" src="../JavaScript/validator.js"></script>
	<script type="text/javascript" src="../Javascript/ReportRequestLog.js"></script>

	<style type="text/css">
		.search
		{
			margin:2.5em auto;
			width:80%;
		}

		fieldset.search table								{ border-width: 0; }
		fieldset.search table > tbody > tr					{ background-color: #fff; }
		fieldset.search table > tbody > tr > td:first-child
		{
			text-align:right;
			padding-right:0.8em;
			padding-left:2em; 
			width: 110px; 
		}
		fieldset.search table > tbody > tr:hover				{ cursor:default; background-color: transparent; color:inherit; }

		.info, .results
		{
			margin:1em auto;
			width:100%;
		}

		fieldset.results table									{ margin: auto; width:100%; }
		fieldset.results table > tbody > tr > td:first-child	{ text-align:center; }
		fieldset.results table > thead > tr > th				{ text-align: left; text-indent: 2em; }
		fieldset.results										{ background-color: transparent; }
	</style>

</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
	<div id="user-log" style="margin: 10px;">
		<input type="hidden" name="connection" id="connection" class="return" />
		<input type="hidden" name="user_role" id="user_role" class="return" />

		<div class="page-heading">Request Logs</div>

		<%--********************************************************************************
			*	User Search Panel
			********************************************************************************--%>
		<div style="position: relative;">
			<div id="user-search" class="search">
				<fieldset class="shadow search" style="position: absolute; z-index: 1;">

					<header style="margin-bottom: 1em;">
						Retrieve User Request Logs by User Name
					</header>

					<div id="info" style="padding-right:3em; color:#760000;">
						<ul>
							<li>Look up by full name (First and Last) or by a partial match where the input value 
								will match anywhere within the first or last name.</li>
						</ul>
					</div>

					<table>
						<tbody>
							<tr style="height: 2.5em; vertical-align: top;">
								<td>User Name:</td>
								<td colspan="3">
									<input type="text" name="value" /></td>
							</tr>


							<tr style="padding-top: 10px;">
								<td></td>
								<td colspan="3">Reports Requested Between the following Dates (inclusive)
								</td>
							</tr>
							<tr>
								<td>Start:</td>
								<td>
									<input type="text" name="start_date" id="start_date" maxlength="10"
										placeholder="mm/dd/yyyy" style="width: 80px;" />
									(mm/dd/yyyy)
								</td>
								<td style="width: 50px;">End:</td>
								<td>
									<input type="text" name="end_date" id="end_date" maxlength="10"
										placeholder="mm/dd/yyyy" style="width: 80px;" />
									(mm/dd/yyyy)
								</td>
							</tr>


						</tbody>
					</table>

					<div style="padding: 20px; margin: 0px; text-align: center;">
						<input type="submit" value="Continue" onclick="GetLogs(); return false" />
					</div>
				</fieldset>

			</div>
		</div>

		<div style="margin: 0px;">
			<%--********************************************************************************
				*	User request Results 
				********************************************************************************--%>
			<fieldset id="user-log-results" class="results no-display">
				<table>
					<thead>
						<tr>
							<th style="padding-left: 1.5em;">User Name</th>
							<th>Report Description	</th>
							<th>Requested Date</th>
							<th>Request Id</th>
							<th>Report Id</th>
							<th>Order By</th>
						</tr>
					</thead>
					<tbody id="tbody_results">
					</tbody>
				</table>
				<div style="text-align: center; padding-top: 10px;">
					<input type="button" value="Search" onclick="DisplayUserSearch(true)" />
				</div>
			</fieldset>

		</div>
	</div>

</asp:Content>

