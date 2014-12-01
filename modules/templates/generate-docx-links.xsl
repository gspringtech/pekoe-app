<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:pekoe="http://www.gspring.com.au/pekoe" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" exclude-result-prefixes="xs xd" version="2.0">
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>
                <xd:b>Created on:</xd:b> Dec 5, 2011</xd:p>
            <xd:p>
                <xd:b>Author:</xd:b> apillow</xd:p>
            <xd:p>Generate the ph-links file from a docx</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:output indent="yes"/>
    <xsl:template match="/">
        <ph-links for="" template-kind="docx">
            <xsl:apply-templates/>
        </ph-links>
    </xsl:template>
    <xsl:function name="pekoe:path-to-significant-ancestor">
        <xsl:param name="dot"/>
        <xsl:value-of select="string-join(for $a in $dot/ancestor-or-self::* return name($a),'/')"/>
    </xsl:function>
    <xsl:template match="w:fldSimple[starts-with(@w:instr, ' MERGEFIELD')]">
        <link ph-name="{replace(normalize-space(./substring-after(substring-before(./@w:instr,'\* '),'MERGEFIELD')),'&#34;','')}" field-path="" output-name="" path-to-repeating-unit="" repeat-separator="" path-to-field="{pekoe:path-to-significant-ancestor(.)}" is-table="false"/>
    </xsl:template>
    <xsl:template match="node() | @*">
        <xsl:apply-templates/>
    </xsl:template>
</xsl:stylesheet>