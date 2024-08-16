<%@ Page Title="Unregister Student" Language="C#" MasterPageFile="~/Screens/SiteNav.master" AutoEventWireup="true" CodeBehind="UnregisterStudent.aspx.cs" Inherits="RegisterStudent.Screens.UnregisterStudent" %>
<%@ MasterType VirtualPath="~/Screens/SiteNav.Master" %>

<asp:Content ID="Content1" ContentPlaceHolderID="head" runat="server">
	<%--<script type="text/javascript" src="../JavaScript/jquery-2.1.1.js"></script>--%>
	<script type="text/javascript" src="../JavaScript/validator.js"></script>
	<script type="text/javascript" src="../JavaScript/UnregisterStudent.js"></script>
	<style type="text/css">
		body				{ background-color: rgba(255, 255, 255, 1.0); }
		header				{ text-align: center; padding: 15px; margin-bottom: 1em; 
							  border-top-left-radius: 15px; border-top-right-radius: 15px;
							  background-color: #990000; color: #ffffff; font-weight: bold; font-size:1.3em; }
		tr>td:first-child	{ text-align: right; padding-right: 1em;}
		#message			{ padding: 1em 2em; color: #800b0b; }
	</style>

	<title>LEAD - Unregister Student</title>
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="main" runat="server">
	<div>
		<div class="title">
			LEAD Class Unregister Student
		</div>

		<div id="request" runat="server">

			<ul style="padding-left: 4em; color: #800b0b;">
				<li>You must enter your email address.  This is a required field.</li>
				<li>Please enter your confirmation number if you know it.</li>
				<li>Confirmation Number is required if you have registered in other LEAD Classes.
				</li>
			</ul>

			<table style="width: 80%; margin: auto;">
				<tbody>
					<tr>
						<td>
							<asp:Literal runat="server" ID="lbName" Visible="false">Name:</asp:Literal></td>
						<td>
							<asp:Literal runat="server" ID="txtName" ></asp:Literal>
						</td>
					</tr>
					<tr>
						<td>Email Address:</td>
						<td>
							<asp:TextBox runat="server" ID="txtEmailAddress" Width="300" ClientIDMode="Static"></asp:TextBox>
						</td>
					</tr>
					<tr>
						<td>Confirmation Number:</td>
						<td>
							<asp:TextBox runat="server" ID="txtConfirmationNumber" Width="60" ClientIDMode="Static"></asp:TextBox>
						</td>
					</tr>
				</tbody>
			</table>

			<div style="text-align: center; margin-top: 1em;">
				<div style="display:inline-block; padding-right:1em;">
					<asp:Button runat="server" ID="btncancel" Text="exit" UseSubmitBehavior="false" Width="120"/>
				</div>
				<div style="display: inline-block; padding-left: 1em;">
					<asp:Button runat="server" ID="unregister" Text="Unregister" OnClick="unregister_Click"
						Width="120"
						OnClientClick="if (confirm('Are you sure you want to unregister from your class')) { if (ValInput()) { $('#modal').modal(); document.body.style.cursor  = 'wait';} else return false; } else return false;" />
				</div>
			</div>
		</div>

		<div id="message">
			<asp:Literal runat="server" ID="litMessage" />
		</div>

		<div id="msgresults" runat="server" visible="false">
			<div style="text-align: center; margin-top: 1em;">
				<asp:Button runat="server" CssClass="button" Text="Exit" ID="btnexit" />
			</div>

		</div>
	</div>
</asp:Content>
