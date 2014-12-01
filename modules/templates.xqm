xquery version "3.0";
(: 
    Module: display and browse Templates.
   Get ph-links (??)
   
    Probably want to create a "bundle" module to handle the display and management of Bundles.
    Bundles would be either Jobs or Templates (.docx, .job etc).
    Display: show as a "File" with an Icon
    Actions:
        Move
        Rename
        Delete.
        Rename can be a move-delete. Copy can be a Move without delete.
   
:)
module namespace templates="http://www.gspring.com.au/pekoe/admin-interface/templates";




declare copy-namespaces preserve, inherit; 

declare variable $templates:fileExtensions := "txt ods odt docx xml";
declare variable $templates:base-path :=    "/db/pekoe/templates";


declare function templates:get-template-collection($collection, $docName) {
    let $col := concat($collection,'/',$docName)
    return 
        if (xmldb:collection-available($col)) 
        then $col
        else xmldb:create-collection($collection, $docName)
        
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
                <td><a href="?collection={util:collection-name($colName)}">Up</a></td>
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
    for $child in xmldb:get-child-collections($collection)[not(contains(., "."))]                          (: get-child-collections/resources return a string*, not an object :)
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

    let $xColl := collection($collection)
    for $child in xmldb:get-child-collections($collection)[contains(., ".")] 
        let $path := concat($collection, '/', $child)
        let $available := xmldb:collection-available($path)
        let $extension := substring-after($child,'.')
        let $basedoc := substring-before($child, '.')
        let $pekoe-meta-doc := concat($path,'/pekoe-meta.xml')
        order by $child
(: Will want to create a custom action associated with a Link on the Template. 
    How do I create a "rename" or "move". Are they the same? (Both requiring a path and name?)  :)
    return
        <tr><td><input type="checkbox" name="resource" value="{$collection}/{$child}"/></td>
            <td>{$child}</td>
            <td class="perm">{xmldb:permissions-to-string(xmldb:get-permissions($path))}</td>
            <td>{xmldb:get-owner($path)}</td>
            <td>{xmldb:get-group($path)}</td>
            <td>{xmldb:get-mime-type(xs:anyURI($path))}</td>
            <td>{if (doc-available($pekoe-meta-doc)) then xsl:format-dateTime(xmldb:last-modified($path,"pekoe-meta.xml"),"dd MMM yyyy hh:mm:ss aa") else xmldb:created($path)}</td>
            <td>{
                if (doc-available($pekoe-meta-doc)) 
                    then "yes"
                    else ()
            }
            
           </td>
            

        </tr>
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
    true()
};


(: NOTE: The new form of Template management relies on creating a Collection for each Template.
    So even a TEXT Template will need to be stored as a collection.
    
    But where am I going to put the Admin page? 
    How do I manage template Uploads and Edits
    Holy Crap there's a lot of work here.
:)

declare function templates:display-templates-list($collection as xs:string) as element()* {
    let $xColl := collection($collection)
    
(:    for $childString in xmldb:get-child-resources($collection):)
    for $childString in xmldb:get-child-collections($collection)[contains(., ".")]
    let $log := util:log("debug","TEMPLATE ITEM " || $childString)
    let $fp := concat($collection,'/',$childString)
(:    let $available := templates:check-all-permissions($fp):)
    let $extension := substring-after($childString,'.')
    let $title := substring-before($childString,'.')
(:    where (contains($templates:fileExtensions, $extension) or ($extension eq "xql")):)
    let $meta-doc-path := concat($fp,'/pekoe-meta.xml')
    let $doctype := doc($meta-doc-path)//ph-links/@for/data(.)
    order by $childString
    return 
        <li class='item' type='item' fileType="{$extension} {$doctype}" title="{$fp}">{$title}</li>
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
    for $child in xmldb:get-child-collections($collection)[not(contains(., "."))]
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
    let $log := util:log("debug","GET SIMPLE LISTING FOR COLLECTION " || $colName)
    let $sublists := (templates:display-collections-list($colName), templates:display-templates-list($colName))
	return if ($sublists) then
	<ul>{$sublists}
	</ul> 
	else ()
};

declare function templates:get-meta-file-name($file) {
   concat($file,"/pekoe-meta.xml")
};

declare function templates:get-phlinks($template) {
(:
    GOT:	/db/pekoe/tenants/<tenant>/templates/todo.txt
    WANT:   /db/pekoe/tenants/<tenant>/templates/todo.txt/ph-links.txt
    
    There are other ways to handle this.
    First, the template code could manage all the template stuff so you run a switch and then a function.
    That sounds boring. Too much work every time. Stick with the collection-as-document-bundle approach.
    
    Also, going to want DEFAULT templates
    /db/pekoe/templates
    /db/pekoe/schemas
    /db/pekoe/files?
    /db/pekoe/resources
    /db/pekoe/tenants
    
    and then wrap with additional info ... from Config?
    with a doctype basis? which means getting the doctype from the ph-links FIRST
:)

(:    let $doc-name := collection($template)/ph-links (\:templates:get-meta-file-name($template):\):)
(:    let $links := doc($doc-name)//ph-links:)
    let $links := collection($template)/ph-links
    let $doctype := $links/data(@for)
(:  This could be made more specific by including the template type (e.g. docx or text)   :)
(:TODO add the tenant path here:)
(:    let $site-commands := doc("/db/pekoe/config/site-commands.xml")//commands[@for eq $doctype]
    let $template-commands := $links/commands:)
    
    return $links
(:        <template name='{$template}' >
            <commands>
                {$site-commands/*}
            </commands>
            {$links}
        </template>:)
};
