

<%@ Page Title="LEAD Class Information" Language="C#" MasterPageFile="~/Screens/SiteNav.master"
	AutoEventWireup="true"
	CodeBehind="Information.aspx.cs" Inherits="RegisterStudent.Screens.Information"
	Async="true" %>
<%@ MasterType VirtualPath="~/Screens/SiteNav.Master" %>

<asp:Content ContentPlaceHolderID="head" runat="server">
	<style type="text/css">
		ul		  { margin-top: 0px; margin-bottom: 0px;  text-align:justify;}
		.heading  { margin-top: 1em; font-weight: bold; text-align:justify; }
		.main	  { width: 1000px;}
	</style>
</asp:Content>

<asp:Content ContentPlaceHolderID="main" runat="server">
	<div class="title">
		LEAD Class Information
	</div>
	<div style="padding: 0px 30px 10px 30px;">
		<div class="heading">
			The Licensee Education on Alcohol and Drugs (LEAD) Program is a free, voluntary
			prevention and education program for retail licensees, their employees and applicants.
			The curriculum is designed for licensees, managers and employees. Program length
			is 4 hours. Participation is limited depending on the size of the training location.
		</div>

		<div class="heading">Class Requirements:</div>
		<ul>
			<li>Must be on time (Late arrivals will not be admitted)</li>
			<li>Must be present the duration of entire training (4 hours)</li>
			<li>No cell phone use during class</li>
			<li>Bring your confirmation number or copy of confirmation email</li>
			<li>Bring a pen or pencil and notepad</li>
			<li>Must pass written exam to receive certificate of completion (written exam is offered
				in English)</li>
			<li>Bring your own interpreter if needed</li>
		</ul>

		<div class="heading">Registration Information:</div>
		<ul>
			<li>Your registration is not completed until you receive a confirmation email with
				your confirmation number.
			</li>
			<li>If class is full, you will still be able to register for the class but will
				be put on a standby list.  This does not guarantee that you will be able to take
				the class.  Do not contact the trainer or LEAD office to see if there is room for
				you to attend the class.  Until class starts, the trainer will not know how many
				students on the standby list will be added to the class or even if any will be added.
			</li>
			<li>The standby list will be used to fill the spots of students that registered
				but did not show up for the class. The students selected from the standby list will
				be in the order that they registered for the class.
			</li>
			<li>Email validation will be accomplished by sending a validation email to the
				email address entered on the registration page.  You will need to click on the link
				in the email in order to complete the registration process.  This link will take
				you to the registration confirmation page and also generate your confirmation email.
			</li>
			<li>All class notifications will be sent by email.</li>
		</ul>

		<div class="heading">Required Registration Information</div>
		<ul>
			<li>Your name, this will be how it will appear on your certificate (first, last)
			</li>
			<li>Valid Email address.</li>
			<li>Valid phone number.</li>
		</ul>

		<div style="text-align:center; margin-top:2em;">
			<asp:Button runat="server" CssClass="button" Text="Exit" ID="btnexit" />
			<asp:Button runat="server" CssClass="button" Text="Next" PostBackUrl="~/Screens/AvailableClasses.aspx"
						OnClientClick="$('#modal').modal(); document.body.style.cursor='wait';" />
		</div>

        <div style="text-align:center; margin-top:2em;">
            Comments or Questions: <a href="mailto:Leadinfo@abc.ca.gov">Leadinfo@abc.ca.gov</a>
        </div>

	</div>
</asp:Content>
