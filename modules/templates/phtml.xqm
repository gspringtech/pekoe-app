(: Manage HTML documents. :)
xquery version "1.0";
module namespace phtml = "http://www.gspring.com.au/pekoe/templates/pekoe-html";

declare function phtml:extract-placeholder-names($doc) {
    for $n in $doc//*[contains(@class , 'pekoe-ph')]
    return $n/data(@id)
};




declare function phtml:merge($intermediate, $template-file) {
    let $template-content := concat(substring-before(replace($template-file,"templates/","config/template-content/") , "."), ".xml")
    (:let $merged := transform:transform($intermediate, $merge-docx:stylesheet, <parameters><param name="template-content">{attribute value {$template-content}}</param></parameters>) 
    
    A transformation is probably the easiest way to merge this file. eXist likes to do updates on files in the database - not in memory.
    To make these updates in memory requires running util:eval which is probably more awkward than developing a stylesheet
    :)
    return $template-content
    
};