<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  
    <xsl:output method="xml" indent="yes"/>
    
    <xsl:param name="http.port"/>
    <xsl:param name="http.proxyName"/>
    <xsl:param name="http.proxyPort"/>
    <xsl:param name="http.redirectPort"/>
    <xsl:param name="http.connectionTimeout"/>
    <xsl:param name="http.compression"/>
    <xsl:param name="http.scheme"/>
    <xsl:param name="http.maxHttpHeaderSize"/>
    <xsl:param name="http.relaxedPathChars"/>
    <xsl:param name="http.relaxedQueryChars"/>
    <xsl:param name="https.scheme"/>
    <xsl:param name="https.port"/>
    <xsl:param name="https.maxThreads"/>
    <xsl:param name="https.clientAuth"/>
    <xsl:param name="https.proxyName"/>
    <xsl:param name="https.proxyPort"/>
    <xsl:param name="https.keystoreFile"/>
    <xsl:param name="https.keystorePass"/>
    <xsl:param name="https.keyAlias"/>
    <xsl:param name="https.keyPass"/>
    <xsl:param name="https.compression"/>
    <xsl:param name="https.maxHttpHeaderSize"/>

    <xsl:template match="@*|node()">
        <xsl:copy>
            <xsl:apply-templates select="@*|node()"/>
        </xsl:copy>
    </xsl:template>
    
    <!-- redirect HTTP to HTTPS-->
    <!-- @redirectPort requires security-constraint in web.xml: https://tomcat.apache.org/tomcat-8.0-doc/config/http.html -->
    <xsl:template match="Connector[@protocol = 'HTTP/1.1']">
        <xsl:copy>
            <xsl:apply-templates select="@*"/>

            <xsl:if test="$http.port">
                <xsl:attribute name="port">
                    <xsl:value-of select="$http.port"/>
                </xsl:attribute>
            </xsl:if>
            <xsl:if test="$http.proxyName">
                <xsl:attribute name="proxyName">
                    <xsl:value-of select="$http.proxyName"/>
                </xsl:attribute>
            </xsl:if>
            <xsl:if test="$http.proxyPort">
                <xsl:attribute name="proxyPort">
                    <xsl:value-of select="$http.proxyPort"/>
                </xsl:attribute>
            </xsl:if>
            <xsl:if test="$http.redirectPort">
                <xsl:attribute name="redirectPort">
                    <xsl:value-of select="$http.redirectPort"/>
                </xsl:attribute>
            </xsl:if>
            <xsl:if test="$http.connectionTimeout">
                <xsl:attribute name="connectionTimeout">
                    <xsl:value-of select="$http.connectionTimeout"/>
                </xsl:attribute>
            </xsl:if>
            <xsl:if test="$http.compression">
                <xsl:attribute name="compression">
                    <xsl:value-of select="$http.compression"/>
                </xsl:attribute>
            </xsl:if>
            <xsl:if test="$http.scheme">
                <xsl:attribute name="scheme">
                    <xsl:value-of select="$http.scheme"/>
                </xsl:attribute>
            </xsl:if>
            <xsl:if test="$http.maxHttpHeaderSize">
                <xsl:attribute name="maxHttpHeaderSize">
                    <xsl:value-of select="$http.maxHttpHeaderSize"/>
                </xsl:attribute>
            </xsl:if>
            <xsl:if test="$http.relaxedPathChars">
                <xsl:attribute name="relaxedPathChars">
                    <xsl:value-of select="$http.relaxedPathChars"/>
                </xsl:attribute>
            </xsl:if>
            <xsl:if test="$http.relaxedQueryChars">
                <xsl:attribute name="relaxedQueryChars">
                    <xsl:value-of select="$http.relaxedQueryChars"/>
                </xsl:attribute>
            </xsl:if>

            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>

    <!-- enable HTTPS if it's not already enabled -->
    <xsl:template match="Service[not(Connector/@protocol = 'org.apache.coyote.http11.Http11NioProtocol')]/*[last()]">
        <xsl:copy>
            <xsl:apply-templates select="@*|node()"/>
        </xsl:copy>
        
        <Connector port="{$https.port}" protocol="org.apache.coyote.http11.Http11NioProtocol"
                   maxThreads="{$https.maxThreads}" SSLEnabled="true"  secure="true"
                   keystoreFile="{$https.keystoreFile}" keystorePass="{$https.keystorePass}"
                   keyAlias="{$https.keyAlias}" keyPass="{$https.keyPass}"
                   sslProtocol="TLS">
            <xsl:if test="$https.scheme">
                <xsl:attribute name="scheme">
                    <xsl:value-of select="$https.scheme"/>
                </xsl:attribute>
            </xsl:if>
            <xsl:if test="$https.proxyName">
                <xsl:attribute name="proxyName">
                    <xsl:value-of select="$https.proxyName"/>
                </xsl:attribute>
            </xsl:if>
            <xsl:if test="$https.proxyPort">
                <xsl:attribute name="proxyPort">
                    <xsl:value-of select="$https.proxyPort"/>
                </xsl:attribute>
            </xsl:if>
            <xsl:if test="$https.clientAuth">
                <xsl:attribute name="clientAuth">
                    <xsl:value-of select="$https.clientAuth"/>
                </xsl:attribute>
            </xsl:if>
            <xsl:if test="$https.compression">
                <xsl:attribute name="compression">
                    <xsl:value-of select="$https.compression"/>
                </xsl:attribute>
            </xsl:if>
            <xsl:if test="$https.maxHttpHeaderSize">
                <xsl:attribute name="maxHttpHeaderSize">
                    <xsl:value-of select="$https.maxHttpHeaderSize"/>
                </xsl:attribute>
            </xsl:if>
        </Connector>
    </xsl:template>
    
</xsl:stylesheet>