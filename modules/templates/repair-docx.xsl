<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:doctorx="http://gspring.com.au/pekoe/templates/docxt" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" exclude-result-prefixes="xs xd doctorx" version="2.0">
    <!-- Replace the Complex Field Character structure with a fldSimple. 
        this transformation will start with the identity-transform at the end. 
        The important action starts when it encounters an element containing the MERGEFIELD instruction.  -->
    
    <!--  convert instrText content into a useable placeholder name. (Strip whitespace and quotes - I haven't done the quotes) -->
    <xsl:function name="doctorx:fix-field-name"> 
        <!-- instrText:
            ' MERGEFIELD  School-address  \* MERGEFORMAT ' 
            '   MERGEFIELD     "School address"    \* MERGEFORMAT  '  I haven't handled this yet. 
             and other variations of space and time.
        -->
        <xsl:param name="instrText"/>
        <xsl:variable name="trimmed">
            <xsl:value-of select="normalize-space($instrText)"/> <!-- 'MERGEFIELD School-address \* MERGEFORMAT' -->
        </xsl:variable>
        <xsl:variable name="second-token">
            <xsl:value-of select="tokenize($trimmed,'\s+')[2]"/> <!-- 'School-address' -->
        </xsl:variable>
        <xsl:value-of select="$second-token"/> <!-- could have used the previous 'select' -->
    </xsl:function>

    <!-- the main action. Replace a Complex Field Character structure with a fldSimple -->
    <xsl:template match="*[w:r/w:instrText[contains(.,'MERGEFIELD')]]">
        <!-- this matches a para, tc or similar container. Copy it, and its attributes, then process the first child. 
            Each child must explicitly apply-templates to the following sibling. 
            A Mode is used to indicate whether we're inside the Complex Field or not. 
        -->
        <xsl:copy>
            <xsl:apply-templates select="@*"/>
            <xsl:apply-templates mode="outside" select="child::*[1]"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template mode="outside" match="node() | @*"><!-- not sure if attributes need to be matched here. --> 
        <!-- Initially, this should match a Run (r). if the run contains a complex-field-character "begin", switch modes. else copy the content -->
        <xsl:choose>
            <xsl:when test="descendant::w:fldChar/@w:fldCharType[. eq 'begin']">
                <!-- Don't copy - just change modes and go next. -->
                <xsl:apply-templates mode="inside" select="following-sibling::*[1]"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy> <!-- copy this element and its children, because it's not of any interest. -->
                    <xsl:apply-templates select="node() | @*" mode="#default"/>
                </xsl:copy>
                <xsl:apply-templates mode="outside" select="following-sibling::*[1]"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template mode="inside" match="node()">
        <!-- These nodes are following a "begin". -->
        <xsl:choose>
            <xsl:when test="descendant::w:fldChar/@w:fldCharType[. eq 'end']">
                <!-- Don't copy it. Switch back to outside for the following sibling -->
                <xsl:apply-templates mode="outside" select="following-sibling::*[1]"/>
            </xsl:when>
            <xsl:when test="descendant::w:instrText[contains(.,'MERGEFIELD')]">
                <!-- Sadly, this is NOT the Run I need to copy. The one I want is after the "separator" - the second following-run
                <fldChar fldCharType="separate"/>
                 -->
                <xsl:variable name="Mergefield">
                    <xsl:value-of select=".//w:instrText"/>
                </xsl:variable>
                <w:fldSimple w:instr="{$Mergefield}">
                    <w:r>
                        <xsl:copy-of select="following-sibling::w:r[2]/w:rPr"/>
                        <w:t>«<xsl:value-of select="doctorx:fix-field-name($Mergefield)"/>»</w:t>
                    </w:r>
                </w:fldSimple>
                <xsl:apply-templates mode="inside" select="following-sibling::*[1]"/> <!-- next -->
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates mode="inside" select="following-sibling::*[1]"/>
            </xsl:otherwise> <!-- remove any other "inside" node -->
        </xsl:choose>
    </xsl:template>

    <!-- identity transform -->
    <xsl:template match="node() | @*">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*"/>
        </xsl:copy>
    </xsl:template>
</xsl:stylesheet>