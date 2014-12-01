xquery version "3.0";
module namespace pekoe-http = "http://pekoe.io/http";

declare variable $pekoe-http:HTTP-200-OK := 200;
declare variable $pekoe-http:HTTP-201-CREATED := 201; 
declare variable $pekoe-http:HTTP-300-MULTIPLECHOICES := 300; (: Might want to use this when no tenant selected and multiple exist. :)
declare variable $pekoe-http:HTTP-302-FOUND := 302; (: Typically used as a redirect :)
declare variable $pekoe-http:HTTP-303-SEEOTHER := 303; (: Provide new Location header:)
declare variable $pekoe-http:HTTP-400-BADREQUEST := 400; (: Bad Request :)
declare variable $pekoe-http:HTTP-401-UNAUTHORIZED := 401; (: Not logged in or - here - not in the right Group :)
declare variable $pekoe-http:HTTP-403-FORBIDDEN := 403;   (: you may be logged-in but you don't have permission to access this resource :)
declare variable $pekoe-http:HTTP-419-SESSIONEXPIRED := 419;
declare variable $pekoe-http:HTTP-204-NOCONTENT := 204;  (:   :)
declare variable $pekoe-http:HTTP-404-NOTFOUND := 404;  (:  Not found. :)
declare variable $pekoe-http:HTTP-412-PRECONDITIONFAILED := 412;  (:  Not found. :)

(:

can't do this - these are not available when the query is prepared.
declare variable $pekoe-http:tenant := req:header("subdomain");
declare variable $pekoe-http:tenant-path := "/db/pekoe/" || $pekoe-http:tenant ;:)

(: Need to create a "none" or empty or vacant. Maybe this is the place for the default? probably not. It's the missing  tenant:)