<%@ Page Title="" Language="C#" MasterPageFile="~/Screens/SiteNav.master" AutoEventWireup="true" CodeBehind="ClassRoster.aspx.cs" Inherits="LEADMaintenance.Screens.ClassRoster" %>

<%@ MasterType VirtualPath="~/Screens/SiteNav.Master" %>

<asp:Content ID="Content1" ContentPlaceHolderID="head" runat="server">
	<script type="text/javascript" src="../JavaScript/validator.js"></script>
	<script type="text/javascript" src="../JavaScript/StudentInformation.js"></script>

	<style type="text/css" >
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
		td:nth-of-type(8)	{ width: 70px; text-align:center; }
		td:nth-of-type(9)	{  }

		tr:last-child > td:first-child		{ border-bottom-left-radius: .3em; }
		tr:last-child > td:last-child		{ border-bottom-right-radius: .3em; }
		thead				{ background-color: #04a8cf; color: #e5f0f3; }
		th:first-child		{ border-top-left-radius: .3em; }
		th:last-child		{ border-top-right-radius: .3em; }

		.left	{ display:inline-block; width: 200px; text-align:right; padding: 0px 10px 15px 0px; vertical-align: top; }
		.right  { display:inline-block; padding-bottom: 15px; vertical-align:top; }
	</style>
</asp:Content>
<asp:Content ID="Content2" ContentPlaceHolderID="main" runat="server">
	<asp:HiddenField runat="server" ID="classobjectid" />

	<div class="content">

		<div style="margin-bottom: .5em; font-size: 1.2em; font-weight: bold;">
			<div class="title">
				LEAD Class
			</div>
			<div style="width: 100%; text-align: center;">
				<asp:Literal ID="classtimeexpression" runat="server"></asp:Literal>
			</div>
		</div>
		<div style="margin-bottom: .5em; padding-left: 4em; font-size:1.2em; font-weight:bold;">
			<asp:Literal ID="district" runat="server"></asp:Literal>
		</div>
		<div style="width:100%;">
			<div style="padding-left: 6em; display:inline-block; width:40%">
				<asp:Literal ID="location" runat="server"></asp:Literal>
			</div>
			<div style="display:inline-block; width:40%; vertical-align: top;">
				<div style="width: 100%;">
					<div style="display: inline-block; width: 40%;">Class Size:</div>
					<div style="display: inline-block; width: 20%; text-align:right;"><asp:Literal ID="classsize" runat="server"></asp:Literal></div>
				</div>
				<div style="width: 100%;">
					<div style="display: inline-block; width: 40%;">Students Attended:</div>
					<div style="display: inline-block; width: 20%; text-align: right;"><asp:Literal ID="studentsattended" runat="server"></asp:Literal></div>
				</div>
				<div style="width: 100%;">
					<div style="display: inline-block; width: 40%;">Students Register:</div>
					<div style="display: inline-block; width: 20%; text-align: right;"><asp:Literal ID="studentsregistered" runat="server"></asp:Literal></div>
				</div>
			</div>
		</div>

		<div id="addStudentPanel" class="addStudentPanel" runat="server">
			<div style="margin-top: 2em;">
				<div style="vertical-align: top;">
					<div class="left">Name:</div>
					<div class="right">
						<div>
							<asp:TextBox runat="server" ID="firstName" ClientIDMode="Static" /></div>
						<div>First</div>
					</div>
					<div class="left" style="width: 1px;"></div>
					<div class="right">
						<div>
							<asp:TextBox runat="server" ID="lastName" ClientIDMode="Static" /></div>
						<div>Last</div>
					</div>
				</div>

			</div>
			<div>
				<div class="left">
					Cell Phone #:
				</div>
				<div class="right">
					<asp:TextBox runat="server" ID="cellPhone" ClientIDMode="Static" Width="110" placeholder="#########" />
				</div>
			</div>
			<div>
				<div class="left">
					Email Address:
				</div>
				<div class="right">
					<asp:TextBox runat="server" ID="email" onpaste="return false" Width="250" ClientIDMode="Static" />
				</div>
			</div>
			<div>
				<div class="left">
					Re-Enter Email Address:
				</div>
				<div class="right">
					<asp:TextBox runat="server" ID="reemail" onpaste="return false" Width="250" ClientIDMode="Static" />
				</div>
			</div>

			<div style="text-align:center; padding: 1em;">
				<asp:Button runat="server" ID="addSubmit" OnClick="addSubmit_Click"
					OnClientClick="if (!ValNewStudent()) return false; $('#modal').modal(); document.body.style.cursor='wait';"
					Text="Submit" />
				<asp:Button runat="server" ID="addExit" OnClick="refresh_Click"
					Text="Exit" />
				<asp:Button runat="server" ID="addClear" OnClientClick="jQuery(':text', '.addStudentPanel').val('');jQuery('#msg').hide(); return false;"
					Text="Clear" />
			</div>
		</div>

		<div runat="server" id="roster" style="padding: 0 1em; margin: auto;">
			<div style="margin: 0 0 1em 0; ">
				<div style="color:#670000; font-weight:bold; display:inline-block; width: 48%;">
					<ul>
						<li>CR - Completed Registration</li>
						<li>SB - On Stand By List</li>
						<li>CN - Confirmation Number</li>
					</ul>
				</div>
				<div style="display:inline-block; width: 48%; text-align:left; vertical-align: text-bottom; ">
					<asp:Button runat="server" ID="addStudent" OnClick="addStudent_Click" 
						Text="Add Student" />
				</div>
			</div>
			<div runat="server" id="rosterTable">
				<table id="roster-tbl"  style="margin:auto">
					<thead>
						<tr>
							<th>CR</th>
							<th>SB</th>
							<th>CN</th>
							<th>Student Name</th>
							<th>Email Address</th>
							<th>Pass/Fail</th>
							<th>Send</th>
							<th>Delete</th>
						</tr>
					</thead>
					<tbody>
						<asp:PlaceHolder runat="server" ID="rosterinfo" ClientIDMode="Static" ViewStateMode="Enabled" ></asp:PlaceHolder>
					</tbody>
				</table>
			</div>
			<div style="text-align:center; margin:1em 0">
				<div id="buttons" runat="server" style="display:inline-block; padding-right:.5em;">
					<span style="padding-right:6em;"><asp:CheckBox runat="server" ID="autorefresh" Text=" Auto Re-fresh Status" TextAlign="Right"  /></span>
					<span><asp:Button runat="server" ID="submit" Text="Submit" OnClick="submit_Click"
							OnClientClick="if (!valRosterChanges()) return false; $('#modal').modal(); document.body.style.cursor  = 'wait';" /></span>
					<span><asp:Button runat="server" ID="refresh" Text="Refresh Status" OnClick="refresh_Click" /></span>
				</div>
			
				<div style="display: inline-block; padding-left: .5em;">
					<asp:Button runat="server" ID="back" Text="Class Search" OnClientClick="window.location='ClassSearch.aspx'; return false;" />
					<asp:Button runat="server" ID="exit" Text="Exit" OnClientClick="window.location='Main.aspx'; return false;" />
				</div>
			</div>
		</div>
		<div runat="server" id="msg" style="text-align: center; font-size: 1.3em;" clientidmode="Static">
		</div>
	</div>
</asp:Content>
