(: 
    Module: display and browse Templates.
    
    This module does too much. The Browse stuff should be elsewhere. 
    This handles Triggered actions and client-side requests.
    
    Should move the odt specific behaviour to a module.
:)
module namespace templates="http://www.gspring.com.au/pekoe/admin-interface/templates";

declare namespace request="http://exist-db.org/xquery/request";
declare namespace xmldb="http://exist-db.org/xquery/xmldb";
declare namespace util="http://exist-db.org/xquery/util";
declare namespace datetime = "http://exist-db.org/xquery/datetime";

declare namespace t = "urn:oasis:names:tc:opendocument:xmlns:text:1.0";
declare namespace s = "urn:oasis:names:tc:opendocument:xmlns:table:1.0";
declare namespace w = "http://schemas.openxmlformats.org/wordprocessingml/2006/main";

declare namespace filestore="http://www.gspring.com.au/pekoe/fileStore";
declare copy-namespaces preserve, inherit; 

import module namespace security="http://www.gspring.com.au/pekoe/security" at "security.xqm";
import module namespace ods="http://www.gspring.com.au/pekoe/templates/ods" at "ods.xqm";
import module namespace odt="http://www.gspring.com.au/pekoe/merge/odt" at "../templates/merge-odt.xqm";
import module namespace docx="http://www.gspring.com.au/pekoe/merge/docx" at "../templates/merge-docx.xqm";
import module namespace phtml="http://www.gspring.com.au/pekoe/templates/pekoe-html" at "../templates/phtml.xqm";


declare variable $templates:fileExtensions := "txt ods odt docx xml";
declare variable $templates:base-path :=    "/db/pekoe/templates";
declare variable $templates:meta-path :=    "/db/pekoe/config/template-meta";
declare variable $templates:content-path := "/db/pekoe/config/template-content";

(:declare option exist:serialize "method=html5 media-type=application/xhtml+xml encoding=utf-8 indent=yes";:)


(: called by admin/templates.xql :)
declare function templates:extract($collection as xs:string) as element() {
let $resources := request:get-parameter("resource", ())
    return
        <div class="process">
            <h3>Extract Actions:</h3>
            <ul>
                {
                    for $resource in $resources
                    return <li>{templates:process-template-file($resource,$collection)}</li>
                }
            </ul>
        </div>
};

(: This _should_ come from a configuration file. :)
declare function templates:get-qualified-content-name($template-type) {
    if ($template-type eq 'docx')     then 'word/document.xml'
    else if ($template-type eq 'ods') then 'content.xml'
    else if ($template-type eq 'odt') then 'content.xml'
    else ()
};

(:     
    UPDATE: 2011-01-11
    I WANT TO CHANGE THIS PROCESS
    Instead of simply extracting the content, I want to check to see if there's existing content - if not
    then create a .xml file and store both the "phtree" and the template-content.xml in it.
    
    ALTERNATIVELY, wait until the template is requested. 
    The phtree MIGHT be stored in a LOCAL SCHEMA. 
    
    BECAUSE how can I avoid overwriting changes to the phtree-schema link?
    I think I wanted to put input and output FUNCTIONS in the schema for GENERAL use.
    I really want person-name-on-one-line in ONE PLACE ONLY.
    
    For example, there are 441 placeholders that use XPath output function - but there are only 80 distinct-values. 
    (less if typographical issues are removed). And this is WITHOUT the Form1 mess.
    For Javascript it's 66 and 22 distinct
    
    Most of the scripted output will be associated with a fragment. But the scripts AREN'T on the fragment - they're on the 
    fragmentRef
    
    That really suggests the scripts should be separate from both the fields and the placeholders.
    
    There are no output scripts on fragments. (which is fair enough as fragment-schemas are not attached to fields).
:)

(: Expecting to find either xml, html or text. $file-extension is ods, odt, docx, html, txt, xml :)
declare function templates:create-or-update-links($content-file-path, $subdir, $file-extension) {
    let $meta-dir := templates:get-meta-dir($subdir)
    let $dir := xmldb:create-collection($templates:meta-path, replace($meta-dir, $templates:meta-path,""))
    let $content-doc-name := util:document-name($content-file-path)
    let $meta-doc-name := concat(substring-before($content-doc-name,"."),".xml")
    
    let $allPlaceholders := 
        distinct-values(
        if ($file-extension eq 'odt') 
            then odt:extract-placeholder-names(doc($content-file-path))
        else if ($file-extension eq 'ods')
            then ods:extract-placeholder-names(doc($content-file-path))
        else if ($file-extension eq 'docx')
            then docx:extract-placeholder-names(doc($content-file-path))
        else if ($file-extension eq 'html')
            then phtml:extract-placeholder-names(doc($content-file-path))
        else if ($file-extension eq "txt")
            then 
                let $txt := util:binary-to-string(util:binary-doc($content-file-path))
                for $ph in tokenize($txt, "[\n\r]") (: split placeholders using line-breaks. This is a temporary measure. :)
                where ($ph ne "") 
                return $ph
        else ()
        )
    let $existing-links-file := concat($meta-dir,"/",$meta-doc-name)
    let $existing-links-doc := doc($existing-links-file)
    let $existing-links := $existing-links-doc//link
    let $existing-placeholders := $existing-links/string(@ph-name)
    let $for := replace($existing-links-doc/ph-links/@for,"^\s*(.*)\s$","")
    let $ph-links := 
        <ph-links xmlns="" for='{$for}' template-kind='{$file-extension}'>
        {$existing-links}
        {
            for $ph in $allPlaceholders return 
            if ($ph = $existing-placeholders) then () else 
            <link ph-name="{$ph}" field-path="" output-name="" />
        }
        </ph-links>

    return xmldb:store($meta-dir, $meta-doc-name, $ph-links)
};
(:
    I'm starting to doubt the value of having separate meta-data directories. 
    A possible alternative is to use underscores in the names and run a filter
    on any uploaded file to ensure that the name doesn't begin with an underscore.
    The big drama is when the user wants to move a file. 
    
    I have SO MUCH work to do.
:)

declare function templates:get-meta-subdir($file-or-collection) {
    let $folder-path := 
        if (contains($file-or-collection ,'.')) (: is it a file?  :)
        then util:collection-name($file-or-collection)
        else $file-or-collection
    return     
        replace($folder-path, $templates:base-path, $templates:meta-path)
};

declare function templates:get-content-dir($file-or-collection) {
    let $folder-path := 
        if (contains($file-or-collection ,'.')) (: is it a file?  :)
        then util:collection-name($file-or-collection)
        else $file-or-collection
    return     
        replace($folder-path, $templates:base-path, $templates:content-path)
};

declare function templates:get-content-file-name($file) {
    let $content-path := templates:get-content-dir($file)
    let $file-name := util:document-name($file)
    return concat($content-path,"/",replace($file-name,"\..*$",".xml"))

};

declare function templates:get-meta-file-name($file) {
   replace(concat(substring-before($file,'.'),".xml"), $templates:base-path, $templates:meta-path)
};

declare function templates:get-meta-dir($file-or-collection) {
    let $folder-path := 
        if (contains($file-or-collection ,'.')) (: is it a file?  :)
        then util:collection-name($file-or-collection)
        else $file-or-collection
    return     
        replace($folder-path, $templates:base-path, $templates:meta-path)
};

(: called by extract($coll) above, 
    and by admin/template-update.xql (trigger)  ********************** ENTRY POINT ******************* :)
declare function templates:process-template-file($file as xs:string, $collection as xs:string)  {
    (: got /db/pekoe/templates/FrogDetail.odt in /db/pekoe/templates  :)
    let $shortName := util:document-name($file)
    let $template-type := substring-after($file,'.') (: ods odt docx txt xml :)
    let $content-dir := templates:get-content-dir($file)
    (: 
        What I should probably do is use the doctype/extension to call a function in an imported module. 
        Better still, the import should be dynamic, or else call an external resource - so that I can 
        add new doctypes if needed. Otherwise pekoe must be updated. 
    :)
    let $stored-content-path := 
        if ($template-type = ("","txt","xml") )
        then templates:copy-raw-template-content($collection, $content-dir, $shortName ) (: store the raw file. Possibly xml, html or text :)
        else  templates:store-extracted-content($template-type, $file, $content-dir, $shortName)
     return templates:create-or-update-links($stored-content-path, $collection,$template-type)
};

declare function templates:copy-raw-template-content($collection, $content-dir, $shortName ) {
    (:  Make sure the destination exists. :)
    let $dir := xmldb:create-collection($templates:content-path, replace($content-dir, $templates:content-path,""))
    let $meta-dir := xmldb:create-collection($templates:meta-path, replace($content-dir, $templates:content-path,""))
    let $copy := xmldb:copy($collection, $content-dir, $shortName)
    return concat($content-dir, "/",$shortName)
};

declare function templates:store-extracted-content($docType, $file, $content-dir, $shortName) {
(:
    This is where it all goes wrong. The content extraction process should be passed off to the modules.
    ods, odt, text, xml, docx xls?
:)
    let $contentToExtract := templates:get-qualified-content-name($docType) (: eg. content.xml :)
    let $dir := xmldb:create-collection($templates:content-path, replace($content-dir, $templates:content-path,""))
    let $docname := util:document-name($file)
    let $localName := concat(substring-before($shortName,"."),'.xml')
    let $fullpath := concat('xmldb:exist://',$file)
    let $zf := filestore:extract-from-zip($fullpath,$contentToExtract) 
    (: So the $zf is a filepath - not the content. which is why we pass it to Store. :)

    let $stored:=  xmldb:store($content-dir, $localName, $zf) (: namespaces intact here :)

    let $repair-docx := if ($docType ne 'docx') then ()
        else
        let $doc := doc($stored)
(:        let $update := doctorx:transform-doc($doc) (\: losing namespaces here :\):)
        let $update := transform:transform($doc, xs:anyURI("../templates/repair-docx.xsl"),())
        return xmldb:store($content-dir, $localName, $update)
    return $stored
};

(:
    Store uploaded content. Extract "content.xml" from the ".odt".
    Store both the file and the content. 
    Called by admin/templates.xql 
:)
declare function templates:upload($collection as xs:string) as element() {
(:    let $docName := request:get-uploaded-file-name("upload")
    let $file    := request:get-uploaded-file("upload")

    return
        <div class="process">
            <h3>Actions:</h3>
            <ul>
                <li>Storing uploaded content to:
                {
                    xmldb:store($collection, $docName, $file)
                } </li>
            </ul>
        </div>:)
        let $name := request:get-parameter("name", ()),
    $docName := if($name) then $name else request:get-uploaded-file-name("upload"),
    $file := request:get-uploaded-file("upload") return
    
        <div class="process">
            <h3>Actions:</h3>
            <ul>
                <li>Storing uploaded content to: {$docName}</li>
                {
                    xmldb:decode-uri(xs:anyURI(xmldb:store($collection, xmldb:encode-uri($docName), $file)))
                }
            </ul>
    </div>
}; 

declare function templates:get-template-collection($collection, $docName) {
    let $col := concat($collection,'/',$docName)
    return 
        if (xmldb:collection-available($col)) 
        then $col
        else xmldb:create-collection($collection, $docName)
        
};

declare function templates:store($collection) {
    let $name := request:get-parameter("name", ()),
        $docName := if($name) then $name else request:get-uploaded-file-name("upload"),
        $file := request:get-uploaded-file("upload") 
        let $col := templates:get-template-collection($collection,$docName)
    return
    (: What I want to do is 
        create a collection with the document name.
        Then, depending on the doctype,
        either put the original into the collection OR put the contents of the original.
        So a docx or odt would be unzipped, but a text would be as-is.
    :)
    ()
    
};

(: called by admin/templates.xql
    Might be redundant as I no longer need the stylesheet.
:)
declare function templates:delete-stylesheet() {
   let $resources := request:get-parameter("resource", ())
   return
        <div class="process">
            <h3>Remove Actions:</h3>
            <ul>
                {
                    for $resource in $resources
                    return templates:remove-stylesheet($resource)
                }
            </ul>
        </div>
};

declare function templates:remove-stylesheet($resource as xs:string) as element()* 
{
    let $xsl := concat(substring-before($resource,"."),".xsl")
    let $isBinary := exists(doc($xsl))
    let $doc :=  doc($xsl) 
    return
        
        if (exists($doc)) then
        (
            <li>Removing document: {xmldb:decode-uri(xs:anyURI($xsl))} ...</li>,
            xmldb:remove(util:collection-name($doc), util:document-name($doc))
        )
        else
        (

        )
};

(:
    Remove a set of resources.
:)
declare function templates:remove() as element() {
    let $resources := request:get-parameter("resource", ())
    return
        <div class="process">
            <h3>Remove Actions:</h3>
            <ul>
                {
                    for $resource in $resources
                    return templates:remove-resource($resource)
                }
            </ul>
        </div>
};

(:
    Remove a resource.
:)
declare function templates:remove-resource($resource as xs:string) as element()* 
{
    let $isBinary := util:binary-doc-available($resource),
    $doc := if ($isBinary) then $resource else doc($resource) return
        
        if($doc)then
        (
            <li>Removing document: {xmldb:decode-uri(xs:anyURI($resource))} ...</li>,
            xmldb:remove(util:collection-name($doc), util:document-name($doc))
        )
        else
        (
            <li>Removing collection: {xmldb:decode-uri(xs:anyURI($resource))} ...</li>,
            xmldb:remove($resource)
        )
};

(:
    Create a collection.
:)
declare function templates:create-collection($parent) as element() {
    let $newcol := request:get-parameter("create", ())
    return
        <div class="process">
            <h3>Actions:</h3>
            <ul>
            {
                if($newcol) then
                    let $col := xmldb:create-collection($parent, $newcol)
                    return
                        <li>Created collection: {util:collection-name($col)}.</li>
                else
                    <li>No name specified for new collection!</li>
            }
            </ul>
        </div>
};

(:
    Display the contents of a collection in a table view.
    Called by admin/templates.xql
:)
declare function templates:display-collection($collection as xs:string) 
as element() {
    let $colName := $collection (:util:collection-name($collection):)
    return
        <table cellspacing="0" cellpadding="5" id="browse">
            <tr>
                <th/>
                <th>Name</th>
                <th>Permissions</th>
                <th>Owner</th>
                <th>Group</th>
                <th>Mime-type</th>
                <th>Modified</th>
                <th>Placeholders?</th>
                

            </tr>
            <tr>
                <td/>
                <td><a href="?collection={templates:get-parent-collection($colName)}">Up</a></td>
                <td/>
                <td/>
                <td/>
                <td/>
                <td/>
                
                <td/>
            </tr>
            {
                templates:display-child-collections($collection),
                templates:display-child-resources($collection)
            }
        </table>
};

declare function templates:display-child-collections($collection as xs:string)
as element()* {
    let $parent := $collection (:util:collection-name($collection):)
    for $child in xmldb:get-child-collections($collection)                          (: get-child-collections/resources return a string*, not an object :)
    let $path := concat($parent, '/', $child)
    order by $child
    return
        <tr>
            <td>&#160;</td>
            <td><a href="?collection={$path}">{$child}</a></td>
            <td class="perm">{xmldb:permissions-to-string(xmldb:get-permissions($path))}</td>
            <td>{xmldb:get-owner($path)}</td>
            <td>{xmldb:get-group($path)}</td>
            <td>-</td>
            <td>-</td>
            <td/>
        </tr>
};


declare function templates:display-child-resources($collection as xs:string)
as element()* {

    let $parent := $collection (:util:collection-name($collection):)
    let $xColl := collection($collection)
    for $child in xmldb:get-child-resources($collection) 
        let $path := concat($collection, '/', $child)
        let $available := if (util:is-binary-doc($path)) then (util:binary-doc-available($path)) else doc-available($path)
        let $extension := substring-after($child,'.')
        let $basedoc := substring-before($child, '.')
    
    (:  We're looking at odt files. The text:placeholder element contains a description.
        The description is a simple path expression. $root is the root of the path.  :)
        where contains($templates:fileExtensions, $extension)  and $available (:and doc-available(concat($parent,'/',$child)):)
           
        order by $child
(: probably want to wrap this $child in a link that sends us to the current URL with panel=editPlaceholder and with the full-child as a param.
   On return, come back here to the collection we're looking at. 
   This approach will allow me to keep using the admin.xql skin
   :)
    return
        <tr><td><input type="checkbox" name="resource" value="{$parent}/{$child}"/></td>
            <td><a target="_new" href="/exist/rest{$parent}/{$child}">{$child}</a></td>
            <td class="perm">{xmldb:permissions-to-string(xmldb:get-permissions($parent,$child))}</td>
            <td>{xmldb:get-owner($parent,$child)}</td>
            <td>{xmldb:get-group($parent,$child)}</td>
            <td>{xmldb:get-mime-type(xs:anyURI($path))}</td>
            <td >{datetime:format-dateTime(xmldb:last-modified($collection, $child),"dd MMM yyyy hh:mm:ss aa")}</td>
            <td>{
                let $meta-doc-name := templates:get-meta-file-name($path)
                return 
                    if (exists(doc($meta-doc-name))) 
                    then "yes"
                    else ()
            }
            
           </td>
            

        </tr>
};

(:
    Get the name of the parent collection from a specified collection path.
:)
declare function templates:get-parent-collection($path as xs:string) as xs:string {
    if($path eq "/db") then
        $path
    else
        replace($path, "/[^/]*$", "")
};

(: IT could be more efficient to use collection() to gather all the children,
   then post-process into collections using document-uri()
 :)


(: 
    There are two approaches to listing resources: 
    1) provide a complete list of all children - regardless of depth (but respecting permissions)
    2) list only the immediate children.
    
    1) collection() provides all the children for 1), but you have to use the document-uri to identify the collection path
    2) get-child-resources/collections will list the immediate children (2) but you have to use doc-available() to make sure
    that the permissions give you read access before looking at the child.
    
    
:)

declare function templates:check-all-permissions($fp) {
    let $meta-doc := templates:get-meta-file-name($fp)
    let $available := if (util:is-binary-doc($fp)) then util:binary-doc-available($fp) else doc-available($fp)
    return doc-available($meta-doc) and $available
};

declare function templates:display-templates-list($collection as xs:string) as element()* {
    let $parent := $collection (:util:collection-name($collection):)
    let $xColl := collection($collection)
    
    for $childString in xmldb:get-child-resources($collection)
    let $fp := concat($parent,'/',$childString)
    (: $fp gives me the resource path in the pekoe/templates folder. 
        Must also check the permissions of the templates-meta and -content folders. :)
    let $available := templates:check-all-permissions($fp)
    let $extension := substring-after($childString,'.')
    where (contains($templates:fileExtensions, $extension) or ($extension eq "xql"))
    order by $childString
    return if ($available) then 
    (:  /db/pekoe/config/template-meta/Schemas/Schema.xml  :)

    let $title := substring-before($childString,'.')
    (:  This was a test to see if we had extracted the content from the ODT or ODS.   
        let $associatedXML := concat($parent, '/',$title,".xml")
        :)
    (:  Instead, we need to indicate whether the Template has an associated ph-links file - but that just means it has a doctype definition in the ph-links for 
    the meta-collection. 
    
    This is where I have a problem. The permissions scheme for template-meta currently isn't in sync with the pekoe/templates file. 
    Options:
     keep permissions in sync
     make template-meta world-readable
     make template-meta group readable for staff and make all users part of staff
    
    :)
    
    let $meta-doc := templates:get-meta-file-name($fp)
    let $doctype := doc($meta-doc)/ph-links/@for/data(.)
(:  We want odt content.xml files. The first 3 parts of the where-clause check that. 
    The text:placeholder element contains a description. - which is a simple path expression. $root is the root of the path.  
    The doc-available function raises an error if the document isn't xml.
    :)
    (: 2007-09-27: the selection process is not useful. It's selecting xml containing a placeholder - 
    when we really need ANY template (.odt, .ods ,???) as long as it has xml.
    
    :)
    (:    where (contains($templates:fileExtensions, $extension) and doc-available($associatedXML) or ($extension eq "xql")):)

    
    return
         <li class='item' type='item' fileType="{$extension} {$doctype}" title="{$fp}">{$title}</li>
    else () (: not available :)
};

(:  javascript:gs.Pekoe.Controller.getTemplateComponents('{$fp}','{ $title }'); void 0  :)
(:
    I don't want to see these errors:
    Insufficient privileges to read resource /db/pekoe/config/template-meta/Schemas/ph-links.xml
    Permission denied to read collection '/db/pekoe/config/template-meta/Frogs
    
    So I'll need to check the 
:)

declare function templates:display-collections-list($collection as xs:string) as element()* {
    let $parent := $collection
    for $child in xmldb:get-child-collections($collection)
    let $path := concat($parent, '/', $child)
    order by $child
    return
        <li class='sublist' type='sublist' path='{$path}'><span class='folder'>{$child}</span>{templates:get-simple-listing($path)}</li>
};

(: 
    2011-03-09:
    Let the Client-side worry about the doctype and whether the templates are available. All I have to do is
    say whether a ph-link exists for the template. 
    Even that approach is problematic - because it means that the BAG must be reloaded when the ph-link is edited. 
    HOW can that be "pushed"?
:)
declare function templates:get-simple-listing($colName as xs:string) as element()? 
{
    let $sublists := (templates:display-collections-list($colName), templates:display-templates-list($colName))
	return if ($sublists) then
	<ul>{$sublists}
	</ul> 
	else ()
};

(:
    While the List of Lists is awkward, it is better than trying to do a breadth-first traversal with accumulators.
    
:)


(: Default fields/Placeholders. This relies on one or more "ph-schema.xml" file in the template's path.
    The system is outside the normal edit/publish mechanism for the schema. 
<placeholders>
    <ph name="notes" default="true" />
    <ph name="OurRef" default="true" />
</placeholders>

    The @default is in case this file becomes the schema later on.
:)

(: recursive function returns sequence of default placeholders from the ph-schema.xml doc declared at the current $root path
   plus those declared at each child collection along a path :)
declare function templates:path-step($root,$path,$root-element) {
(
    doc(concat($root,"/ph-schema.xml"))/placeholders/ph[@for eq $root-element and @default eq 'true']/@name/data(.)
    ,
    if (empty($path) or $path eq '') then ()
    else (templates:path-step(concat($root,substring-before($path,'/'),'/'), substring-after($path,'/'),$root-element))
)
};

(: Given a template path (ending with a slash) find all the default-placeholders. :)
declare function templates:get-default-placeholders($template,$root-element) {
    let $root := concat($templates:base-path,'/')
    let $context := substring-after($template, $root)

    return templates:path-step($root,$context,$root-element)
};

(: will potentially have multiple document types here - so need a better way to handle this:
    The only (simply) way to differentiate between an odt and an ods is by the file-extension. Both documents
    are office:document-content and its only when you get to the body that you find a difference. 
    Looking at the content won't help with MS docs either. Better to use the file-type. 
    Also, this highlights the awkwardness of my approach. Clearly, you can't have 
    test.odt and test.ods in the same collection as I'm extracting content to test.xml.
    
    Is it possible to upload an XML file using a custom extension (e.g. .odt_xml or .ods_xml )???
    
    It would be better to use the java url approch and use example.odt!/content.xml
    (But this may cause a performance hit.)
    
    If namespaces are applied (based on document path) then these will need to be added to the placeholder names.
    
:)

(: Returning a list here is not so satisfactory. There is more information in a spreadsheet which
   would be useful to display in the editor (e.g. number, date, text).
   However, this function is used by the field editor and transaction-reporting. 
   :)

declare function templates:placeholders-list($template) {
    let $docType := substring-after($template,'.')
    let $basedoc := substring-before($template, '.')
    let $contentDoc := concat($basedoc,".xml")
    let $docType := if (doc-available($contentDoc)) then $docType else ()
    let $allPlaceholders := 
        if ($docType eq 'odt') 
            then for $n in doc($contentDoc)//t:placeholder return data($n/@t:description)
        else if ($docType eq 'ods')
            then ods:extract-placeholder-names(doc($contentDoc))
            (:for $n in doc($contentDoc)//s:named-expression return data($n/@s:name):)
        else if ($docType eq 'docx')
            then for $n in doc($contentDoc)//w:customXml[@w:uri eq "http://www.gspring.com.au/simple-ph"]   
                return data($n/w:customXmlPr/w:attr/@w:val)
        else if ($docType eq "txt")
            then for $ph in doc($contentDoc)/phtree/ph return data($ph)
        else ()
    return distinct-values($allPlaceholders)
};

declare function templates:placeholders-list($template, $include-defaults as xs:boolean,$root-element) {
    let $docType := substring-after($template,'.')
    let $basedoc := substring-before($template, '.')
    let $contentDoc := concat($basedoc,".xml")
    let $docType := if (doc-available($contentDoc)) then $docType else ()
    let $defaults := if ($include-defaults eq true()) then templates:get-default-placeholders($template,$root-element) else ()
    let $allPlaceholders := 
        if ($docType eq 'odt') 
            then for $n in doc($contentDoc)//t:placeholder return data($n/@t:description)
        else if ($docType eq 'ods')
            then ods:extract-placeholder-names(doc($contentDoc))
            (:for $n in doc($contentDoc)//s:named-expression return data($n/@s:name):)
        else if ($docType eq 'docx')
            then for $n in doc($contentDoc)//w:customXml[@w:uri eq "http://www.gspring.com.au/simple-ph"]   
                return data($n/w:customXmlPr/w:attr/@w:val)
        else if ($docType eq "txt")
            then for $ph in doc($contentDoc)/phtree/ph return data($ph)
        else ()
    return distinct-values(($defaults, $allPlaceholders))
};

(: from docx
<w:customXml w:uri="http://www.gspring.com.au/simple-ph" w:element="placeholder">
    <w:customXmlPr>
       <w:attr w:name="name" w:val="/txo/property/address-on-one-line"/>
    </w:customXmlPr>

	<w:r>
        <w:t xml:space="preserve">12 Bonhomie Boulevard, </w:t>
    </w:r>
    <w:proofErr w:type="spellStart"/> Ain't this the stupidest thing. *************
        <w:r>
            <w:t>Balmain</w:t>
        </w:r>
    <w:proofErr w:type="spellEnd"/>
</w:customXml>

:)

(:
    Need a change to this function.
    Want to inject some site specific "commands" like "Download", "Email to teacher", "Open for editing".
    These may also be template-specific, which is why they're being added to the ph-links.
    Easiest way to achieve this is to WRAP the ph-links doc:
:)

declare function templates:get-phlinks($template) {
(:
    GOT:	/db/pekoe/templates/Schemas/ph-links.txt
    WANT:   /db/pekoe/config/template-meta/Schemas/ph-links.xml
    which is concat($templates:meta-path, replace($template, $templates:base-path)
    
    and then wrap with additional info ... from Config?
    with a doctype basis? which means getting the doctype from the ph-links FIRST
:)

    let $doc-name := templates:get-meta-file-name($template)
    let $links := doc($doc-name)/ph-links
    let $doctype := $links/data(@for)
    let $template-type := substring-after($template, ".")
(:  This could be made more specific by including the template type (e.g. docx or text)   :)
    let $site-commands := doc("/db/pekoe/config/site-commands.xml")//commands[@for eq $doctype]
    let $template-commands := $links/commands
    
    return 
        <template name='{$template}' >
            <commands>
                {$site-commands/command[empty(@template-type) or @template-type eq $template-type]}
            </commands>
            {$links}
        </template>
};

declare function templates:make-phlinks($template) {
<ph-links for="">
{
    let $docType := substring-after($template,'.')
    return 
        if ($docType eq "ods") 
        then for $n in ods:placeholders-list($template) 
            let $parts := tokenize($n,"--")
            return <link ph-path="{$parts[2]}" ph-name="{$parts[1]}" field-path="" output-name=""/>
        else for $n in distinct-values(templates:placeholders-list($template)) return <link ph-name="{$n}" field-path="" output-name=""/>
        
       }
</ph-links>
};

(: 
NOTE: 2011-03-08
xmldb:create-collection($existing-collection, $a-path-to-new-collection) will create the full path.
So why not create meta-data files in a meta-data folder:
/db/pekoe/phtree/
/db/pekoe/form-templates/

I still can't decide whether to have one meta-phtree-file per collection or one per document. 
And I also want this business of "include everything in the hierarchy down to this level, but no deeper" (whatever that might mean in context).

Perhaps somehow this can be expressed as a filter on elements:
collection("/db/pekoe/phtree")/phtree[document-uri( ????) ] or something.
:)

(: I want to change this so that instead of generating it each time, we simply return the pre-generated phtree. One option
is to generate it if it isn't there. :)

declare function templates:get-phlist($template, $include-defaults as xs:boolean,$root) as element() {
    
    <phtree file='{$template}'>
    {
        let $defaults := templates:get-default-placeholders($template,$root)
        for $n in $defaults
        return <ph name='{$n}' default='y' />
    }
    {
        let $docType := substring-after($template,'.')
        return 
            if ($docType eq "ods") 
            then for $n in ods:placeholders-list($template) 
                let $parts := tokenize($n,"--")
                return <ph path="{$parts[2]}" name="{$parts[1]}" />
            else for $n in distinct-values(templates:placeholders-list($template)) return <ph name="{$n}" />
        
    
      }
      </phtree>
};

(:declare function templates:get-phlist($template) as element() {
  <phtree file='{$template}'>
  {
    for $n in templates:placeholders-list($template)
    return <ph name='{$n}' />
  }
  </phtree>
};:)

declare function templates:show-schema($credentials as xs:string*) as element()+  {
    <div class="panel">
        <ul>{
        let $schema := doc('/db/pekoe/config/template-resources/schema.xml')
        for $ph in $schema/phtree/ph
        return <li>{data($ph/@name)}</li>
        }</ul>
    </div>
};

