<%@ Page Title="" Language="C#" MasterPageFile="~/Screens/SiteNav.master" AutoEventWireup="true" CodeBehind="StudentInfo.aspx.cs" Inherits="LEADMaintenance.Screens.StudentInfo" %>

<%@ MasterType VirtualPath="~/Screens/SiteNav.Master" %>

<asp:Content ID="Content1" ContentPlaceHolderID="head" runat="server">
	<script type="text/javascript" src="../JavaScript/validator.js"></script>
	<script type="text/javascript" src="../JavaScript/StudentInformation.js"></script>

	<style type="text/css">
		#roster-tbl 		{ border-collapse: collapse; background-color:#daeaee; border-radius: .3em; }
		tr					{ vertical-align:top; }
		#roster-tbl > tbody > tr > td	{ padding: 5px; }
		#roster-tbl > tbody > tr:nth-child(odd)	{ background-color: #96c4cf}
		#roster-tbl > tbody > tr > td:nth-of-type(1)  { width: 30px; text-align:center; }
		td:nth-of-type(2)  { width: 30px; text-align:center; }
		td:nth-of-type(3)	{ width: 70px; text-align:center; }
		td:nth-of-type(4)	{ width: 150px; }
		td:nth-of-type(5)	{ width: 200px; }
		td:nth-of-type(6)	{ width: 150px; }
		td:nth-of-type(7)	{ width: 70px; text-align:center; }
		td:nth-of-type(8)	{ visibility: hidden; }
		td:nth-of-type(9)	{  }

		
		tr:last-child > td:first-child		{ border-bottom-left-radius: .3em; }
		tr:last-child > td:last-child		{ border-bottom-right-radius: .3em; }
		thead				{ background-color: #04a8cf; color: #e5f0f3; }
		th:first-child		{ border-top-left-radius: .3em; }
		th:last-child		{ border-top-right-radius: .3em; }
	</style>
</asp:Content>
<asp:Content ID="Content2" ContentPlaceHolderID="main" runat="server">
	<asp:HiddenField runat="server" ID="studentobjectid" />

	<div class="content">
		<div class="title">Student Information</div>
		<div style="margin-bottom: .5em; font-size: 1.2em; font-weight: bold;">
			<div style="width: 100%; text-align: center;">
			<asp:Literal ID="classtimeexpression" runat="server"></asp:Literal>
		</div>
		</div>
		<div style="margin-bottom: .5em; padding-left: 4em; font-size: 1.2em; font-weight: bold;">
			<asp:Literal ID="district" runat="server"></asp:Literal>
		</div>
		<div style="width: 100%;">
			<div style="padding-left: 6em; display: inline-block; width: 40%">
				<asp:Literal ID="location" runat="server"></asp:Literal>
			</div>
			<div style="display: inline-block; width: 40%">
			</div>
		</div>
		<div style="margin: 1em 0; color: #670000; font-weight: bold;">
			<div style="display:inline-block; width: 55%; vertical-align:top;">
				<ul style="vertical-align:top; margin:0; ">
					<li>CR - Completed Registration</li>
					<li>SB - On Stand By List</li>
					<li>CN - Confirmation Number</li>
				</ul>
			</div>
			<div style="display: inline-block; width: 40%; text-align:justify; font-weight:normal;">
				When the Send check box is checked to send a certificate, on average it could take
				up to 6 minutes to process but could take as much as 45 minutes to be processed
			</div>
		</div>
		<div runat="server" id="rosterTable">
			<table id="roster-tbl" style="margin: auto;">
				<thead>
					<tr>
						<th>CR</th>
						<th>SB</th>
						<th>CN</th>
						<th>Student Name</th>
						<th>Email Address</th>
						<th>Pass/Fail</th>
						<th>Send</th>
					</tr>
				</thead>
				<tbody id="tbody">
					<asp:PlaceHolder runat="server" ID="studentinfo" ClientIDMode="Static" ViewStateMode="Enabled">
					</asp:PlaceHolder>
				</tbody>
			</table>
		</div>
		<div style="text-align: center; margin: 1em 0">
			<div id="buttons" runat="server" style="display: inline-block; padding-right: .5em;">
				<span style="padding-right: 6em;"><asp:CheckBox runat="server" ID="autorefresh" Text=" Auto Re-fresh Status" TextAlign="Right" /></span>
				<span><asp:Button runat="server" ID="submit" Text="Submit" OnClick="submit_Click"
									OnClientClick="if (!valRosterChanges()) return false; $('#modal').modal(); document.body.style.cursor  = 'wait';" /></span>
				<span><asp:Button runat="server" ID="refresh" Text="Refresh Status" OnClick="refresh_Click" /></span>
			</div>

			<div style="display: inline-block; padding-left: .5em;">
				<asp:Button runat="server" ID="back" Text="Student Search" OnClientClick="window.location='StudentSearch.aspx'; return false;" />
				<asp:Button runat="server" ID="exit" Text="Exit" OnClientClick="window.location='Main.aspx'; return false;" />
			</div>
		</div>

		<div runat="server" id="msg" style="text-align: center; font-size: 1.3em;">
		</div>
	</div>
</asp:Content>
