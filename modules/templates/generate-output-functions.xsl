<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xso="dummy" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" exclude-result-prefixes="xd" version="2.0">
    <xsl:output indent="yes"/>
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>
                <xd:b>Created on:</xd:b> Nov 30, 2011</xd:p>
            <xd:p>
                <xd:b>Author:</xd:b> Alister Pillow</xd:p>
            <xd:p/>
            <xd:p>
                <xd:b>Description:</xd:b> Generate XSL functions from the named OUTPUT elements in
                the schema. These functions will be imported by the Template-stylesheet when
                Merging. </xd:p>
            <xd:p>Not quite sure how this will work. 
                Every field can have one or more named-output formatters which will either be an XPath or a call to a Common XSL Function 
                (defined in pekoe-system/common.xsl).
                The named-outputs are not unique across the schema - e.g many fragments will use the Address fragment and so require
                an "address" output. In most cases this will be an XPath based on the context node.
                What exactly do I want here? Is this going to be called from the Template? Or used to _generate_ the template?
                
                Stepping back again.
                I've just said that the names are not unique - suggesting that within the schema, the names might be re-used, but 
                the _scripts_ could be different. But surely the aim is to have names reused with a COMMON function?
                
                The problem in the original schema was that the names were GLOBAL AND FIELD-SPECIFIC. So I couldn't 
                have vendor:address and purchaser:address, I had to used vendor:v-address and purchaser:p-address, because only 
                the NAME was used to link the template to the schema. 
                
                So now, I can write 
                
                link ph-name="School-address" field-path="/school-booking/school" output-name="address-on-one-line"
                and in a different template, I can write (assuming the address fragment is present)
                link ph-name="Teacher-address" field-path="/school-booking/school/teacher" output-name="address-on-one-line"
                
                So now I just have to work out how to re-use the "address-on-one-line" output instead of re-defining it each time.
                My preference is to be able to define "address-on-one-line" IN the address fragment - but I don't know how to do that.
                
                Can it be overridden?
                
                ** 
                Functions do NOT have CONTEXT
                ** 
                
                
            </xd:p>
        </xd:desc>
    </xd:doc>
    
    <!-- This allows me to write xsl instructions in the output document -->
    <xsl:namespace-alias stylesheet-prefix="xso" result-prefix="xsl"/>
    <xsl:variable name="schema-root" select="string(/schema/@for)"/><!-- functions are in the namespace of the schema-root -->
    <xsl:template match="/schema">
        <xso:stylesheet xmlns:pekoe="http://www.gspring.com.au/pekoe" version="2.0">
            <xsl:namespace name="{$schema-root}">
                <xsl:value-of select="$schema-root"/>
            </xsl:namespace>
            <xso:include href="/db/pekoe-system/common.xsl"/>
            <xsl:apply-templates/>
        </xso:stylesheet>
    </xsl:template>
    
    <!--
        A TABLE needs to have a wrapper (created by  the template-stylesheet-generator) 
        Pass a param with the index-position number - or just run in a for-loop and make sure the CONTEXT is correct
        for-each??
        
        -->
    <xsl:template match="output[not(ancestor::fragment) and string(xpath) ne '']">
        <xso:function name="{$schema-root}:{string(./@name)}">
            <xso:param name="path"/> <!-- this param is made available to the script -->
            <xsl:comment>Has output xpath</xsl:comment>
            <xso:value-of select="{string(xpath)}"/>
        </xso:function>
    </xsl:template>
    
<!--    <xsl:template match="output[not(ancestor::fragment) and string(xpath) eq '']">
        <xso:function name="{$schema-root}:{string(../@path)}" >
            <xso:value-of select="{../@path}"/>
        </xso:function>
    </xsl:template>-->
    
<!--    <xsl:template match="output[ancestor::fragment]">
         
    </xsl:template>-->
    <xsl:template match="node()">
        <xsl:apply-templates/>
    </xsl:template>
</xsl:stylesheet>