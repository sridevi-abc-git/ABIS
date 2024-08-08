<%@ Page Title="" Language="C#" MasterPageFile="~/Screens/SiteNav.master" AutoEventWireup="true" CodeBehind="Main.aspx.cs" Inherits="LEADMaintenance.Screens.Main" %>

<%@ MasterType VirtualPath="~/Screens/Site.Master" %>

<asp:Content ID="Content1" ContentPlaceHolderID="head" runat="server">
</asp:Content>
<asp:Content ID="Content2" ContentPlaceHolderID="main" runat="server">

	<div class="content" >
		
		<div class="title">Main Menu</div>
		<div>
			<ul>
				<li><asp:LinkButton runat="server" OnClientClick="$('#modal').modal(); document.body.style.cursor='wait';window.location='ClassSearch.aspx'; return false;"
						Text="Class Roster Maintenance"></asp:LinkButton></li>
				<li><asp:LinkButton runat="server" OnClientClick="$('#modal').modal(); document.body.style.cursor='wait';window.location='StudentSearch.aspx'; return false;"
						Text="Re-issue Student Certificate"></asp:LinkButton></li>
				<li><asp:LinkButton runat="server" OnClientClick="window.location = '../LEAD Class Roster Maintenance User Manual.pdf'; return false" Text="User Manual"></asp:LinkButton></li>
			</ul>
		</div>

		
	</div>
</asp:Content>
