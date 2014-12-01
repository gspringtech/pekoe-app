xquery version "1.0" encoding "UTF-8";
(: Copyright 2012 Geordie Springfield Pty Ltd Australia :)

module namespace docx="http://www.gspring.com.au/pekoe/merge/docx";
declare namespace w="http://schemas.openxmlformats.org/wordprocessingml/2006/main";
declare namespace file-store="http://www.gspring.com.au/pekoe/fileStore";
declare copy-namespaces preserve, inherit; (: WAS "preserve" :)
declare option exist:serialize "method=text media-type=application/xquery";



declare variable $docx:stylesheet := <xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl"
    xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
    exclude-result-prefixes="xs xd" version="2.0">
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p><xd:b>Created on:</xd:b> Apr 19, 2012</xd:p>
            <xd:p><xd:b>Author:</xd:b> apillow</xd:p>
            <xd:p/>
        </xd:desc>
    </xd:doc>
    <xsl:param name="template-content" />
    <xsl:param name="session-user" />    <!-- without this, the transform runs as guest - which is no good. -->
    <xsl:variable name="path-to-template-content" select="concat('xmldb:exist://', $session-user, '@', $template-content )" />
    <xsl:variable name="phlinks" select="/ph-links"/> <!--  a reference to the root is needed because another document is imported. -->

    <xsl:template match="/">
        <xsl:choose>
            <xsl:when test='doc-available($path-to-template-content)'>
                <xsl:apply-templates select=" doc( $path-to-template-content )/* "/> 
            </xsl:when>
            <xsl:otherwise>
                <error>Permission Denied</error>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

<!-- Might want to look at the key() function to do the lookup on the ph-links/link 
    I really need to investigate a better way to process tabular fields. 
    One option would be to generate a sequence of rows where each row contains an element matching the placeholder-name:
    <row><Date/><booked/><fee/>...</row>
    
-->




    <!-- process a TABLE ROW containing at least one field -->
    <xsl:template match="w:tr[w:tc/*/w:fldSimple]">
        <!-- 
            Aim here is to copy the tr for each repetition of the value in the first field. 
            Sounds confusing - but it's simple enough. We want a table, so the number of values in the first field determines the 
            number of rows. 
            (The first field doesn't have to be in the first column of the table.)                    
        -->
        <xsl:variable name="first-field" select="translate((.//w:fldSimple)[1]//w:t/text(),'«»','')" /> <!-- must be a better way to get the mergefield name. -->
        <xsl:variable name="row-count" select="count($phlinks/link[@ph-name eq $first-field]/*)" /> <!-- what if it's ZERO ???? -->
        <xsl:variable name="this-row" select="." />
        
        <xsl:if test="$row-count eq 0 and $phlinks/link[@ph-name eq $first-field] ne ''" > <!-- handle the case where there is no child element, only a value -->
            <xsl:apply-templates select="$this-row" mode="copy"><xsl:with-param name="index" select="0" as="xs:integer" tunnel="yes" /></xsl:apply-templates>
        </xsl:if>
        
        <xsl:for-each select="1 to $row-count"><!-- context is now the index number - hence the use of a variable in the select...  -->
            <xsl:apply-templates select="$this-row" mode="copy"><xsl:with-param name="index" select="." as="xs:integer" tunnel="yes" /></xsl:apply-templates> 
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="w:tr" mode="copy">     
        <xsl:copy>
            <xsl:apply-templates  mode="#default" />
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
        <xsl:param name="index" select="0" tunnel="yes"/> <!-- NOTE - MUST indicate that we EXPECT a tunnelled param here. -->
        <xsl:variable name="placeholder-name" select="translate(.//w:t/text(),'«»','')" /> 
       <w:r>
            <xsl:apply-templates select="./w:r/@*"></xsl:apply-templates>
            <xsl:apply-templates select="./w:r/w:rPr" />
            <w:t><xsl:choose>
                <xsl:when test="$index eq 0">
                    <xsl:value-of select="$phlinks/link[@ph-name eq $placeholder-name]/string(.)" />
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="($phlinks/link[@ph-name eq $placeholder-name]/*)[$index]/string(.)" />
                </xsl:otherwise>
            </xsl:choose></w:t>
        </w:r>
    </xsl:template>

    <xsl:template match="node() | @*">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*"/>
        </xsl:copy>
    </xsl:template>

</xsl:stylesheet>
;

(: --------------- Extract placeholders from Word ------------------------ :)

declare function docx:extract-placeholder-names($doc) {
        (: Here's a problem. How do I tell between docx with customXml and without? 
            I'm just going to assume that if the file contains customXml at all, then that's the approach.
        :)
        if (exists($doc//w:customXml[@w:uri eq "http://www.gspring.com.au/simple-ph"]) )
            then 
                for $n in $doc//w:customXml[@w:uri eq "http://www.gspring.com.au/simple-ph"]   
                return data($n/w:customXmlPr/w:attr/@w:val)
            else local:get-complex-mess-from-file($doc)
                
};

declare function local:get-complex-mess-from-file($doc) {
    distinct-values((local:get-fldSimple($doc),local:get-messy-field($doc)))  
};

declare function local:get-fldSimple($doc) {
    for $f in $doc//w:fldSimple[starts-with(@w:instr, " MERGEFIELD")]
    return replace(normalize-space($f/substring-after(substring-before(./@w:instr,"\* "),"MERGEFIELD")),"&quot;","")
};

declare function local:get-messy-field($doc) {
    for $f in $doc//w:instrText[contains(.," MERGEFIELD")]
    return replace(normalize-space($f/substring-after(substring-before(.,"\* "),"MERGEFIELD")),"&quot;","")
};

(: --------------------------------------- MERGE DOCX --------------------------------------:)

(:
    This module is imported by every WORD .docx Template XQuery. 
    The Merge process is based on the ph-links file. This file is copied and the desired outputs are constructed within it. 
    This temporary file and the Word document.xml file are passed to the docx:id-transform() function.
    The input document is copied to the output, except when fldSimple is encountered. This element is replaced by the associated value from the ph-links.
    
    TODO: Make this work with Word 2011 files.  
    ***** It might be useful to strip all w14:* attributes when importing the template-content.
    A simple stylesheet process perhaps.
    
:)


(:
    Step 1. Identity transform.

:)



(: This is where the field-placeholder is finally replaced by the data from the job - by getting the merge-field name from the template fldSimple
   and then using it as a key to a value in the $links. :)
declare function docx:replace-fld($input, $links, $index) {
let $phName := translate($input, "«»","")
let $ph-link := $links//link[@ph-name eq $phName]
return 
    if (count($ph-link/*) eq 0) 
    then <w:t>{string($ph-link)}</w:t>
    else <w:t>{string($ph-link/*[$index])}</w:t> (: should handle the multiple elements cleverly - perhaps in a table or by repeating :)
};


(: Seems like overkill but it's working. :)
declare function docx:id-transform-fld($input as node(),$links, $index) {
    typeswitch ($input) 
        case element(w:t) return
            docx:replace-fld($input, $links,$index)
        case element() return
        element { node-name($input) } {
            $input/@*, for $child in $input/node() return docx:id-transform-fld($child,$links,$index)
            }
    default return $input
};

declare function docx:process-field($fldSimple,$links) {
    docx:process-field($fldSimple,$links,1)
};
declare function docx:process-field($fldSimple,$links,$index) {
    for $f in $fldSimple/* 
    return docx:id-transform-fld($f,$links,$index)
};

declare function local:one-row($input, $links) {
 if ( $input instance of element(w:fldSimple)) then docx:process-field($input,$links)
      
      else if ($input instance of element()) then 
           element { node-name($input) } {
                $input/@*, for $child in $input/node() return docx:id-transform($child,$links)
                }
      else $input          

};

declare function local:one-row($index, $input, $links) {
    (: this is a tr. replicate and then process its children :)
    typeswitch ($input) 
        case element(w:fldSimple) return docx:process-field($input, $links, $index)
        case element() return element { node-name($input) } {
                    $input/@*, for $child in $input/node() return local:one-row($index, $child, $links)
                    }
        default return $input

};


(: Is it possible to generate replicas for any field whose value is more than one element? :)

declare function local:many-rows($row-count, $tr, $links) {
    for $i in 1 to $row-count
    return local:one-row($i, $tr, $links)

};

(:  This ROW contains a field (SOMEWHERE). Is it possible to work out whether 
    a second row is needed? 
    Could 
    - optimistically examine the first field,  - count elements.
    - look it up in the links area, 
    - check to see if the link is marked as a table
    - somehow process from there. 
    RULE is that if a table-cell is expected, the intermediate-results should be elements of the same name as the output? Or just elements anyway
:)
declare function docx:tablerow-with-field($tr,$links) {
    
    let $phName :=  translate(($tr//w:fldSimple)[1]//w:t[1], "«»","")
    let $ph-link := $links//link[@ph-name eq $phName]
    let $row-count := count($ph-link/*)
    return if ($row-count gt 1) then local:many-rows($row-count, $tr, $links) else local:one-row($tr, $links)
};


(:  Simple identity transform with filters. Looking for fldSimple. 
    Will also need to look for a 
    w:r/w:fldChar[@w:fldCharType eq "begin"]
    and then do some hopeful processing until the 
    w:r/w:fldChar[@w:fldCharType eq "end"]
    -- this will be similar to the transform-fld above in that a 
    separate id-transform will do the processing on elements until the last one. I think.
    
    How about this for an idea.
    I think it's possible to turn a field-code form into a fldSimple form by running a transformation. 
    The reason I'm not using a transformation here is ??
:)
declare function docx:id-transform($input as node(), $links) {
    (:
        Typeswitch is almost useless. There's no way to check the element's contents
        You can't write element(w:tr[.//w:fldSimple]) to test for a child 
        You can't write a for loop that handles this because then we'll get out of order
        You can't write a test like if ($input eq w:tr[.//w:fldSimple])
    :)
   
      if ( $input instance of element(w:fldSimple)) then docx:process-field($input,$links)
      else if ($input instance of element(w:tr) and exists($input//w:fldSimple)) then docx:tablerow-with-field($input, $links) 
      else if ($input instance of element()) then 
           element { node-name($input) } {
                $input/@*, for $child in $input/node() return docx:id-transform($child,$links)
                }
      else $input           
};


(: Copy-transform the original template-content using the data provided in the ph-links file. The :)
declare function docx:doc-transform($template-content as node(), $ph-links) {
    for $child in $template-content/* return docx:id-transform($child,$ph-links)
};


(: This is the only REQUIRED function - will be called by the <template>.xql
   Given the data as values in a list of element(link), and the template-file path,
   Find the template-content (in config/template-content/...)
   put the data values into the template-content
   add template-content to the docx file
   stream the result as a download back to the client.
   (That last step should be replaced - should simply return the binary to the calling <template>.xql 
   - which could then pass it to a suitable output function
   
   *****There are permissions issues when running the transform.******
   org.exist.storage.io.ExistIOException: BlockingOutputStream closed with an exception
   set the permissions to rwurwurwu
   xmldb:set-collection-permissions('/db/pekoe/config/template-content/Education', 'admin','staff',util:base-to-integer(0777,8))
:)
declare function docx:merge($intermediate, $template-file) {

    let $template-content := concat(substring-before(replace($template-file,"templates/","config/template-content/") , "."), ".xml")
    let $stored := xmldb:store('/db/temp','inter.xml',$intermediate)
    let $log := util:log("warn",concat("Doc ", $template-content, " available? ", doc-available($template-content)))
    let $log := util:log("warn",xmldb:get-current-user())
    let $log := util:log("warn",concat("CONTEXT: ", request:get-effective-uri()))

    let $merged := transform:transform($intermediate, $docx:stylesheet, 
        <parameters>
            <param name="template-content">{attribute value {$template-content}}</param> (: NOTE: the session info is not available OR needed in eXist 2.2 :)
            <param name="session-user">{attribute value {concat(session:get-attribute('user'), ":", session:get-attribute('password'))}}</param>
            </parameters>) 


    let $path-in-zip := 'word/document.xml' (: Which file in the DOCX or ODT are we replacing. :)
    let $binary-doc := util:binary-doc($template-file) (: this is the template ZIP :)
    return file-store:add-x-to-zip($merged, $path-in-zip, $binary-doc)
};

