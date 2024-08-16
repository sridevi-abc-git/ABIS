<%@ Page Title="Student Registration" Language="C#" MasterPageFile="~/Screens/SiteNav.master"
	AutoEventWireup="true" CodeBehind="StudentInformation.aspx.cs" Inherits="RegisterStudent.Screens.StudentInformation" %>
<%@ MasterType VirtualPath="~/Screens/SiteNav.Master" %>


<asp:Content ContentPlaceHolderID="head" runat="server">
	<script type="text/javascript" src="../JavaScript/jquery.autotab.min.js"></script>
	<script type="text/javascript" src="../JavaScript/validator.js"></script>
	<script type="text/javascript" src="../JavaScript/StudentInformation.js"></script>
	<script src="https://www.google.com/recaptcha/api.js"></script>
	<style type="text/css">
		.left	{ display:inline-block; width: 200px; text-align:right; padding: 0px 10px 15px 0px; vertical-align: top; }
		.right  { display:inline-block; padding-bottom: 15px; vertical-align:top; }

        .flashit{
	        -webkit-animation: flash linear 2s infinite;
	        animation: flash ease-in-out 2s infinite;
        }
        @-webkit-keyframes flash {
	        0% { opacity: 1; } 
            40% { opacity: 1; }
	        50% { opacity: .1; } 
            90% { opacity: .0; } 
	        100% { opacity: 1; }
        }
        @keyframes flash {
	        0% { opacity: 1; } 
            80% { opacity: 1; }
	        81% { opacity: .0; }
            99% { opacity: .0; } 
	        100% { opacity: 1; }
        }

	</style>
</asp:Content>

<asp:Content ContentPlaceHolderID="main" runat="server">
	<asp:HiddenField runat="server" ID="classobjectid" />
		<div runat="server" id="title" class="title">
		</div>
	<div style="margin:2em;">
		<div runat="server" id="standbymessage" style="text-align:center; color: #620000; font-size:1.1em; margin-bottom:.5em;">
			This registration is for the standby list only. This does <i>NOT</i> guarantee a seat in the selected class.
		</div>

		<div runat="server" id="msg" class="flashit" style="text-align: center; font-size: 2em; padding-bottom:1em;" clientidmode="Static"></div>

		<div style="margin-bottom:.5em; font-size: 1.2em; font-weight:bold;">
			<div style="width: 30%; display:inline-block;">
				LEAD Class:
			</div>
			<div style="width:65%; display:inline-block; text-align:right;" >
				<asp:Literal ID="classtimeexpression" runat="server"></asp:Literal>
			</div>
		</div>
		<div>
			<asp:Literal ID="location" runat="server"></asp:Literal>
		</div>
		<div style="padding-top:.5em;">
			Available Seats: <asp:Literal ID="spotsavailable" runat="server"></asp:Literal>
		</div>

		<div style="margin-top:2em;">
			<div style="vertical-align: top;">
				<div class="left">Name:</div>
				<div class="right">
					<div><asp:TextBox runat="server" ID="firstName" ClientIDMode="Static" /></div>
					<div>First</div>
				</div>
				<div class="left" style="width:1px;"></div>
				<div class="right">
					<div><asp:TextBox runat="server" ID="lastName" ClientIDMode="Static" /></div>	
					<div>Last</div>
				</div>
			</div>
		
		</div>
		<div>
			<div class="left">
				Cell Phone #:
		    </div>
			<div class="right">
				<asp:HiddenField runat="server" ID="cellPhone" ClientIDMode="Static" />
				<div style="display:inline-block;"><asp:TextBox runat="server" ID="cellPhone1" ClientIDMode="Static" Width="30" placeholder="###" MaxLength="3" /></div>
				<span> - </span>
				<div style="display: inline-block;"><asp:TextBox runat="server" ID="cellPhone2" ClientIDMode="Static" Width="30" placeholder="###" MaxLength="3" /></div>
				<span> - </span>
				<div style="display: inline-block;"><asp:TextBox runat="server" ID="cellPhone3" ClientIDMode="Static" Width="40" placeholder="####" MaxLength="4" /></div>
			</div>
		</div>
		<div>
			<div class="left">
				Email Address:
		    </div>
			<div class="right">
				<asp:TextBox runat="server" ID="email2" onpaste="return false" Width="250" ClientIDMode="Static" />
				<asp:HiddenField runat="server" ID="email" ClientIDMode="Static" />
			</div>
		</div>
		<div>
			<div class="left">
				Re-Enter Email Address:
		    </div>
			<div class="right">
				<asp:TextBox runat="server" ID="reemail2" onpaste="return false" Width="250" ClientIDMode="Static" />
				<asp:HiddenField runat="server" ID="reemail" ClientIDMode="Static" />
			</div>
		</div>

		<div>
			<div class="left"></div>
			<div class="right">
				<div class="g-recaptcha" data-sitekey="<%=System.Configuration.ConfigurationManager.AppSettings["SiteKey"] %>"></div>
			</div>

		</div>

		<div style="text-align: center; margin-top:2em; margin-bottom:1.5em;">
			<asp:Button runat="server" CssClass="button" Text="Back" PostBackUrl="~/Screens/AvailableClasses.aspx" />
			<asp:Button runat="server" CssClass="button" Text="Submit" OnClick="submit_Click" 
						OnClientClick="if (!ValInput()) return false; $('#modal').modal(); document.body.style.cursor  = 'wait';" />
			<asp:Button runat="server" CssClass="button" Text="Exit"   ID="btnexit" />
		</div>
		
	</div>
</asp:Content>
