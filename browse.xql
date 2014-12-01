xquery version "3.0";
(: 
    Top-level List View: browse files, xqueries and collections.
    This file has setUid applied. It will run as admin.
    THIS FILE HAS SETUID APPLIED. IT WILL RUN AS ADMIN.
:)


(:declare namespace browse = "http://www.gspring.com.au/file-browser";:)
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "html5";
declare option output:media-type "text/html";

(:import module namespace permissions = "http://www.gspring.com.au/pekoe/admin-interface/permissions"  at "admin/permissions.xqm";:)
import module namespace list-wrapper = "http://pekoe.io/list/wrapper" at "list-wrapper.xqm";


declare variable $local:default-user := "pekoe-staff";
declare variable $local:default-group := "staff";
declare variable $local:default-pass := "staffer";
declare variable $local:open-for-editing :=       "rwxr-----";
declare variable $local:closed-and-available :=   "r--r-----"; 
declare variable $local:xquery-permissions :=     "rwxr-xr--";
declare variable $local:collection-permissions := "rwxrwx---";

declare variable $local:root-collection := "/db/pekoe";
declare variable $local:base-collection := "/files";
declare variable $local:filter-out := ("xqm","xsl");
declare variable $local:action := request:get-parameter("action","browse");
declare variable $local:tenant := replace(request:get-cookie-value("tenant"),"%22","");
declare variable $local:tenant-path := "/db/pekoe/tenants/" || $local:tenant;
 

(: Doctypes are provided by the schema@for attributes. :)
declare function local:doctype-options() {
    let $general-doctypes := collection("/db/pekoe/schemas")/schema/@for/data(.) 
    let $current-col := request:get-parameter("collection",())
(:  maybe this should be specific to the tenant rather than the current collection? :)
    let $local-doctypes := collection($local:tenant-path)/schema/@for/data(.)
    for $dt in ($general-doctypes, $local-doctypes)
    order by $dt
    return <option>{$dt}</option>
};

declare function local:get-request-as-number($param as xs:string, $default as xs:integer) as xs:integer {
    let $requested := request:get-parameter($param, "")
    return if ($requested castable as xs:integer) then xs:integer($requested) else $default 
};

declare function local:get-paged-items($items) {
    
    let $rp := local:get-request-as-number("rp",10)
    let $cp := local:get-request-as-number("p",1)
    let $count := count($items)
    let $total-pages := ceiling($count div $rp)
    let $start-index := ($cp - 1) * $rp + 1 
    let $end-index := $start-index + $rp - 1
    return  
    <page>
        <start>{$start-index}</start>
        <end>{$end-index}</end>
        <rp>{$rp}</rp>
        <current>{$cp}</current>
        <pages>{$total-pages}</pages>
        <count>{$count}</count>
    </page>
};

(:
    Display the contents of a collection in a table view.
:)

declare function local:quarantined-path($real-path) {
    substring-after($real-path, $local:tenant-path)
};
  
(:%rest:GET
%rest:path("/pekoe/tenant/{$tenant}/browse")
%rest:query-param("collection","{$colpath}", "/files")
%rest:query-param("search","{$searchstr}","")
%output:media-type("text/html")
%output:method("html5"):)
declare function local:display-collection($colpath) 
{

    let $searchstr := request:get-parameter("searchstr", ())
    let $colName := $local:tenant-path || $colpath (: $colpath is expected to start with a slash :)
    let $paging := local:get-paged-items((xmldb:get-child-collections($colName),xmldb:get-child-resources($colName))) 
    let $callback-name := util:uuid()
    let $parent-col := local:get-parent-collection($colName)
(:    let $searchstr := request:get-parameter("searchstr",""):)
    let $xpath := request:get-parameter("xpath","")
    return
        (
        (:response:set-header("Content-type","text/html"),:)
        <div>
            <div title="collection:{$colName}" class='action search'>
            <form method="GET">
                <input type='hidden' name='collection' value='{$colpath}' />
                <input type='text' name='searchstr' value='{$searchstr}' />
                <input type="submit" value="Search" name="action" />
                </form>
            </div>
            <div title="collection:{$colName}" class='action xpath'>
                <input type='text' name='xpath' value='{$xpath}' id='xpath{$callback-name}' size='60'/>
                <input type="submit" value="XPath Search" name="action" />
            </div>
            {
            (: 
            Regarding the XPath (above). If I can somehow attach an autocomplete on this how should it work?
            from my perspective, I'd want the smallest significant path - eg 
            //meeting[contains(., 'Ruth')]
            
            but from a user perspective, with no knowledge of XPath,
            they want a guided tour: show me the Start (root elements)
            (and you could stop at that point too - /meeting[contains(., 'Ruth')] is fine )
            but they might want the next level 
            /meeting ???
            PLUS this helps to distinguish between /school/id and /school-booking/id or one of the many "name" elements. 
            
            (regarding the "new" below)
            Here's where I'd like an ACL:
                I'd like to say "Does the user have create-permissions in this directory? 
                Better still, WHAT can they create?
                
                So - i want the person to be an Admin member AND a member of the current group
                OR
                Maybe I want to limit the schemas according to type. 
                Perhaps the schemas have permissions?
                
            :)
            
(:            if (xmldb:is-admin-user(xmldb:get-current-user()) ) then :)
               if (true()) then 
               <div title="collection:{$colName}" class='action new'>
                 Make a new:  
                 <form method="GET">
                    <select name='doctype' >
                        <option></option>
                        <option value="collection">Folder</option>
                        <option disabled="disabled" style='color:#AAAAAA; background-color:#EEEEEE;padding-top:3px;'>Schemas:</option>
                    {
(: What if the schemas were collection-dependant. So schemas defined in files/schemas could be "global" and 
   schemas defined elsewhere would be only available to the collection and sub-collections. 
   That would mean the schema would be sitting in the top-level which might not be so good. 
   But it would also ensure that group A Admins could only see group A schemas. 
   
   :)
                       local:doctype-options()
                    }
                    </select> named: <input type='text' name='file-name' />
                    <input type='submit' class='list' name='action' value='New' /> (in {$colName})
                    </form>
               </div> 
            else () }
            
            <table id='{$callback-name}' class='table'>
                <tr>
                    <th>Name</th>
                    <th>Permissions</th>
                    <th>Owner</th>
                    <th>Group</th>
                    <th>Created</th>
                    <th>Modified</th>
                    <th>Size/Nodes*</th>
                </tr>
            
            {
(:  **** Here's where the paging doesn't work: there's no single batch of items. NOTE: A little re-writing would help!   ***   
    This approach doesn't match the "selected-resources first" method I use in custom XQueries. Perhaps it should. 
    The advantage of the other approach is that displaying search results is easy and requires little change to the
    output process.
:)
                local:display-child-collections($colName),
                local:display-child-resources($colName)
            }
        </table>

    <script type='text/javascript'> 
    gs["{$callback-name}"] = {{
        rp: {$paging/rp/text()},
		page: {$paging/current/text()},
		pages:{$paging/pages/text()},
		cp: {$paging/current/text()}, 
        usepager:false 
    }};
     gs["f:{$callback-name}"] = function () {{
            console.log('apply autocmplete to ',jQuery("#xpath{$callback-name}"));
            // or don't
            // jQuery("#xpath{$callback-name}").autocomplete({{"source":"browse.xql?action=JSON", minLength:3}});
        }};
    </script>
    </div>
    )
};
(: //gs["{$callback-name}"] = {{cp: {$paged-items[4]}, rp:{$paged-items[3]}, page:{$paged-items[4]}, pages:{$paged-items[5]}, usepager:false }}; :)

declare function local:display-child-collections($colName as xs:string) as element()* {

    let $rootpath := local:quarantined-path($colName)
    for $child in xmldb:get-child-collections($colName)
    let $path := concat($colName,"/", $child),
        $created := xmldb:created($path) 
    order by $child
    return
    <tr title='collection:{$path}' class='collection'>
        <td class='tablabel'><a href="?collection={$rootpath}/{$child}">{$child}</a></td>
        <td class="perm">{xmldb:permissions-to-string(xmldb:get-permissions($path))}</td>
        <td>{xmldb:get-owner($path)}</td>
        <td>{xmldb:get-group($path)}</td>
        <td>{format-dateTime($created,"[D01] [M01] [Y0001] [H01]:[m01]:[s01]")}</td>
        <td/>
        <td/>
    </tr>
};

(: The quarantine model sucks. It means that all the queries must know the collection-root.
   It will be better to simply check for an xquery. 
:)
declare function local:display-child-resources($colName as xs:string) as element()* {
    let $children := xmldb:get-child-resources($colName)
    let $collection-owner := xmldb:get-group($colName)
    
    (:  A general comparison = must return false for every item to be false. Conversely, != only needs to be true of one item  :)
    for $child in $children[not(substring-after(.,".") = $local:filter-out)]
    
    let $file-path := concat($colName,"/",$child)
    let $names := tokenize($child,"\.")
    let $class := ($names[2], "unknown")[1] (: failsafe :)
    
(:    want to add a target so that the page can open a new tab. Also want to give the user the option to open in an new tab. :)
    
    let $owner := xmldb:get-owner($colName, $child)
    let $owner-is-me := $owner eq xmldb:get-current-user()
    let $smp := sm:get-permissions(xs:anyURI($file-path))
    let $read-permissions := $smp//@mode = ($local:closed-and-available, $local:xquery-permissions)
    let $locked-class :=  (:if (not($read-permissions)) then "locked" else ():)
        if ($read-permissions) then $class
        else if ($owner-is-me) then concat($class, " locked-by-me") 
        else " locked"

    let $short-name := $names[1]
    let $available := if (util:is-binary-doc($file-path)) then util:binary-doc-available($file-path) else doc-available($file-path)
    let $doctype := if ($available and ($class eq "xml"))
        then name(doc($file-path)/*)
        else $class
    let $title := if ($read-permissions or $owner-is-me) then concat($doctype,":", $file-path) else $owner
    let $size-indicator := 
        if (util:is-binary-doc($file-path)) then string(ceiling(xmldb:size($colName, $child) div 1024)) || "k"
        else string(count(doc($file-path)/descendant-or-self::node())) || "*"
        
    order by index-of(("xql","xml","unknown"),$class),  lower-case($child)
    return
        if (not($available)) then () else
       
        <tr title='{$title}' class='{string-join(($locked-class,$doctype)," ")}'>
            <td class='tablabel'><a href="/pekoe-form/index.html?job={$title}">{$short-name}</a></td>
            <td class="perm">{xmldb:permissions-to-string(xmldb:get-permissions($colName, $child))}</td>
            <td>{$owner}</td>
            <td>{xmldb:get-group($colName, $child)}</td>
            <td>{if ($available) then format-dateTime(xmldb:created($colName, $child),"[D01] [M01] [Y0001] [H01]:[m01]:[s01]") else ()}</td>
            <td>{if ($available) then format-dateTime(xmldb:last-modified($colName, $child),"[D01] [M01] [Y0001] [H01]:[m01]:[s01]") else ()}</td>
            <td>{if ($available) then $size-indicator else ()}</td>
        </tr>
};

(:
    What I really want here is a TAG type behaviour. 
    But not quite - because if this is going to start at "whatever roots" 
    then the user shouldn't type anything. In fact, on FOCUS, 
    I should show the roots. On selection 
    
    Better still, what if the Javascript constructed the XPath
    //meeting[contains(.,'Ruth')]
    Then, the XPath could be handled by the controller, and sent back to the browser in a paged set like the Sandbox does.  
    :)
declare function local:json-xpath-lookup() {

    '[',string-join(
    let $col := request:get-parameter("collection", $local:base-collection)
    let $roots := for $n in distinct-values(collection($col)/*/name(.))
order by $n
return $n

for $r in $roots
let $path := concat('distinct-values(collection("', $col, '")/',$r, '/*/name(.))')
let $children := util:eval($path)
let $results :=  for $c in $children return concat($r,'/',$c)
return 
concat('["',string-join($results,'", "'),'"]')
, ",")
   ,']'

};


(: the problem with this search at the moment is that it returns a file without showing where the result is.
    What Carolyn wants is a search that lets her double click to edit the specific meeting. 
:)
declare function local:xpath-search() {
    let $col := request:get-parameter("collection", $local:base-collection)
    let $search := request:get-parameter("xpath",())
    let $callback-name := util:uuid()
    let $xpathsearch := concat("collection('",$col,"')", $search)
    
    let $log := util:log("debug", concat("################################### XPATH Search: ",$xpathsearch) )
    (: why not iterate over the actual results? Probably will include parent elements. :)
    let $found  := util:eval($xpathsearch) (: get all the result nodes :)
    let $files := (for $f in $found return root($f))/.
    let $paging := local:get-paged-items($files) 
    let $response := response:set-header("Content-type","text/html")
    return 
    <div>
    <table id='{$callback-name}'>
        <tr><th>Path</th><th>Doctype</th><th>Field</th><th>Context</th></tr>
        {
            for $f in $files[position() = $paging/start to $paging/end]
            let $f-col := util:collection-name($f)
            let $f-name := util:document-name($f)
            let $file-path := document-uri($f)
            
            let $class := "xml"
            
            let $owner := xmldb:get-owner($f-col, $f-name)
            let $owner-is-me := $owner eq xmldb:get-current-user()
            
            let $smp := sm:get-permissions(xs:anyURI($file-path))
            let $read-permissions := $smp//@mode = ($local:closed-and-available, $local:xquery-permissions)
            let $locked-class :=  (:if (not($read-permissions)) then "locked" else ():)
                if ($read-permissions) then $class
                else if ($owner-is-me) then concat($class, " locked-by-me") 
                else " locked"
        
            let $short-name := substring-before($f-name,'.')
            let $available := if (util:is-binary-doc($file-path)) then util:binary-doc-available($file-path) else doc-available($file-path)
            let $doctype := if ($available and ($class eq "xml"))
                then name($f/*)
                else $class
            let $title := if ($read-permissions or $owner-is-me) then concat($doctype,":", $file-path) else $owner
            return if (not($available)) then () else
            <tr title='{$title}' class='{string-join(($locked-class,$doctype)," ")}'>
                <td class='tablabel'>{document-uri($f)}</td>
                <td>{name($f/*)}</td>
                <td>--</td>
                <td>--</td>
            </tr>
        }
    </table>
    
    <script type='text/javascript'> 
    gs["{$callback-name}"] = {{
        rp: {$paging/rp/text()},
		page: {$paging/current/text()},
		pages:{$paging/pages/text()},
		cp: {$paging/current/text()}, 
        usepager:true 
    }};
    </script>
    </div>
};

declare function local:display-search-results($colName) {
    let $colpath := $local:tenant-path || $colName
    let $col := collection($colpath ) (:Base collection for search:)
    let $callback-name := util:uuid()
(:    Note: a range index will be used if defined - otherwise brute force. This one should probably be a full-text index. But it would need to be defined. 
        The NEW range index supports general comparisons (eq etc), plus starts-with, ends-with and contains. Not matches. Matches requires the old range index.
        New index is
        <range>
            <create qname="mods:namePart" type="xs:string" case="no"/>
            <create qname="mods:dateIssued" type="xs:string"/>
            <create qname="@ID" type="xs:string"/>
        </range>
        
        old index is without the <range>
:)
    let $searchString := request:get-parameter("searchstr",())
    let $files := for $n in $col/*[contains(., $searchString)] return root($n)
    let $paging := local:get-paged-items($files) 
(:    let $response := response:set-header("Content-type","text/html"):)
    return
   
    <div>
    <table id='{$callback-name}'>
        <tr><th>Path</th><th>Doctype</th><th>Field</th><th>Context</th></tr>
        {
            for $f in $files[position() = $paging/start to $paging/end]
            let $f-col := util:collection-name($f)
            let $f-name := util:document-name($f)
            let $file-path := document-uri($f)
            
            let $class := "xml"
            
            let $owner := xmldb:get-owner($f-col, $f-name)
            let $owner-is-me := $owner eq xmldb:get-current-user()
            
            let $smp := sm:get-permissions(xs:anyURI($file-path))
            let $read-permissions := $smp//@mode = ($local:closed-and-available, $local:xquery-permissions)
            let $locked-class :=  (:if (not($read-permissions)) then "locked" else ():)
                if ($read-permissions) then $class
                else if ($owner-is-me) then concat($class, " locked-by-me") 
                else " locked"
        
            let $short-name := substring-before($f-name,'.')
            let $available := if (util:is-binary-doc($file-path)) then util:binary-doc-available($file-path) else doc-available($file-path)
            let $doctype := if ($available and ($class eq "xml"))
                then name($f/*)
                else $class
            let $title := if ($read-permissions or $owner-is-me) then concat($doctype,":", $file-path) else $owner
            return if (not($available)) then () else
            <tr title='{$title}' class='{string-join(($locked-class,$doctype)," ")}'>
                <td class='tablabel'>{document-uri($f)}</td>
                <td>{name($f/*)}</td>
                <td>--</td>
                <td>--</td>
            </tr>
        }
    </table>
    
    <script type='text/javascript'> 
    gs["{$callback-name}"] = {{
        rp: {$paging/rp/text()},
		page: {$paging/current/text()},
		pages:{$paging/pages/text()},
		cp: {$paging/current/text()}, 
        usepager:true 
    }};
    </script>
    </div>
};

(:
    Get the name of the parent collection from a specified collection path.
:)
declare function local:get-parent-collection($path as xs:string) as xs:string {
    if($path eq "/db") then
        $path
    else
        replace($path, "/[^/]*$", "")
};
(:  This is nice, but doesn't add an ID and allows creation of fragment-elements (like "item" which is a child of ca-resources) :)
declare function local:new-file($doctype, $colname,$file-name) {
    let $new-file := element {$doctype} {
        attribute created-by {xmldb:get-current-user()}, 
        attribute created-dateTime {current-dateTime()}
        }
    return xmldb:store($colname, $file-name, $new-file)
};

declare function local:good-file-name($n,$type) {
    if ($type ne 'collection') 
    then concat(replace(tokenize($n,"\.")[1],"[\W]+","-"), ".xml")
    else replace(tokenize($n,"\.")[1],"[\W]+","-")
};

(:
    So for functions inside /db/apps/pekoe - which are common for all tenants - it might be 
    useful to setUid as admin (or another specific dba user) on those scripts
    so that the script can execute system:as-user(group-user, standard-password, code-block)
    Then, any resources will be owned by the group-user.
    setGid will ensure that all collections and resources in a tenancy will belong to the group-user.

:)
(:
declare function local:new-collection($group-user, $full-path, $file-name){
    xmldb:create-collection($full-path,$file-name),
    let $new-resource := $full-path || '/' || $file-name
    
};:)

declare function local:do-new($colname) {
    let $full-path := $local:tenant-path || $colname
    let $log := util:log("warn","FULL PATH IS " || $full-path)
    let $item-type := request:get-parameter("doctype","") 
    let $group-user := sm:get-permissions(xs:anyURI($full-path))//@group/string()   
    let $file-name := local:good-file-name(request:get-parameter("file-name",""),$item-type)
(:    let $redirect-path := response:set-header("RESET_PARAMS","action=browse") (\:The header MUST have a value or it won't be received by the client:\):)
    return 
        if ($item-type eq "" or $file-name eq "") then local:display-collection($colname)
        else 
        let $result :=  
            if ($item-type eq "collection")            
            then system:as-user($group-user, "staffer", xmldb:create-collection($full-path,$file-name)) (: TODO fix permissions and ownership :)
            else local:new-file($item-type,$full-path,$file-name)
        return local:display-collection($colname)
};


let $path := request:get-parameter("collection",$local:base-collection)
let $path-parts := tokenize(substring-after($path,"/"),"/")
let $base := '?collection=' (:/exist/rest/db/apps/pekoe/browse.xql:)
let $content := <content>
    <title>{let $t := $path-parts[position() eq last()]
    return concat(upper-case(substring($t,1,1)), substring($t,2))}</title>
    <path>{list-wrapper:breadcrumbs($base, $path)}</path>
    <tenant>{$local:tenant}</tenant>
    <body>
    {
(: browse is the default action :)
     if ($local:action eq "browse") then local:display-collection($path)
else if ($local:action eq "Search") then local:display-search-results($path)
else if ($local:action eq "XPath Search")  then local:xpath-search()
else if ($local:action eq "JSON")   then local:json-xpath-lookup()
else if ($local:action eq "New")    then local:do-new($path)
else <result status='error'>Unknown action {$local:action} </result>
}</body>
</content>
return list-wrapper:wrap($content)
