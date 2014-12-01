xquery version "3.0";
module namespace tenant = "http://pekoe.io/tenant";
(: Module is used directly by admin when creating a new tenant.
   Module is called by others if a list of tenants is needed.
:)
import module namespace pekoe-http = "http://pekoe.io/http" at "modules/http.xqm";


declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare variable $tenant:pekoe-tenants := '/db/pekoe/tenants';


declare 
%rest:GET
%rest:path("/pekoe/tenant")
(:
%rest:produces("application/json"):)
%output:media-type("application/xml")
(:%output:media-type("application/json")
(\:%output:encoding("UTF-8"):\)
%output:method("json"):)
function tenant:list() {
    <tenants for="{xmldb:get-current-user()}">{ 
    (: The advantage of simply looking at /db/pekoe/tenants is I don't need to check if the user 
        is authorized - xmldb:collection-available will do that for me. :)
    for $t in xmldb:get-child-collections($tenant:pekoe-tenants)
    let $coll := $tenant:pekoe-tenants || "/" || $t
(:    return if (not(xmldb:collection-available($coll))) then ():)
        return if (not(sm:has-access(xs:anyURI($coll), 'r--'))) then ()
        else
    
        let $tenant-name := doc($coll || "/config/tenant.xml")//name/string(.)
        return 
            <tenant key="{$t}" name="{$tenant-name}" />
    }</tenants>
};

declare function tenant:good-name($key) as xs:boolean {
    matches($key,"^[A-Za-z0-9]([A-Za-z0-9\-]{0,61}[A-Za-z0-9])?$")
};


declare
%rest:POST
%rest:path("/pekoe/admin/tenant")
%rest:produces("application/json")
%output:media-type("application/json")
%output:method("json")
function tenant:add($key) {
(: Tenants file should be readable by who? Registered users? Why?
tenants file should only be writeable by dba.  Do I need to test? 
Do I need a tenants file?
:)
    if (not(tenant:good-name($key))) then 
    (<rest:response>
        <http:response status="{$pekoe-http:HTTP-400-BADREQUEST}"/>
    </rest:response>,
    <error>Not a good name</error>
    )
    else if (tenant:exists($key)) then
    (<rest:response>
        <http:response status="{$pekoe-http:HTTP-400-BADREQUEST}">
        </http:response>
    </rest:response>,
    <error>already exists</error>
    )
    
    else     <rest:response>
        <http:response status="{$pekoe-http:HTTP-201-CREATED}">
            <http:header name="Location" value="/exist/restxq/pekoe/tenant/{$key}"/>
        </http:response>
    </rest:response>

(:
 - check for existing and return 200 OK
 - Add a group
:)
};

declare function tenant:exists($key) {
    if (xmldb:collection-available("/db/pekoe/tenants/" || $key))
    then 
    <rest:response>
        <http:response status="{$pekoe-http:HTTP-200-OK}">
            <http:header name="Location" value="/exist/restxq/pekoe/tenant/{$key}"/>
        </http:response>
    </rest:response>
    else false()
};

(: Recursively apply ownership to a collection hierarchy :)
declare function tenant:fix-ownership($collection, $staff-name) {
    sm:chown($collection,$staff-name),
    sm:chgrp($collection,$staff-name),
(:    xmldb:set-collection-permissions($collection,$staff-name,$staff-name,sm:mode-to-octal('r-xr-x---')),:)
(: -----------------------------------------             MUST use setGid on collections after setting the correct group-owner. :)
    for $r in xmldb:get-child-resources($collection)
    let $resource := $collection || "/" || $r
    return (sm:chown($resource,$staff-name),sm:chgrp($resource,$staff-name)),
    for $c in xmldb:get-child-collections($collection)
    let $coll := $collection || "/" || $c
    return tenant:fix-ownership($coll,$staff-name)
};

declare function tenant:create-tenant-user($key) as xs:string { (: returns $key_staff :)
    let $admin-group-name := $key || "_admin"
    let $admin-users := if (not(sm:group-exists($admin-group-name))) then sm:create-group($admin-group-name, "Admin users for " || $key) else ()
    let $tenant-staff-name := $key || "_staff"
(:  $key_staff group will be created automatically :)
    let $tenant-owner := if (not(sm:user-exists($tenant-staff-name))) then sm:create-account($tenant-staff-name,"staffer",()) else ()
(:    let $tenant-owner-disabled := sm:set-account-enabled($tenant-staff-name,false()):)
    
    return $tenant-staff-name
};


declare function tenant:copy-template($new-tenant, $key) {
    if (not(exists(collection($new-tenant)))) then
        (
            xmldb:copy("/db/apps/pekoe/tenant-template","/db/pekoe/tenants"),
            sm:chmod(xs:anyURI("/db/pekoe/tenants/tenant-template"), 'rwxrwx---'),
            xmldb:rename("/db/pekoe/tenants/tenant-template", $key)
        )
    else ()
};
declare function tenant:create($key, $client-name){

(:    Use a tenant-template. Only have to reset ownership.     :)
    let $tenant-staff-name := tenant:create-tenant-user($key)
    let $new-tenant := "/db/pekoe/tenants/" || $key
    let $make-tenant-coll := tenant:copy-template($new-tenant,$key)
    
(:    let $permissions := xmldb:set-collection-permissions($new-tenant,$tenant-staff-name,$tenant-staff-name,sm:mode-to-octal('rwxrwx---')):)
    let $permissions := tenant:fix-ownership($new-tenant, $tenant-staff-name)
    let $conf := doc($new-tenant || "/config/tenant.xml")/tenant
    let $conf-id := update value $conf/@id  with $key
    let $conf-name := update value $conf/name with $client-name
    return 
    
    $new-tenant
};