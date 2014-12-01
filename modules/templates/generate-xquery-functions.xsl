<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xso="dummy" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" exclude-result-prefixes="xd" version="2.0">
    <xsl:output indent="no" media-type="application/xquery" method="text"/>
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
            <xd:p>
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
                

                
            </xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:variable name="schema-root" select="string(/schema/@for)"/><!-- functions are in the namespace of the schema-root -->
    <xsl:template match="/schema">
module namespace sm="http://www.gspring.com.au/schema-module/<xsl:value-of select="$schema-root"/>";
import module namespace pekoe="http://www.gspring.com.au/pekoe" at "xmldb:exist://db/pekoe-system/common.xql";
<xsl:apply-templates/>
    </xsl:template>
    
    <!--
        A TABLE needs to have a wrapper (created by  the template-stylesheet-generator) 
        Pass a param with the index-position number - or just run in a for-loop and make sure the CONTEXT is correct
        for-each??
        
        2012-01-26: MAYBE a table should have all its content generated through one function. 
        So instead of depending on an array for each element, we generate a structure for the whole table out of one Output function:
        <table>
        <fees><actual>23</actual><total>466</total></fees> 
        <fees><actual>22</actual><total>423</total></fees> 
        </table>
        
        But this is going to be hard to make and explain.
                
        -->
    <xsl:template match="output[not(ancestor::fragment) and string(xpath) ne '']">
declare function sm:<xsl:value-of select="string(./@name)"/> ($path) {
<!--  <xsl:value-of select="string(xpath)"/>  This doesn't work because it won't copy elements (which are needed for tables) -->
        <xsl:copy-of select="./xpath/(* | text())"/>
};
    </xsl:template>
    
<!--    <xsl:template match="output[ancestor::fragment]">
         
    </xsl:template>-->
    <xsl:template match="node()">
        <xsl:apply-templates/>
    </xsl:template>
</xsl:stylesheet>