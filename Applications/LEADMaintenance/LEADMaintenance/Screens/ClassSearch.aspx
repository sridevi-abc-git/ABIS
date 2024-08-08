<%@ Page Title="" Language="C#" MasterPageFile="~/Screens/SiteNav.master" AutoEventWireup="true" CodeBehind="ClassSearch.aspx.cs" Inherits="LEADMaintenance.Screens.ClassSearch" %>

<%@ MasterType VirtualPath="~/Screens/SiteNav.Master" %>

<asp:Content ID="Content1" ContentPlaceHolderID="head" runat="server">
	<style type="text/css">
		.grid-view				{ border: solid 1px #daeaee; border-radius: 10px 10px 0 0; }
		.header-style-default	{ border: none; background-color: #04a8cf; color: #e5f0f3; }
		.header-select			{ border: none;  }
		.item-select			{ width:  50px; vertical-align: top; border: none; }
		.header-status			{ border: none;  }
		.item-status			{ width: 100px; vertical-align: top; border: none; }
		.header-district		{ border: none;  }
		.item-district			{ width: 200px; vertical-align: top; border: none; }
		.header-location		{ border: none; }
		.item-location			{ width: 300px; vertical-align: top; border: none; }
		.header-trainingdate	{ border: none; }
		.item-trainingdate		{ width: 150px; vertical-align: top; border: none; text-align: center; }

		.no-display				{ display:none; padding:3px 0px; }
		.left-col				{ padding-right:10px; text-align: right; display:inline-block; width: 150px; vertical-align:top; margin-bottom: 1em; }
		.right-col				{ display:inline-block; }

		/*tbody > tr:nth-child(odd)	{ background-color: #96c4cf}*/

		th:first-child		{ border-top-left-radius: .6em; }
		th:last-child		{ border-top-right-radius: .6em; }

		tr:last-child > td:first-child		{ border-bottom-left-radius: .6em; }
		tr:last-child > td:last-child		{ border-bottom-right-radius: .6em; }

		/*.title				{ text-align:center; font-weight:bold; font-size:1.2em; padding:.4em 0; margin-bottom: 1em;
							  background-color:#04a8cf; color: #e5f0f3; border-radius: .3em .3em 0 0;
							}*/
	</style>
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="main" runat="server">
	<div class="content">

		<div id="searchinput" runat="server">
			<div class="title">Search for Classes</div>
			<div>
				<div>
					<div class="left-col">District:</div>
					<div class="right-col">
						<asp:DropDownList runat="server" ID="DistrictList">

						</asp:DropDownList>
					</div>
				</div>
				<div>
					<div class="left-col">Class Start Date:</div>
					<div class="right-col">
						<asp:TextBox runat="server" ID="start_date" maxlength="10" Width="80"  />
						(mm/dd/yyyy)
					</div>
				</div>

				<div>
					<div class="left-col">Class End Date:</div>
					<div class="right-col">
						<asp:TextBox runat="server" ID="end_date" MaxLength="10" Width="80" />
						(mm/dd/yyyy)
					</div>
				</div>
				<div style="padding-top:1em; padding-bottom: 1em; text-align:center;">
					<asp:Button runat="server" ID="search" Text="Search" OnClick="search_Click" 
								OnClientClick="$('#modal').modal(); document.body.style.cursor  = 'wait';" />
					<asp:Button runat="server" Text="Exit" OnClientClick="window.location='Main.aspx'; return false;" />
				</div>
			</div>
		</div>
		<div id="searchresults" runat="server" visible="false">
			<div class="title">Class List</div>
			<div style="width: 90%; margin: auto;">
				<asp:GridView runat="server" ID="classes" CssClass="grid-view" OnRowDataBound="classes_RowDataBound"
					HeaderStyle-CssClass="header-style-default" AlternatingRowStyle-BackColor="#96c4cf"
					RowStyle-BackColor="#daeaee"
					AutoGenerateColumns="false" CellPadding="10" OnRowCommand="classes_RowCommand">
					<Columns>
						<asp:TemplateField ItemStyle-CssClass="item-select" HeaderStyle-CssClass="header-select">
							<ItemTemplate>
								<asp:Button runat="server" ID="select" CommandName="select" CommandArgument='<%#Eval("objectid")%>'
									Text="Select" OnClientClick="$('#modal').modal(); document.body.style.cursor='wait';" />
							</ItemTemplate>
						</asp:TemplateField>
						<asp:TemplateField HeaderText="Class Status" ItemStyle-CssClass="item-status" HeaderStyle-CssClass="header-status">
							<ItemTemplate>
								<asp:Label runat="server" ID="status" />
							</ItemTemplate>
						</asp:TemplateField>
						<asp:BoundField DataField="DISTRICT" HeaderText="District" ItemStyle-CssClass="item-district"
							HeaderStyle-CssClass="header-district" />
						<asp:BoundField DataField="LOCATION" HeaderText="Location" ItemStyle-CssClass="item-location"
							HeaderStyle-CssClass="header-location" />
						<asp:BoundField DataField="TRAININGDATE" HeaderText="Date" ItemStyle-CssClass="item-trainingdate"
							HeaderStyle-CssClass="header-trainingdate" />
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
