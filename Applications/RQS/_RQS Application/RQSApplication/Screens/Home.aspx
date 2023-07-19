<%@ Page Title="" Language="C#" MasterPageFile="~/Screens/SiteNavigation.master" AutoEventWireup="true" CodeBehind="Home.aspx.cs" Inherits="RQS.Screens.Home" %>
<asp:Content ID="Content1" ContentPlaceHolderID="head" runat="server">
    <%--<script type="text/javascript" src="../Javascript/demo.js"></script>--%>
    <script type="text/javascript" src="../Javascript/ABC-Bargraph.js"></script>
    <script type="text/javascript">
        $(document).ready(function ()
        {
            if (g_user.USER_ROLE == 'I') jQuery('#dashboard').show();
        });

    </script>
    <style type="text/css">
        #dashboard      { margin: 15px; border: solid 5px #ffffff; border-radius:15px; background: #6274ff; padding:10px; }
    </style>
</asp:Content>
<asp:Content ID="Content2" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">

	<div class="box" style="border-top-left-radius: 10px; border-top-right-radius: 10px; min-height:400px; margin:2em 1em;">

	</div>

<%--    <div id="dashboard" style="display:none; background-color:#474744"; >
        <div id="main-dashboard" style="color:#ffffff">
            <div style="text-align:center; font-size:18pt;">
                Summary of Enforcement ABC-61 and ABC-220 Assignments
            </div>
            <div style="text-align:Center;">July 01, 2014</div>
            <div id="odometer" style="display:inline-block; width:48%; text-align:center;"></div>
            <div id="pie" style="display:inline-block; width:48%; text-align:center;"></div>
        </div>

        <div id="sub-dashboard" style="display:none">
            <div id="bar" style="text-align:center; border-radius:10px; background-color:#474744;">
                <div id="buttons" style="text-align:left; padding-left:30px;">
                  <input type="button" id="close" value="Close" 
                         onclick="jQuery('#main-dashboard').show(); jQuery('#sub-dashboard').hide();">
                </div>
                <canvas id="bar_canvas" width="500" height="450" style="padding-left:20px;" ></canvas>
  
            </div>
        </div>
    </div>--%>
</asp:Content>
