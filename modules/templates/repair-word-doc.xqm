xquery version "1.0" encoding "UTF-8";
module namespace doctorx = "http://www.gspring.com.au/pekoe/templates/doctorx";
declare namespace w="http://schemas.openxmlformats.org/wordprocessingml/2006/main";

(:declare namespace w14="http://schemas.microsoft.com/office/word/2010/wordml";:)

(:
    This module is losing the namespaces. But they aren't lost in the other processes. 
:)

(:

There are two forms of "field" in Word. The first w:fldSimple, is the easiest to deal with. Sadly, MSWord(mac) converts this form into the second form 
 - which is more like a "field-code" approach to word-processing.
To make things more amusing, if you open and Save-as the second form, it reverts to the first!! How's that for consistency!

This Query is intended to be used every time the document is uploaded - if it contains the dodgy form, then fix it before storing it in the Database.

<w:fldSimple w:instr=" MERGEFIELD  School-name  \* MERGEFORMAT ">
    <w:r w:rsidR="00121DC1">
        <w:rPr>
            <w:noProof/>
        </w:rPr>
        <w:t>�School-name�</w:t>
    </w:r>
</w:fldSimple>

"Field-code" form:
 <w:r w:rsidR="00FE6862">
    <w:fldChar w:fldCharType="begin"/>
</w:r>
<w:r w:rsidR="00FE6862">
    <w:instrText xml:space="preserve"> MERGEFIELD  School-name  \* MERGEFORMAT </w:instrText>
</w:r>
<w:r w:rsidR="00FE6862">
    <w:fldChar w:fldCharType="separate"/>
</w:r>
<w:r w:rsidR="00121DC1">
    <w:rPr>
        <w:noProof/>
    </w:rPr>
    <w:t>�School-name�</w:t>
</w:r>
<w:r w:rsidR="00FE6862">
    <w:rPr>
        <w:noProof/>
    </w:rPr>
    <w:fldChar w:fldCharType="end"/>
</w:r>

            
:)

(: 
the field-name shown in instrText often has too much white-space.
' MERGEFIELD  School-name  \* MERGEFORMAT '
It also can have spaces (and this must be managed)
' MERGEFIELD  "School name"  \* MERGEFORMAT '
want to produce 
'School-name' 
:)

declare function doctorx:fix-field-name($e) { 
    let $trimmed := normalize-space($e)
    return translate(tokenize($trimmed,"\s+")[2],'"','')
};

declare function doctorx:block-child-copy($input,$index,$inField) {
    
    if ($index gt count($input)) (:Is the index still valid?:)
    then ()
    else 
        (:I'm sure this could be tidied up - it's iteration via recursion, but with a twist. :)
         if ($inField) then (: Are we inside the field? Don't output anything:)
            if ($input[$index]/w:fldChar[@w:fldCharType eq 'end']) (: If so, test for the "end" code :)
            then doctorx:block-child-copy($input,$index + 1, false()) 
            else doctorx:block-child-copy($input,$index + 1, true())
        else (: Is the current node a "begin" statement? :)
            if ($input[$index]/w:fldChar/@w:fldCharType eq 'begin') 
            then (doctorx:transform-fieldcode($input[$index]),doctorx:block-child-copy($input, $index + 1, true()))
            else (doctorx:copy($input[$index]),doctorx:block-child-copy($input,$index + 1, false()))    
            
};

declare function doctorx:copy($e) {
    if ($e instance of element()) 
    then element { node-name($e) } 
        { $e/@*, 
          for $child in $e/node() return doctorx:copy($child)
        }
    else $e    
};


(: I guess that this function could be replaced by the field lookup... :)
declare function doctorx:transform-fieldcode($input as node()) {
    let $f := ($input/following-sibling::*[w:instrText])[1]/string(w:instrText)
    return
        <w:fldSimple w:instr='{$f}'>
            <w:r>
                <w:rPr>
                    <w:noProof/>
                </w:rPr>
                <w:t>«{doctorx:fix-field-name($f)}»</w:t>
            </w:r>
        </w:fldSimple> 
};

declare function doctorx:block-containing-field ($input) {
element { node-name($input) } 
    { $input/@*, 
      doctorx:block-child-copy($input/*,1,false())
    }
};

(: this is the (hopefully) final piece of the puzzle :)
declare function doctorx:filter-ignorable($attribute) {
    if (local-name($attribute) eq "Ignorable") then () 
    else if (starts-with(name($attribute), "w14") or starts-with(name($attribute), "wp14")) then ()
    else $attribute
};

declare function doctorx:transform($input as node()) {
    if ($input[w:r/w:fldChar[@w:fldCharType eq 'begin'] and w:r[w:instrText[contains(.,"MERGEFIELD")]]]) then doctorx:block-containing-field($input)
    else if ($input instance of element()) then 
           element { node-name($input) } {
                $input/@*, for $child in $input/node() return doctorx:transform($child)
                }
      else $input      
};
(: :)
(: given the document node, make a copy and fix the field-code style fields :)
declare function doctorx:transform-doc($input as node()) {
doctorx:transform($input)
};
(: Called from templates.xqm templates:store-extracted-content when user clicks "Generate or Update placeholders" :)
(:doctorx:transform-doc($doc):)
