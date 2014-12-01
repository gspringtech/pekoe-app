(:
    Get the appropriate schema
:)
xquery version "3.0"; 
module namespace schema = "http://pekoe.io/schema";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace pekoe-http = "http://pekoe.io/http" at "modules/http.xqm";

(:declare variable $schema:selected-tenant := req:header("tenant");:)
declare variable $schema:tenant := replace(request:get-cookie-value("tenant"),"%22","");
declare variable $schema:tenant-path := "/db/pekoe/tenants/" || $schema:tenant ;
(:
    Not quite so simple.
    Will need to check the default schemas and then add the tenant's schemas


:)

declare
%rest:GET
%rest:path("/pekoe/schema/{$for}")
%rest:produces("application/xml")
%output:media-type("application/xml")
function schema:get-schema($for) {
    let $local-schema := collection($schema:tenant-path)/schema[@for eq $for]
    
    return 
        if (not(empty($local-schema)))
        then  $local-schema
        else 
            let $default-schema := collection('/db/pekoe/schemas')/schema[@for eq $for]
            let $log := util:log("debug", "SCHEMA FOR " || $for || " is " || $default-schema)
            return
                if (not(empty($default-schema))) then $default-schema
                else                
                <rest:response>
                     <http:response status="{$pekoe-http:HTTP-404-NOTFOUND}"/>
                 </rest:response>

};
