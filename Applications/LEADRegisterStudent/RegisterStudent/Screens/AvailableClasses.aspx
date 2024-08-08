<%@ Page Title="Available LEAD Classes" Language="C#" MasterPageFile="~/Screens/SiteNav.master" AutoEventWireup="true" CodeBehind="AvailableClasses.aspx.cs" Inherits="RegisterStudent.Screens.AvailableClasses"
	 EnableEventValidation="true" %>
<%@ MasterType VirtualPath="~/Screens/SiteNav.Master" %>


<asp:Content ContentPlaceHolderID="head" runat="server">
	<style type="text/css">
		.grid-view				{ border: solid 1px #E0E0E0; border-radius: 10px 10px 0 0; }
		.header-style-default	{ border: none; background-color: #990000; color: #ffffff; }
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
	</style>
</asp:Content>

<asp:Content ContentPlaceHolderID="main" runat="server">
	<div style="margin-bottom: 2em;">
		<div class="title">Available Classes</div>
		<div style="color: #620000; margin: 0 auto 2em auto; text-align:justify; width:90%;">
			<ul style="margin-right:3em;">
				<li>
					Even if the class is full, you still can register for the standby list.
					The standby list will be used to fill the spots of students that registered
					but did not show up for the class. The students selected from the standby list
					will be in the order that they registered for the class.
				</li>
			</ul>
		</div>
		<div style="width:90%; margin:auto;">
			<asp:GridView runat="server" ID="classes" CssClass="grid-view" OnRowDataBound="classes_RowDataBound"
				HeaderStyle-CssClass="header-style-default"
				AutoGenerateColumns="false" CellPadding="10" OnRowCommand="classes_RowCommand" >
				<Columns>
					<asp:TemplateField ItemStyle-CssClass="item-select" HeaderStyle-CssClass="header-select">
						<ItemTemplate >
							<asp:Button runat="server" ID="select"	CommandName="select" CommandArgument='<%#Eval("objectid")%>' Text="Select" />
						</ItemTemplate>
					</asp:TemplateField>
					<asp:TemplateField HeaderText="Class Status" ItemStyle-CssClass="item-status" HeaderStyle-CssClass="header-status" >
						<ItemTemplate>
							<asp:Label runat="server" ID="status" />
						</ItemTemplate>
					</asp:TemplateField>
					<asp:BoundField DataField="DISTRICT" HeaderText="District" ItemStyle-CssClass="item-district" HeaderStyle-CssClass="header-district" />
					<asp:BoundField DataField="LOCATION" HeaderText="Location" ItemStyle-CssClass="item-location" HeaderStyle-CssClass="header-location" />
					<asp:BoundField DataField="TRAININGDATE" HeaderText="Date" ItemStyle-CssClass="item-trainingdate" HeaderStyle-CssClass="header-trainingdate" />
				</Columns>

			</asp:GridView>
		</div>

		<div runat="server" id="msg" style="text-align: center; font-size: 1.3em;">
		</div>

		<div style="text-align: center; margin-top: 2em;">
			<asp:Button runat="server" CssClass="button" Text="Back" PostBackUrl="~/Screens/Information.aspx" />
			<asp:Button runat="server" CssClass="button" Text="Exit" ID="btnexit" />
		</div>
	</div>
</asp:Content>
