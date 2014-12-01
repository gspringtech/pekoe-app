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
declare variable $local:xquery-permissions :=     "rwxr-x---";
declare variable $local:collection-permissions := "rwxrwx---";

declare variable $local:root-collection := "/db/pekoe";
declare variable $local:base-collection := "/files";
declare variable $local:filter-out := ("xqm","xsl");
declare variable $local:action := request:get-parameter("action","browse");
declare variable $local:tenant := replace(request:get-cookie-value("tenant"),"%22","");
declare variable $local:tenant-path := "/db/pekoe/tenants/" || $local:tenant;
declare variable $local:current-user := sm:id()//sm:real;


(:
<sm:id xmlns:sm="http://exist-db.org/xquery/securitymanager">
    <sm:real>
        <sm:username>admin</sm:username>
        <sm:groups>
            <sm:group>perskin@conveyancingmatters.com.au</sm:group>
            <sm:group>tdbg@thedatabaseguy.com.au</sm:group>
            <sm:group>jerskine@conveyancingmatters.com.au</sm:group>
            <sm:group>dba</sm:group>
        </sm:groups>
    </sm:real>
</sm:id>
:)
 

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

(:
    Display the contents of a collection in a table view.
:)

declare function local:quarantined-path($real-path) {
    substring-after($real-path, $local:tenant-path)
};

declare function local:table-wrapper($path, $colName, $rows) {
    let $searchstr := request:get-parameter("searchstr", ())
    let $xpath := request:get-parameter("xpath","")
    return
  <div>
            <div title="collection:{$colName}" class='action search'>
                <span class='pull-left btn' data-href='/exist/pekoe-app/files.xql?action=Search&amp;collection={$path}' 
                    data-title='Search {$path}' 
                    data-type='search'
                    data-params='searchstr'><i class='glyphicon glyphicon-bookmark'/></span>
                    <form method="GET">
                    <input type='hidden' name='collection' value='{$path}' />
                    <input type='text' name='searchstr' value='{$searchstr}' />
                    <input type="submit" value="Search" name="action" />
                </form>
                
            
            </div>
            <div title="collection:{$colName}" class='action xpath'>
                <input type='text' name='xpath' value='{$xpath}' id='xpath' size='60'/>
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
            
(:   This should be updated         if (xmldb:is-admin-user(xmldb:get-current-user()) ) then :)
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
            
            <table class='table'>
                <tr>
                    <th>Name</th>
                    <th>Permissions</th>
                    <th>Owner</th>
                    <th>Group</th>
                    <th>Created</th>
                    <th>Modified</th>
                    <th>Size/Nodes*</th>
                </tr>
            
            { $rows }
        </table>
        <script type='text/javascript'> 
        var gs;
        // run this when loaded...
                // console.log('apply autocmplete to ',jQuery("#xpath"));
                // or don't
                // jQuery("#xpath").autocomplete({{"source":"browse.xql?action=JSON", minLength:3}});
        </script>
    </div>
    
};
  

(:
    This is the main list query.
    Currently, it lacks SORTING and should incorporate the Text and XPath searches
:)
declare function local:display-collection() 
{
    let $logical-path := request:get-parameter("collection",$local:base-collection)
    
    let $real-collection-path := $local:tenant-path || $logical-path (: $colpath is expected to start with a slash :)

    
    let $collections := xmldb:get-child-collections($real-collection-path)
    let $queries := xmldb:get-child-resources($real-collection-path)[substring-after(.,".") eq 'xql']
    let $resources := xmldb:get-child-resources($real-collection-path)[substring-after(.,".") eq 'xml']
    let $params := "collection=" || $logical-path
    let $pagination-map := list-wrapper:pagination-map($params, ($collections,$queries,$resources)) (: Count the items, work out start and end indices. :)
    
(:    let $parent-col := local:get-parent-collection($real-collection-path):)
    let $count := count($collections)
    let $col-rows := for $c in $collections[position() = $pagination-map('start') to $pagination-map('end')] order by $c return local:format-collection($logical-path, $real-collection-path, $c)
    let $start := $pagination-map('start') - $count + 1,
        $end := $pagination-map('end') - $count,
        $count := count($queries)
    let $query-rows := for $c in $queries[position() = $start to $end] order by $c return local:format-query($logical-path, $real-collection-path, $c)
    let $start := $start - $count + 1,
        $end := $end - $count,
        $count := count($resources)
    let $resource-rows := for $c in $resources[position() = $start to $end] order by $c return local:format-resource($logical-path, $real-collection-path, $c)
    let $results := map {
        'title' := $logical-path,
        'path' := $logical-path,
        'body' := local:table-wrapper($logical-path, $real-collection-path, ($col-rows,$query-rows,$resource-rows)),
        'pagination' := list-wrapper:pagination($pagination-map),
        'breadcrumbs' := list-wrapper:breadcrumbs('/exist/pekoe-app/files.xql?collection=', $logical-path)
        }
    return
       list-wrapper:wrap($results)
      
};

declare function local:format-collection($logical-path, $real-collection-path, $child) {
    let $path := $real-collection-path || '/' || $child
 
    let $permissions := sm:get-permissions(xs:anyURI($path)),
        $created := xmldb:created($path) 
    return
    <tr class='collection' data-href='/exist/pekoe-app/files.xql?collection={$logical-path}/{$child}' data-title='{$child}' data-type='html'>
        <td>{$child}</td>
        <td class="perm">{string($permissions/sm:permission/@mode)}</td>
        <td>{string($permissions/sm:permission/@owner)}</td>
        <td>{string($permissions/sm:permission/@group)}</td>
        <td>{format-dateTime($created,"[D01] [M01] [Y0001] [H01]:[m01]:[s01]")}</td>
        <td/>
        <td/>
    </tr>
};


declare function local:format-query($logical-path, $real-collection-path, $child) as element()* {
    let $path := $real-collection-path || '/' || $child

    let $permissions := sm:get-permissions(xs:anyURI($path)),
        $created := xmldb:created($real-collection-path, $child),
        $modified := xmldb:last-modified($real-collection-path, $child)
    return
    <tr class='xql' data-href='/exist/pekoe-files/{$logical-path}/{$child}' data-title='{$child}' data-type='html'>
        <td>{$child}</td>
        <td class="perm">{string($permissions/sm:permission/@mode)}</td>
        <td>{string($permissions/sm:permission/@owner)}</td>
        <td>{string($permissions/sm:permission/@group)}</td>
        <td>{format-dateTime($created,"[D01] [M01] [Y0001] [H01]:[m01]:[s01]")}</td>
        <td>{format-dateTime($modified,"[D01] [M01] [Y0001] [H01]:[m01]:[s01]")}</td>
        <td/>
    </tr>
};

declare function local:format-resource($logical-path, $real-collection-path, $child) {
    let $file-path := concat($real-collection-path,"/",$child) (: This is the real path in the /db :)
        return if (not(sm:has-access(xs:anyURI($file-path),'r'))) then ()
        else 
        let $safe-path := local:quarantined-path($file-path)

        (:  Owner and permissions      :)
        let $smp := sm:get-permissions(xs:anyURI($file-path))
        
        (:        <sm:permission xmlns:sm="http://exist-db.org/xquery/securitymanager" owner="tdbg_staff" group="tdbg_staff" mode="r-xr-x---">
                    <sm:acl entries="0"/>
                </sm:permission>
        :)
        
        let $owner := string($smp//@owner)
        let $current-user := string($local:current-user/sm:username)
        let $owner-is-me := $owner eq $current-user

        let $permission-to-open := $smp//@mode eq $local:closed-and-available

    
        let $short-name := substring-before($child, ".")
        let $doctype := name(doc($file-path)/*) 
        let $href := $doctype || ":/exist/pekoe-files" || $safe-path
        let $size-indicator := string(count(doc($file-path)/descendant-or-self::node())) || "*"

        order by lower-case($child)
        return
            <tr>
               {
                if ($owner-is-me or $permission-to-open) 
                then (
                    attribute title {$href},
                    attribute class {if ($owner-is-me) then "locked-by-me xml" else "xml"},
                    attribute data-href {$href},
                    attribute data-title {$short-name},
                    attribute data-type {'form'},
                    attribute data-target {'other'}
                )
                else (
                    attribute title {$owner},
                    attribute class {"locked xml"}
                )
               
               }
                <td class='tablabel'>{$short-name}</td>
                <td class="perm">{xmldb:permissions-to-string(xmldb:get-permissions($real-collection-path, $child))}</td>
                <td>{$owner}</td>
                <td>{xmldb:get-group($real-collection-path, $child)}</td>
                <td>{format-dateTime(xmldb:created($real-collection-path, $child),"[D01] [M01] [Y0001] [H01]:[m01]:[s01]")}</td>
                <td>{format-dateTime(xmldb:last-modified($real-collection-path, $child),"[D01] [M01] [Y0001] [H01]:[m01]:[s01]")}</td>
                <td>{$size-indicator}</td>
            </tr>
};

    
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
    let $paging := list-wrapper:pagination-map("collection=" || $col, $files) 
    let $response := response:set-header("Content-type","text/html")
    return 
    <div>
    <table id='{$callback-name}' class='table'>
        <tr><th>Path</th><th>Doctype</th><th>Field</th><th>Context</th></tr>
        {
            for $f in $files[position() = $paging('start') to $paging('end')]
            let $f-col := util:collection-name($f)
            let $f-name := util:document-name($f)
            let $file-path := document-uri($f)
            
            let $file-type := "xml"
            
            let $owner := xmldb:get-owner($f-col, $f-name)
            let $owner-is-me := $owner eq sm:id()//sm:username
            
(:            Most of this is replication of code in resource-management - but it can't be imported because it uses sm:id :)
            let $smp := sm:get-permissions(xs:anyURI($file-path))
            let $read-permissions := $smp//@mode = ($local:closed-and-available, $local:xquery-permissions)
            let $locked-class :=  (:if (not($read-permissions)) then "locked" else ():)
                if ($read-permissions) then $file-type
                else if ($owner-is-me) then concat($file-type, " locked-by-me") 
                else " locked"
        
            let $short-name := substring-before($f-name,'.')
            let $available := if (util:is-binary-doc($file-path)) then util:binary-doc-available($file-path) else doc-available($file-path)
            let $doctype := if ($available and ($file-type eq "xml"))
                then name($f/*)
                else $file-type
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
    
    </div>
};

declare function local:display-search-results() {
    let $path := request:get-parameter("collection",$local:base-collection)
    let $colpath := $local:tenant-path ||  $path
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
    let $debug := util:log('debug', 'SEARCH FOR STRING ' || $searchString || ' IN COLLECTION ' || $colpath)
    let $files := for $n in $col/*[contains(., $searchString)] return root($n)
    let $paging := list-wrapper:pagination-map("collection=" || $path, $files) 
    return
   
    <div>
    <table class='table'>
        <tr><th>Path</th><th>Doctype</th><th>Field</th><th>Context</th></tr>
        {
            for $f in $files[position() = $paging('start') to $paging('end')]
            let $f-col := util:collection-name($f)
            let $f-name := util:document-name($f)
            let $file-path := document-uri($f)
            
(:          This is fairly common for all lists. Pagination, Ownership, File type 
            What changes is the initial SELECTION, and the FIELDS. 
            So Ideally I would be passing a SELECTION function and a FORMAT RESULTS function
            The FORMAT RESULTS function would be some kind of map or XML structure that provides the TH info
            including SORTing 
            
            In this query, I have about 3 instances of the same code with minor variations. The booking-list is similar.
            Not Identical, but similar.
            The only other major change is that sometimes the "files" are "records" in a single file.
:)
            let $file-type := "xml"
            
            let $owner := xmldb:get-owner($f-col, $f-name)
            let $owner-is-me := $owner eq sm:id()//sm:username
            
            let $smp := sm:get-permissions(xs:anyURI($file-path))
            let $read-permissions := $smp//@mode = ($local:closed-and-available, $local:xquery-permissions)
            let $locked-class :=  (:if (not($read-permissions)) then "locked" else ():)
                if ($read-permissions) then $file-type
                else if ($owner-is-me) then concat($file-type, " locked-by-me") 
                else " locked"
        
            let $short-name := substring-before($f-name,'.')
            let $available := if (util:is-binary-doc($file-path)) then util:binary-doc-available($file-path) else doc-available($file-path)
            let $doctype := if ($available and ($file-type eq "xml"))
                then name($f/*)
                else $file-type
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
        attribute created-by {sm:id()//sm:username/text()}, 
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

declare function local:do-new() {
    let $path := request:get-parameter("collection",$local:base-collection)
    let $full-path := $local:tenant-path || $path
    let $log := util:log("warn","FULL PATH IS " || $full-path)
    let $item-type := request:get-parameter("doctype","") 
    let $group-user := sm:get-permissions(xs:anyURI($full-path))//@group/string()   
    let $file-name := local:good-file-name(request:get-parameter("file-name",""),$item-type)
(:    let $redirect-path := response:set-header("RESET_PARAMS","action=browse") (\:The header MUST have a value or it won't be received by the client:\):)
    return 
        if ($item-type eq "" or $file-name eq "") then local:display-collection()
        else 
        let $result :=  
            if ($item-type eq "collection")            
            then system:as-user($group-user, "staffer", xmldb:create-collection($full-path,$file-name)) (: TODO fix permissions and ownership :)
            else local:new-file($item-type,$full-path,$file-name)
        return local:display-collection()
};

declare function local:title($path-parts) {
    let $t := $path-parts[position() eq last()]
    return concat(upper-case(substring($t,1,1)), substring($t,2))
};

(: ************************** MAIN QUERY *********************** :)

        
        
    (: browse is the default action :)
         if ($local:action eq "browse") then local:display-collection()
    else if ($local:action eq "Search") then local:display-search-results()
    else if ($local:action eq "XPath Search")  then local:xpath-search()
    else if ($local:action eq "JSON")   then local:json-xpath-lookup()
    else if ($local:action eq "New")    then local:do-new()
    else <result status='error'>Unknown action {$local:action} </result>
            