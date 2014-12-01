<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xso="dummy" xmlns:xs="http://www.w3.org/2001/XMLSchema" exclude-result-prefixes="xs" version="2.0">
    <!-- 2012-01-12: IS THIS USED? -->
    
    <!-- This allows me to write xsl instructions in the output document -->
    <xsl:namespace-alias stylesheet-prefix="xso" result-prefix="xsl"/>
    <!-- 
        Transform a DOCX into a pull-transform stylesheet. 
        To be able to include the functions, the stylesheet must be fully formed.
    -->
    <xsl:param name="links-doc-path"/>
    <xsl:param name="schema-doc-path"/>
    <xsl:param name="schema-functions" select="concat(substring-before($schema-doc-path, '.xml'),'.xsl')"/>
    <xsl:variable name="schema-root" select="string(doc($schema-doc-path)/schema/@for)"/><!-- functions are in the namespace of the schema-root -->
    <xsl:template match="w:document">
        <xsl:copy>
            <xsl:namespace name="xsl">http://www.w3.org/1999/XSL/Transform</xsl:namespace>
            <xsl:attribute name="xsl:version">2.0</xsl:attribute>
            <xsl:attribute name="exclude-result-prefixes">pekoe,<xsl:value-of select="$schema-root"/>
            </xsl:attribute>
            <xsl:namespace name="{$schema-root}">
                <xsl:value-of select="$schema-root"/>
            </xsl:namespace>
            <xsl:namespace name="pekoe">http://www.gspring.com.au/pekoe</xsl:namespace>
            <xso:include href="{$schema-functions}"/>
            <xsl:apply-templates/>
        </xsl:copy>
    </xsl:template>
    
    <!-- 
        w:fldSimple is the easiest of the crappy Word markups (and look how stupid it is!)
        option 1: get the field name from the text: w:t
        option 2: parse the @w:instr 
        
        (using option 1...)
        Now need to figure out how to apply the "output" format to select the correct value.
        
        For example: (from the original txo schema)
        
        <ph path="" name="enquirer-address" output="xpath" order="1-1" join="" context="address">
            <xpath context="">concat(line1, ' ', suburb, ' ', state, ' ', postcode)</xpath>
        
        In the new ph-links, this would be an "output" named "enquirer-address"
        if it's just xpath, it is simple - check to see if it is an absolute path
        If not, append it to the @field-path or else insert it directly.
        
        
        <w:fldSimple w:instr=" MERGEFIELD  School-name  \* MERGEFORMAT ">
         <w:r w:rsidR="00121DC1">
            <w:rPr>
                <w:noProof/>
            </w:rPr>
            <w:t>«School-name»</w:t>
         </w:r>
        </w:fldSimple>
        
        I'm going to need some pre-defined outputs such as Australian-short-date or Number as Words
        But how do I "call" them?
        
        - make all outputs have a name and a value?
        - 
    -->
    
    <!-- 
        A MAJOR FLAW 
        in this approach (putting the xpaths into the <template>.xsl is that if the SCHEMA CHANGES, 
        the templates may need to be recompiled. 
        
        a Better Approach might be the named Functions that I started to create from the SCHEMA
        In fact, the transform of the template to template.xsl might be better as 
        a series of function calls. 
        Then, any changes to fields can be managed within the schema and will generate a new schema.xsl
        This won't prevent the templates breaking if a field or function is removed - but that can't be helped.
        
        So what this transform must do is put named function calls in place of the MERGEFIELDs.
        WHAT ARE these named function calls? Hmm. 
        
        
        Next: how do I deal with TABULAR data?
        
        -->
    <xsl:template match="w:t" mode="field">
        <!-- Extract the mergefield NAME -->
        <xsl:variable name="fName" select="replace(., '«|»','')"/> 
        <!--find associated Link -->
        <xsl:variable name="ph-link" select="doc($links-doc-path)//link[@ph-name eq $fName]"/> 
        <!-- Link provides Field XPath -->
        <xsl:variable name="fPath" select="$ph-link/string(@field-path)"/>
        <xsl:variable name="output-name" select="$ph-link/string(@output-name)"/> <!-- ... and (optional) Named Output -->

        
        <!-- VERY TRICKY: 
            by design, this version of the schema allows output-scripts to have common names. (e.g. address-on-one-line)
            This DOES NOT imply that the script is the SAME. (e.g. some kind of "last" value or "sum")
            So the correct output is field dependent:
            //field[@path = $fPath]/output[@name eq $output-name] 
            can also be written //output[@name eq $output-name and ancestor::field/@path eq $fPath]
            
            Something just occurred to me - some way to pre-process the outputs into named functions in a stylesheet perhaps?
            Some way to generate a stylesheet that simplifies the function?
            
            Biggest problem with this at the moment is the lack of useful inputs and outputs. 
            I think I'll have to re-work the txo-schema.
        -->
        
<!--        <xsl:variable name="full-path" select="if ($output-name ne '') then concat($fPath, '/',$output-name) else"></xsl:variable>-->
        <!-- 
            TODO: change this so that it tests for an absolute path. 
        -->
        <xsl:copy>
            <xsl:choose>
                <xsl:when test="$output-name eq ''">
                    <xso:value-of select="string-join({$fPath},' ')"/>
                </xsl:when>
                <xsl:otherwise>
                    <xso:value-of select="{$schema-root}:{$output-name}({$fPath})"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="w:fldSimple">
        <xsl:apply-templates mode="field"/>
    </xsl:template>
    <xsl:template match="node() | @*" mode="field">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*" mode="field"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="node() | @*">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*"/>
        </xsl:copy>
    </xsl:template>
</xsl:stylesheet>