<%@ Page Title="" Language="C#" MasterPageFile="~/Screens/Site.Master" AutoEventWireup="true" CodeBehind="default.aspx.cs" Inherits="LEADMaintenance._default" %>

<%@ MasterType VirtualPath="~/Screens/Site.Master" %>

<asp:Content ID="Content1" ContentPlaceHolderID="head" runat="server">
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="main" runat="server">
	<div class="signin" style="margin: auto; width: 400px; position: relative;">
		<fieldset class="shadow" style="position: absolute; z-index: 1; margin-top: 5em;
			width: 100%; border: 0;">
			<header>
				LEAD Maintenance Sign-In 
			</header>
			<div>
				<table style="width: 100%; margin-bottom: 1em; margin-top: 1em;">
					<tbody>
						<tr>
							<td style="width: 29%;">LEAD User Id:</td>
							<td style="width: 70%">
								<asp:TextBox runat="server" ID="userid" Style="width: 90%;"></asp:TextBox>
							</td>
						</tr>
						<tr>
							<td>Password:</td>
							<td>
								<asp:TextBox runat="server" ID="pswd" TextMode="Password" Style="width: 90%;"></asp:TextBox>
							</td>
						</tr>
						<tr>
							<td colspan="2" style="text-align: center">
								<asp:Button runat="server" ID="signin_submit" Text="Sign In" OnClick="signin_click"
											OnClientClick="$('#modal').modal(); document.body.style.cursor='wait';" />
							</td>
						</tr>
						<tr style="">
							<td colspan="2" style="text-align: center; font-weight: bold; font-size: 1.1em;">
							</td>
						</tr>
					</tbody>
				</table>
			</div>
			<div id="err_msg" runat="server" style="width: 100%; padding: .5em 0em; background-color: rgba(83, 0, 0, 0.25);
				color: rgba(83, 0, 0, 1.0); border-radius: 0 0 0.75em 0.75em; display: none;">
				<asp:Label runat="server" ID="error_message"
					Style="width: 100%; padding-left: 1em;">
				</asp:Label>
			</div>
		</fieldset>
	</div>
</asp:Content>
