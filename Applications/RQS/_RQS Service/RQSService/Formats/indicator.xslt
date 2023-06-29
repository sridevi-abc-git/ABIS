<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:msxsl="urn:schemas-microsoft-com:xslt" exclude-result-prefixes="msxsl"
>
    <xsl:output method="html" indent="yes"/>
    <xsl:key name="EVENTS" match="EVENT_ID" use="."/>

    <xsl:param name="CURRSTATUSDESC">
        <xsl:value-of select="/INDICATOR/@CURRSTATUSDESC"/>
    </xsl:param>
    <xsl:param name="CURRSTATUS">
        <xsl:value-of select="/INDICATOR/@CURRSTATUS"/>
    </xsl:param>
    <xsl:param name="ENABLEEDIT">
        <xsl:value-of select="/INDICATOR/@ENABLEEDIT"/>
    </xsl:param>
    <xsl:param name="DESC">
        <xsl:value-of select="/INDICATOR/@DESC"/>
    </xsl:param>
    <xsl:param name="DISTRICT">
        <xsl:value-of select="/INDICATOR/@DISTRICT"/>
    </xsl:param>
    
    <xsl:template match="/">
        <html>
            <head>
                <title>
                    <xsl:value-of select="$DESC"/>
                    Status Summary
                </title>
                  <META HTTP-EQUIV="Pragma" CONTENT="no-cache" />
                  <META HTTP-EQUIV="Expires" CONTENT="-1" />

                <xsl:if test="$ENABLEEDIT='Y'">                   
                    <script type="text/javascript">
                        $(document).ready(function () {
                            $('[name="txtDate"]').val(getDateTime());
                            accept('input_area');
                        });
                    </script>
                </xsl:if> 
                <style type="text/css">
                    bodyx    { width:60%; margin:20px auto; background-color: #BBBBBB; color:#00008C; }
                    .header { font-family:Lucida Calligraphy; font-size:18pt; text-align: center; color:#00008C; padding-top:5px; }
                    .item-group { padding: 10px 0px 0px 20px; }
                    .item-header { font-size: 14pt; }
                </style>
            </head>
            <body>
                <div style="border: 0px solid gray; margin:10px; background-color:#FFFFFF;border-radius:10px;">
                    <div style="padding:10px;">
                        <div style="display:inline-block; vertical-align:text-bottom;">
                            <xsl:choose>
                                <xsl:when test="$CURRSTATUS='G'">
                                    <img src="../Images/Dash_Green_Light.jpg" alt="" />
                                </xsl:when>
                                <xsl:when test="$CURRSTATUS='Y'">
                                    <img src="../Images/Dash_Yellow_Light.jpg" alt="" />
                                </xsl:when>
                                <xsl:when test="$CURRSTATUS='R'">
                                    <img src="../Images/Dash_Red_Light.jpg" alt="" />
                                </xsl:when>
                                <xsl:otherwise>
                                    
                                </xsl:otherwise>
                            </xsl:choose>
                        </div>
                        <div class="header" style="display:inline-block; padding-top: 10px; padding-left: 20px;">
                            <xsl:value-of select="$DESC"/>
                            Status Summary: <xsl:value-of select="$CURRSTATUSDESC"/>
                        </div>
                    </div>
                    <hr/>
                    <xsl:if test="$ENABLEEDIT='Y'">
                        <xsl:call-template name="EDIT"/>
                        <hr/>
                    </xsl:if>
                    <div style="padding:10px;">
                        <xsl:for-each select="INDICATOR">
                            <xsl:apply-templates select="INFO/EVENT_ID[generate-id()=generate-id(key('EVENTS', .)[1])]"/>
                        </xsl:for-each>
                    </div>
                </div>
            </body>
            <HEAD>
             <META HTTP-EQUIV="Pragma" CONTENT="no-cache" />
             <META HTTP-EQUIV="Expires" CONTENT="-1" />
            </HEAD>
        </html>
    </xsl:template>

    <xsl:template name="EDIT">
        <div style="padding: 20px 20px;" id="input_area">
            <div>
                <input type="hidden" name="hdnSeq" class="return">
                    <xsl:attribute name="value">
                        <xsl:text>0</xsl:text>
                    </xsl:attribute>
                </input>
                <input type="hidden" name="hdnInd" class="return">
                    <xsl:attribute name="value">
                        <xsl:value-of select="/INDICATOR/@ID"/>
                    </xsl:attribute>
                </input>
                <input type="hidden" name="hdnEventId" class="return">
                    <xsl:attribute name="value">
                      <xsl:choose>
                        <xsl:when test="/INDICATOR/INFO/EVENT_ID != ''">
                          <xsl:value-of select="/INDICATOR/INFO/EVENT_ID"/>
                        </xsl:when>
                        <xsl:otherwise>
                          <xsl:text>1</xsl:text>
                        </xsl:otherwise>
                      </xsl:choose>
                    </xsl:attribute>
                </input>
                <input type="hidden" name="hdnUser" class="return">
                    <xsl:attribute name="value">
                        <xsl:value-of select="/INDICATOR/@CREATE_USER"/>
                    </xsl:attribute>
                </input>
                <div style="display:inline-block; width:200px;">
                    Status:
                </div>
                <div style="display:inline-block; padding-right:20px;">
                    <img src="../Images/Dash_Green_Light.jpg" alt="" />
                    <input type="radio" name="rdbStatus">
                        <xsl:if test="$CURRSTATUS='G'">
                            <xsl:attribute name="checked">checked</xsl:attribute>
                        </xsl:if>
                        <xsl:attribute name="value">G</xsl:attribute>
                    </input>
                </div>

                <div style="display:inline-block; padding-right:20px;">
                    <img src="../Images/Dash_Yellow_Light.jpg" alt="" />
                    <input type="radio" name="rdbStatus">
                        <xsl:if test="$CURRSTATUS='Y'">
                            <xsl:attribute name="checked">checked</xsl:attribute>
                        </xsl:if>
                        <xsl:attribute name="value">Y</xsl:attribute>
                    </input>
                </div>

                <div style="display:inline-block; padding-right:20px;">
                    <img src="../Images/Dash_Red_Light.jpg" alt="" />
                    <input type="radio" name="rdbStatus">
                        <xsl:if test="$CURRSTATUS='R'">
                            <xsl:attribute name="checked">checked</xsl:attribute>
                        </xsl:if>
                        <xsl:attribute name="value">R</xsl:attribute>
                    </input>
                </div>
            </div>

            <div style="padding-top: 10px;">
                <div style="display:inline-block; width:200px;">
                    Event Summary:
                </div>
                <div style="display:inline-block; padding-right:20px;">
                    <input type="text" name="txtSummary" >
                        <xsl:attribute name="value">
                            <xsl:value-of select="$CURRSTATUSDESC"/>
                        </xsl:attribute>
                    </input>
                </div>
            </div>

            <div style="padding-top: 10px;">
                <div style="display:inline-block; width:200px;">
                    District affected:
                </div>
                <div style="display:inline-block; padding-right:20px;">
                    <input type="text" name="txtAffected" >
                        <xsl:attribute name="value">
                            <xsl:value-of select="$DISTRICT"/>
                        </xsl:attribute>
                    </input>
                </div>
            </div>

            <div style="padding-top: 10px;">
                <div style="display:inline-block; width:200px;">
                    Event Description:
                </div>
                <div style="display:inline-block; padding-right:20px;">
                    <textarea name="txtDescription" rows="5" maxlength="500" style="width:500px"/>
                </div>
            </div>

            <div style="padding-top: 10px;">
                <div style="display:inline-block; width:200px;">
                    Event Time:
                </div>
                <div style="display:inline-block; padding-right:20px;">
                    <input type="text" name="txtDate" />
                </div>
            </div>
        </div>
        
        <div style="text-align: center; padding: 10px;">
            <div style="display: inline-block;">
                <input type="button" value="Submit" onclick="UpdateIndicator();" />
            </div>
            <div style="display: inline-block; padding-left: 10px;">
                <input type="button" value="Cancel" onclick="CancelEdit();" />
            </div>
        </div>
    </xsl:template>

    <xsl:template match="EVENT_ID">
        <xsl:variable name="EVENT_KEY" select="."></xsl:variable>
        <div class="item-group">
            <xsl:choose>
                <xsl:when test="position()&gt;1">
                    <xsl:attribute name="style">color:gray</xsl:attribute>
                </xsl:when>
                <xsl:otherwise>
                    <!--<xsl:attribute name="class">item-group</xsl:attribute>-->
                </xsl:otherwise>
            </xsl:choose>

            <div class="item-header">
                District affected: 
                <span style="font-weight:bold; padding-left: 10px;"><xsl:value-of select="../AFFECTED"/></span>
            </div>
            
            <ul style="margin:1px;">
                <xsl:for-each select="key('EVENTS', $EVENT_KEY)">
                    <li>
                        <div style="width:200px;display:inline-block;"><xsl:value-of select="../EVENT_DATE"/></div>
                        <span><xsl:value-of select="../EVENT_DESC"/></span>
                    </li>
                </xsl:for-each>

            </ul>

        </div>
    </xsl:template>

</xsl:stylesheet>
