<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" exclude-result-prefixes="xs xd" version="2.0">
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>
                <xd:b>Created on:</xd:b> Apr 19, 2012</xd:p>
            <xd:p>
                <xd:b>Author:</xd:b> apillow</xd:p>
            <xd:p/>
        </xd:desc>
    </xd:doc>
    <xsl:variable name="phlinks" select="/ph-links"/> <!--  a reference to the root is needed because another document is imported. -->
    <xsl:template match="/">
        <xsl:variable name="path-to-template-content" select="concat('xmldb:exist://', $phlinks/@template-content )"/>
        <xsl:message>*************** GOT HERE ******************<xsl:value-of select="$path-to-template-content"/>
        </xsl:message>
        <xsl:apply-templates select=" doc( $path-to-template-content )/* "/> <!--  here's the import. How will that work? -->
    </xsl:template>

<!-- Might want to look at the key() function to do the lookup on the ph-links/link -->




    <!-- process a TABLE ROW containing at least one field -->
    <xsl:template match="w:tr[w:tc/*/w:fldSimple]">
        <!-- 
            Aim here is to copy the tr for each repetition of the value in the first field. 
            Sounds confusing - but it's simple enough. We want a table, so the number of values in the first field determines the 
            number of rows. 
            (The first field doesn't have to be in the first column of the table.)                    
        -->
        <xsl:variable name="first-field" select="translate((.//w:fldSimple)[1]//w:t/text(),'«»','')"/> <!-- must be a better way to get the mergefield name. -->
        <xsl:variable name="row-count" select="count($phlinks/link[@ph-name eq $first-field]/*)"/> <!-- what if it's ZERO ???? -->
            <!-- ANOTHER tricky technical bit. 
                For each ph-link value ($phlinks/link[@ph-name eq $first-field]/*)
                Copy THIS table-row. Then apply templates. How is that done?
                I think it's much the same as in the XQuery. 
                Create a Loop with an Index. copy the tr and apply templates - passing the Index. 
            -->
        <xsl:variable name="this-row" select="."/>
        <xsl:for-each select="1 to $row-count"><!-- context is now the index number -->
            <xsl:apply-templates select="$this-row" mode="copy">
                <xsl:with-param name="index" select="." as="xs:integer" tunnel="yes"/>
            </xsl:apply-templates>
        </xsl:for-each>
    </xsl:template>
    <xsl:template match="w:tr" mode="copy">
        <xsl:copy>
            <xsl:apply-templates mode="#default"/>
        </xsl:copy>
    </xsl:template>

<!-- Replace fld simple by its content and replace the w:t by the value:
    <w:r>
        <w:rPr>
            <w:rFonts w:asciiTheme="minorHAnsi" w:hAnsiTheme="minorHAnsi" w:cstheme="minorHAnsi"/>
            <w:noProof/>
        </w:rPr>
        <w:t>flab</w:t>
    </w:r>
    -->
    <xsl:template match="w:fldSimple">
        <xsl:param name="index" select="0" tunnel="yes"/> <!-- NOTE - the tunnel attribute must be here or else it won't work. -->m
        <xsl:variable name="placeholder-name" select="translate(.//w:t/text(),'«»','')"/>
        <w:r>
            <xsl:apply-templates select="./w:r/@*"/>
            <xsl:apply-templates select="./w:r/w:rPr"/>
            <w:t>
                <xsl:choose>
                    <xsl:when test="$index eq 0">
                        <xsl:value-of select="$phlinks/link[@ph-name eq $placeholder-name]/string(.)"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="($phlinks/link[@ph-name eq $placeholder-name]/*)[$index]/string(.)"/>
                    </xsl:otherwise>
                </xsl:choose>
            </w:t>
        </w:r>
    </xsl:template>
    <xsl:template match="node() | @*">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*"/>
        </xsl:copy>
    </xsl:template>
</xsl:stylesheet>