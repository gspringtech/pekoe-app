xquery version "3.0";
(:

There are some basic advantages in using JSON - it's simply much easier to integrate with a Javascript front end like Angular.
However, the disadvantages are becoming more apparent.
1/ Can't easily edit a user-file or the default.
2/ Can't run a script to modify all of them (without jumping through serious hoops)
3/ Can't easily include "default" items into the Bookmarks. (e.g. Files, Welcome, or Admin functions.)


For JSON see p123 of the book (pdf 146)
<container json:array="true"><thing>a</thing></container>
[{thing : 'a'}]

    Multi-tenancy.
    http://docs.stormpath.com/guides/multi-tenant/
    "   So if an application needs this identifier with every request, how do you ensure it is transmitted
        to the application in the easiest possible way for your end users?
        The three most common ways are to use one or more of the following:
       
        Subdomain Name
        Tenant Selection After Login
        Login Form Field
    "
    I'd like to use the first one - but use the second two for special users such as myself
    or other Admin staff.
    
    The first approach is easy:
    cm.pekoe.io -> /db/pekoe/clients/cm
    bkfa.pekoe.io -> /db/pekoe/clients/bkfa
    
    OR 
    cm.pekoe.io -> 
    
    The next step with this is to ensure that a user-group is created for the tenant 
    cm-staff
    cm-admin
    or staff-cm, admin-cm
    
    Get domain (or selected tenant)
    Current user must belong to one of the groups.
    
    Make sure this doesn't conflict with my namespaces. e.g. http://pekoe.io/user-prefs
    
    "If a user from a customer organization ever accesses your app directly (https://mycompany.io) 
    instead of using their subdomain (https://customerA.mycompany.io), 
    you still might need to provide a tenant-aware login form (described below). 
    After login, you can redirect them to their tenant-specific url for all subsequent requests."
    
    They recommend using surrogate and natural KEYs e.g. customerA -> 19C2C28D-0CC6-4FD1-B5BC-84F8E7A8E92D (an UUID)
    to allow the customer name to be changed. 
    I'm using collections - so the advantage of this is limited. 
    /db/pekoe/clients/cm
    /db/pekoe/clients/bkfa
    
    pekoe-user -> CAN LOGIN
    <uuid>-staff -> member of /tenants/tenant[@id = <uuid>] group
    
    If I use a surrogate key, I'll have to look it up all the time to perform any under-the-hood actions. Plus they're long and ugly.
    However, in my CODE, the tenant-id should be abstract and not concern me. 
    
    I'd rather NOT use a surrogate in the User database.
    
    Content will need to be owned by the tenant
    group cm-staff
    
    see http://expath.org/spec/http-client for info on http:response
    
    <http:response status = integer
                  message = string>
   (http:header*,
     (http:multipart |
      http:body)?)
</http:response>                                                                                                                                                                                                                                                                                                                                                                                                                             
    
:)

module namespace prefs = "http://pekoe.io/user-prefs";

import module namespace pekoe-http = "http://pekoe.io/http" at "modules/http.xqm";
import module namespace tenant = "http://pekoe.io/tenant" at "tenants.xql";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

(: If you get here and there's no subdomain that's an error.
    BUT - this makes it hard to test outside of the Request.
:)
declare variable $prefs:selected-tenant := req:header("tenant");
declare variable $prefs:tenant-path := "/db/pekoe/tenants/" || $prefs:selected-tenant ;


declare 
%rest:GET
%rest:path("/pekoe/user/bookmarks")
%rest:produces("application/xml")
%output:media-type("application/xml")
function prefs:get-bookmarks-xml() {
    (:    if there's no tenant set, return a tenant list    :)
    if (sm:has-access(xs:anyURI($prefs:tenant-path),'r--')) then prefs:bookmarks-for-user()
    else <rest:response>
            <http:response status="{$pekoe-http:HTTP-412-PRECONDITIONFAILED}">
                <http:header name="Location" value="/exist/restxq/pekoe/tenant"/>
            </http:response>
        </rest:response>
        
};


declare 
%rest:GET
%rest:path("/pekoe/user/bookmarks")
%rest:produces("application/json")
%output:media-type("application/json")
(:%output:method("json"):)
function prefs:get-bookmarks-json() {
    if (sm:has-access(xs:anyURI($prefs:tenant-path),'r--')) then prefs:json-bookmarks-for-user(xmldb:get-current-user())
    else <rest:response>
            <http:response status="{$pekoe-http:HTTP-412-PRECONDITIONFAILED}">
                <http:header name="Location" value="/exist/restxq/pekoe/tenant"/>
            </http:response>
        </rest:response>
        
};

declare function prefs:json-bookmarks-for-user($current-user) {
    let $prefs-path := $prefs:tenant-path || "/config/users" (: e.g. /db/pekoe/cm/config/users :)
    (: May want to MERGE from default - how can I do this in JSON? :)
    let $default := doc($prefs-path || "/default.xml")//bookmarks
    let $user := collection($prefs-path)/prefs[@for eq $current-user]/bookmarks
    let $prefs := ($user,$default)[1] (: Return default bookmarks if user hasn't saved any :)
(:    return (<bookmarks for="{$current-user}" tenant="{$prefs:selected-tenant}">{$prefs/group}</bookmarks>):)
    return string($prefs)
};


declare function prefs:bookmarks-for-user() {
    let $prefs-path := $prefs:tenant-path || "/config/users" (: e.g. /db/pekoe/cm/config/users :)
    let $default := doc($prefs-path || "/default.xml")//bookmarks
    let $current-user := xmldb:get-current-user()
    let $user := collection($prefs-path)/prefs[@for eq $current-user]/bookmarks
    
    let $prefs := ($user,$default)[1]
    let $debug := util:log("warn", concat("PREFS FOR USER: def",$default))
    return (<bookmarks for="{$current-user}" tenant="{$prefs:selected-tenant}">{$prefs/group}</bookmarks>)
};

declare function prefs:new-prefs($prefs-collection, $user, $element-name, $prefs) {
    let $default-prefs-file := $prefs-collection || "/default.xml"
    let $default-prefs := doc($default-prefs-file)/prefs
    let $user-prefs-name := $user || ".xml"                                 (: TODO - Check and fix user name :)
    let $user-prefs-file := xmldb:store($prefs-collection, $user-prefs-name, $default-prefs)
    let $user-prefs := doc($user-prefs-file)
    (: How do I parameterise the update element? :)
    let $update := update value $user-prefs/prefs/bookmarks with util:base64-decode($prefs)
    let $update := update value $user-prefs/prefs/@for with $user
    return $user-prefs-file
};



declare 
%rest:POST("{$body}")
%rest:path("/pekoe/user/bookmarks")
%rest:consumes("application/json")
%output:media-type("application/json")
(:%output:method("json"):)
function prefs:store-bookmarks-json($body) {
    let $prefs-collection := $prefs:tenant-path || "/config/users"
    let $user := xmldb:get-current-user()
    let $user-prefs := collection($prefs-collection)/prefs[@for eq $user]
    return 
        if (exists($user-prefs)) then (
           update value $user-prefs/bookmarks with util:base64-decode($body),
           (<rest:response>
            <http:response status="{$pekoe-http:HTTP-204-NOCONTENT}"/>
            </rest:response>,<result>Saved bookmarks</result>)
        )
        else 
        (
        let $new-prefs := prefs:new-prefs($prefs-collection,$user, "bookmarks",$body)
        (:let $default-prefs-file := $prefs-collection || "/default.xml"
        let $default-prefs := doc($default-prefs-file)/prefs
        let $user-prefs-name := $user || ".xml"                                 (\: TODO - Check and fix user name :\)
        let $user-prefs-file := xmldb:store($prefs-collection, $user-prefs-name, $default-prefs)
        let $user-prefs := doc($user-prefs-file)
        let $update := update value $user-prefs/prefs/bookmarks with util:base64-decode($body)
        let $update := update value $user-prefs/prefs/@for with $user:)
        return (<rest:response>
            <http:response status="{$pekoe-http:HTTP-204-NOCONTENT}"/>
            </rest:response>,<result>Saved bookmarks</result>)
        )
    
        
};

