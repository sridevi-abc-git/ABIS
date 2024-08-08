<%@ Page Title="" Language="C#" MasterPageFile="~/Screens/SiteNav.master" AutoEventWireup="true" CodeBehind="StudentSearch.aspx.cs" Inherits="LEADMaintenance.Screens.StudentSearch" %>

<%@ MasterType VirtualPath="~/Screens/SiteNav.Master" %>

<asp:Content ID="Content1" ContentPlaceHolderID="head" runat="server">
	<style type="text/css">
		.left-col				{ padding-right:10px; text-align: right; display:inline-block; width: 200px; vertical-align:top; margin-bottom: 1em; }
		.right-col				{ display:inline-block; }

		.title				{ text-align:center; font-weight:bold; font-size:1.2em; padding:.4em 0; margin-bottom: 1em;
							  background-color:#04a8cf; color: #e5f0f3; border-radius: .3em .3em 0 0;
							}

	</style>
</asp:Content>
<asp:Content ID="Content2" ContentPlaceHolderID="main" runat="server">
	<div class="content">

		<div id="searchinput" runat="server">
			<div class="title">Search for Student</div>
			<div style="margin: 1em 0;">
				<ul style="padding-top: 0; margin-top: 0;">
					<li>Can search by name, email address or Confirmation Number.</li>
					<li>Partial name search will look for a match anywhere in the first or last name.
					</li>
					<li>Partial email search will look for a match anywhere in the email address.</li>
					<li>All searches are case insensitive.</li>
				</ul>
			</div>
			<div>
				<div>
					<div class="left-col">Name:</div>
					<div class="right-col">
						<asp:TextBox runat="server" ID="studentname"
									 Width="200" />
					</div>
				</div>
				<div>
					<div class="left-col">Email Address</div>
					<div class="right-col">
						<asp:TextBox runat="server" ID="emailaddress"
									 Width="200" />
					</div>
				</div>

				<div>
					<div class="left-col">Confirmation Number:</div>
					<div class="right-col">
						<asp:TextBox runat="server" ID="confirmationnumber"
									 Width="80" />
					</div>
				</div>
				<div>
					<div class="left-col">Phone Number:</div>
					<div class="right-col">
						<asp:TextBox runat="server" ID="phonenumber"
							Width="120" />
					</div>
				</div>
				<div style="padding-top: 1em; padding-bottom: 1em; text-align: center;">
					<asp:Button runat="server" ID="search" Text="Search" OnClick="search_Click" 
								OnClientClick="$('#modal').modal(); document.body.style.cursor  = 'wait';" />
					<asp:Button runat="server" Text="Exit" OnClientClick="window.location='Main.aspx'; return false;" />
				</div>
			</div>
		</div>

		<div id="searchresults" runat="server" visible="false">
			<div class="title">Student List</div>
			<div style="width: 90%; margin: auto;">
				<asp:GridView runat="server" ID="students" CssClass="grid-view" OnRowDataBound="students_RowDataBound"
					HeaderStyle-CssClass="header-style-default" AlternatingRowStyle-BackColor="#96c4cf"
					RowStyle-BackColor="#daeaee"
					AutoGenerateColumns="false" CellPadding="10" OnRowCommand="students_RowCommand">
					<Columns>
						<asp:TemplateField ItemStyle-CssClass="item-select" HeaderStyle-CssClass="header-select">
							<ItemTemplate>
								<asp:Button runat="server" ID="select" CommandName="select" CommandArgument='<%#Eval("objectid")%>'
									Text="Select" OnClientClick="$('#modal').modal(); document.body.style.cursor='wait';" />
							</ItemTemplate>
						</asp:TemplateField>
						<asp:BoundField DataField="STUDENTNAME" HeaderText="Student Name" ItemStyle-CssClass="item-district"
							HeaderStyle-CssClass="header-district" />
						<asp:BoundField DataField="EMAILADDRESS" HeaderText="Email Address" ItemStyle-CssClass="item-district"
							HeaderStyle-CssClass="header-district" />
						<asp:BoundField DataField="CONFIRMATIONNUMBER" HeaderText="Confirmation Number" ItemStyle-CssClass="item-location"
							HeaderStyle-CssClass="header-location" />
						<asp:BoundField DataField="PHONENUMBER" HeaderText="Phone Number" ItemStyle-CssClass="item-phonenumber"
							HeaderStyle-CssClass="header-location" />
					</Columns>

				</asp:GridView>
			</div>
			<div style="text-align: center; margin-top: 2em; margin-bottom: 1em;">
				<asp:Button runat="server" CssClass="button" Text="New Search" OnClientClick="window.history.back();; return false;" />
				<asp:Button runat="server" CssClass="button" Text="Exit" OnClientClick="window.location='Main.aspx'; return false;" />
			</div>
		</div>

		<div runat="server" id="msg" style="text-align: center; font-size: 1.3em;">
		</div>

	</div>
</asp:Content>
