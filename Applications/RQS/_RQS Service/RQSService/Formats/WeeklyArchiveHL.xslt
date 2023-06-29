<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0"
				xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
				xmlns:msxsl="urn:schemas-microsoft-com:xslt"
				exclude-result-prefixes="msxsl"
>
	<xsl:output method="html"
				indent="yes"/>

	<xsl:param  name="CREATE_DATE"></xsl:param >

	<xsl:template match="/ROOT">
		<xsl:text disable-output-escaping="yes">&lt;!DOCTYPE html&gt;</xsl:text>
		<html  xmlns="http://www.w3.org/1999/xhtml">
			<head>
				<xsl:text disable-output-escaping="yes"><![CDATA[
				<link rel="stylesheet" href="/css/styles.css" media="screen, projection, print, tv" type="text/css" />
				<link rel="stylesheet" href="/css/navigation-megadropdown.css" media="screen, projection, print, tv" type="text/css" />
				<link rel="stylesheet" href="/css/design03r.css" media="screen, projection, print, tv" type="text/css" />
				<link rel="stylesheet" href="/css/footer-with-dark-container.css" media="screen, projection, print, tv" type="text/css" />
				]]></xsl:text>
				<script type="text/javascript">
					var page = 'new';
					<!--
					var defaultMainList = "eServices";
					// -->
				</script>

				<xsl:text disable-output-escaping="yes"><![CDATA[<script type="text/javascript" src="/javascript/scripts.js"></script>]]></xsl:text>

				<style type="text/css">
					td	{ padding-right: 3em; }

				</style>

				<title>California ABC Archived Reports</title>
			</head>
			<body>
				<xsl:text disable-output-escaping="yes"><![CDATA[<!--#include virtual="/ssi/header.megadropdown.html" -->]]></xsl:text>

				<div id="page_container">
					<div id="main_content">
						<div class="add_padding">
							<div class="content_left_column">

								<h1> Archived Reports</h1>
								<p>Reports are in chronological order, by latest year.</p>

								<div style="margin: 10px auto; padding:0px 0px; background-color:white;">
									<!--<table class="">-->
										<ul class="list_style_4">
											<xsl:for-each select="*">
												<xsl:call-template name="archive-entry"/>
											</xsl:for-each>
										</ul>
									<!--</table>-->
								</div>
								<!--<div style="padding-bottom:1.0em; color:#808080; width:100%; padding-left: 5em;">
									Updated: <xsl:value-of select="$CREATE_DATE"/>
								</div>-->
							</div>


							<div class="content_right_column">
								<xsl:text disable-output-escaping="yes"><![CDATA[<!--#include virtual="ABC_ssi/popular_links.html" -->]]></xsl:text>
								<xsl:text disable-output-escaping="yes"><![CDATA[<!--#include virtual="ABC_ssi/Reports_Related.html" -->]]></xsl:text>
								<xsl:text disable-output-escaping="yes"><![CDATA[<div class="cleaner"></div>]]></xsl:text>
							</div>

						</div>
						<xsl:text disable-output-escaping="yes"><![CDATA[<!--#include virtual="/ssi/footer_1.html" -->]]></xsl:text>
					</div>

				</div>
				<xsl:text disable-output-escaping="yes"><![CDATA[<!--#include virtual="/ssi/footer_2.html" -->]]></xsl:text>
			</body>
		</html>
	</xsl:template>

	<!-- ******************************************************************** -->
	<!--     Template layout                       -->
	<!-- ******************************************************************** -->
	<xsl:template name="archive-entry">
		<!--<tr>
			<td>-->
		<li>
				<a>
					<xsl:attribute name='href'>
						<xsl:value-of select='./HREF'/>
					</xsl:attribute>
					<xsl:value-of select="./DESCRIPTION"/>
				</a></li>
			<!--</td>
		</tr>-->

	</xsl:template>

</xsl:stylesheet>
