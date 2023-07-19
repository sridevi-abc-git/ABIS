<%--
//**********************************************************************************
//	File:			UserMaintenance.aspx
//	Author:			Timothy J. Lord
//
//  Districption:
//
//  $Rev: 51 $   $Date: 2018-09-01 12:02:56 -0700 (Sat, 01 Sep 2018) $
//  Modified By: $Author: TLord $
//
//**********************************************************************************
//  History:
//     Date  Developer  
//----------------------------------------------------------------------------------
//  01/14/2015  TJL      Ticket 6197
//**********************************************************************************
--%>

<%@ Page Title="Add - Remove Users" Language="C#" MasterPageFile="~/Screens/SiteNavigation.master"
		 AutoEventWireup="true" CodeBehind="UserMaintenance.aspx.cs" Inherits="RQS.Screens.UserMaintenance" %>

<asp:Content ID="Content1" ContentPlaceHolderID="head" runat="server">
	<script type="text/javascript" src="../JavaScript/validator.js"></script>
	<script type="text/javascript" src="../JavaScript/UserMaintenance.js"></script>

	<style type="text/css">
		.search
		{
			margin:2.5em auto;
			width:60%;
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

		fieldset.results table									{ margin: auto; width:95%; }
		fieldset.results table > tbody > tr > td:first-child	{ text-align:center; }
		fieldset.results table > thead > tr > th				{ text-align: left; text-indent: 2em; }
	</style>

</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
	<div id="user-maintenance" style="margin: 10px; ">
		<input type="hidden" name="connection" id="connection" class="return" />
		<input type="hidden" name="user_role" id="user_role" class="return" />
		<input type="hidden" name="office_id" id="office_id" class="return" />

		<div class="page-heading">User Maintenance</div>

		<div id="info">
			<ul>
				<li>To add a user to the Report Query System, the user must have an active ABIS user id.</li>
				<li>When a user is removed (deleted) from the Report Query System, they are NOT removed from ABIS</li>
				<li>While in the User Maintenance Screens do NOT use the browser back button.</li>
				<li>Click on 'Continue' to lookup a user to Add, Edit, or Remove</li>
			</ul>
			<div style="padding: 10px; margin: 0px; text-align: center;">
				<input type="button" value="Continue" onclick="DisplayUserSearch(true); return false" />
			</div>
		</div>
			<%--********************************************************************************
			*	User Search Panel
			********************************************************************************--%>
			<div style="position:relative;">
				<div id="user-search" class="search no-display">
					<fieldset class="shadow search" style="position:absolute; z-index:1;">
							
						<header style="margin-bottom: 1em;">
							Search for ABIS / RQS user
						</header>
						
						<div>
							<div style="height:2.5em; vertical-align:top;">
								<div style="display:inline-block; width:150px; text-align:right; padding-right:2em;">Search By:</div>
								<div style="display: inline-block;">
									<input type="radio" name="search_by" value="N" checked="checked" />Name
									<input type="radio" name="search_by" value="U" />User Id
									<input type="radio" name="search_by" value="E" />Email Address
								</div>
							</div>
							<div id="office-div" class="no-display" >
								<div style="display: inline-block; width: 150px; text-align: right; padding-right: 2em;">Office:</div>
								<div style="display: inline-block;">
									<select id="selected_office" name="selected_office">
									</select>
								</div>
							</div>
							<div>
								<div style="display: inline-block; width: 150px; text-align: right; padding-right: 2em;">Search:</div>
								<div style="display: inline-block;"><input type="text" name="value" /></div>
							</div>
						</div>
						
						<div style="padding: 20px; margin: 0px; text-align: center;">
							<input type="submit" value="Continue" onclick="GetUser(); return false" />
						</div>
					</fieldset>

				</div>
			</div>
		
			<div style="margin: 0px;">
				<%--********************************************************************************
				*	User Search Results and Select Panel
				********************************************************************************--%>
				<fieldset id="user-list" class="results no-display shadow" style="">
					<div style="padding:15px 0px 15px 35px; font-size:14pt; color:#6c0101">
						Click on user to display user information
					</div>
					<table>
						<thead>
							<tr>
								<th style="width:2em; text-indent:0em; padding-left:1.5em;">User Role</th>
								<th>Name</th>
								<th>Office</th>
								<th>Email Address</th>
							</tr>
						</thead>
						<tbody id="tbody_results">
						</tbody>
					</table>
					<div style="text-align: center; padding-top: 10px;">
						<input type="button" value="Search" onclick="DisplayUserSearch(true)" />
					</div>
				</fieldset>

				<%--********************************************************************************
				*	User Info Panel
				********************************************************************************--%>
				<div id="user-information" class="info no-display">
					<div class="rpt-heading">User Information</div>
					<div class="box" style="margin: auto; min-height: 400px;">
						<div style="width:100%;">
						<div style="display: inline-block; width: 49%;">
							<table>
								<tbody>
									<tr>
										<td>Name:</td>
										<td id="t_name"></td>
									</tr>
									<tr>
										<td>User Id:</td>
										<td id="t_user_id"></td>
									</tr>
									<tr>
										<td>Email Address:</td>
										<td id="t_email_address"></td>
									</tr>
									<tr>
										<td>Office:</td>
										<td id="t_office"></td>
									</tr>
									<tr id="tr_user_role" class="no-display">
										<td>User Role:</td>
										<td>
											<select id="t_user_role">
												<option value="">Select User Role</option>
												<option value="U">User</option>
												<option value="M">Manager</option>
												<option value="S">Super User</option>
												<option value="I">IT User</option>
											</select>
										</td>
									</tr>
								</tbody>
							</table>
						</div>
						<div style="display: inline-block; width: 49%; vertical-align: top; ">
							<p>
								Click on report to enable or disable user access to the report.
							</p>
							<fieldset class="" style="margin: 0em auto; background-color:transparent;">
								<table style="width: 100%; padding:0px;">
									<thead>
										<tr>
											<th style="width:80%">Available Reports</th>
											<th style="width:20%"></th>
										</tr>
									</thead>
									<tbody id="report-list" ></tbody>
								</table>
							</fieldset>
						</div>

					</div>
					<div>
						<div style="text-align: center; padding-top: 10px; display: inline-block; width: 49%;">
							<input type="button" value="Search" onclick="DisplayUserSearch(true)" />
							<input type="button" name="user-list" value="User List" onclick="DisplayUserList(true)" />
						</div>
						<div style="text-align: center; padding-top: 10px; display:inline-block; width:49%;">
							<input type="button" name="add-update" onclick="UserUpdate(this);" />
							<input type="button" name="delete" value="Remove User" onclick="UserUpdate(this);" />
						</div>
					</div>
				</div>

			</div>
		</div>
	</div>

</asp:Content>
