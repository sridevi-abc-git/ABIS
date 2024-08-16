<%@ Page Title="LEAD Confirmation" Language="C#" MasterPageFile="~/Screens/SiteNav.master" AutoEventWireup="true" CodeBehind="Confirmation.aspx.cs" Inherits="RegisterStudent.Screens.Confirmation" %>
<%@ MasterType VirtualPath="~/Screens/SiteNav.Master" %>


<asp:Content ContentPlaceHolderID="head" runat="server">

</asp:Content>

<asp:Content ContentPlaceHolderID="main" runat="server">
	<div runat="server" id="title" class="title">
	</div>
	<div style="margin:0 3em 1em 3em;">
		<div runat="server" id="standbymessage" style="text-align: center; color: #620000;
			font-size: 1.3em; margin-bottom: .5em;">
			This registration is for the standby list only. This does <i>NOT</i> guarantee a
			seat in the selected class.
		</div>
		<div>
			<div style="margin-bottom: .5em; font-size: 1.3em;">
				<div style="width: 30%; display: inline-block;">
					LEAD Class:
				</div>
				<div style="width: 65%; display: inline-block; text-align: right;">
					<asp:Literal ID="classtimeexpression" runat="server"></asp:Literal>
				</div>
			</div>
			<div>
				<asp:Literal ID="location" runat="server"></asp:Literal>
			</div>

			<div style="margin:20px 0 0 0;">
				<div><asp:Literal ID="StudentName" runat="server" /></div>
				<div><asp:Literal ID="emailaddress" runat="server" /></div>
				<div>Confirmation Number: <asp:Literal ID="confirmationNumber" runat="server" /></div>
			</div>

			<div style="margin:20px 0 0 0;">
				Thank you for registering for the Licensee Education on Alcohol and Drugs (LEAD)
				Program. In the case that there is a cancellation or rescheduling of the class you
				will be notified via email.  
			</div>

			<div runat="server" id="msg2" style="font-size:1.3em; color:darkred;margin:20px 0;">
				If you do not receive a confirmation email within 24 hours please email <b>LEADinfo@abc.ca.gov.</b>
				Include your name, above confirmation number, date of class and contact telephone
				number.
			</div>

			<div runat="server" id="msg" style="text-align: center; font-size: 1.3em; margin: 20px 0;">
			</div>

			<div style="text-align: center;">
				<asp:Button runat="server" CssClass="button" Text="Exit" ID="btnexit" />
			</div>
		</div>
	</div>
</asp:Content>
