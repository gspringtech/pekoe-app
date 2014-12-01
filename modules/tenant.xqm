xquery version "3.0";

module namespace tenant = "http://pekoe.io/tenant";

(: The Tenant info should probably be in the session !!! :)

declare variable $tenant:tenant := replace(request:get-cookie-value("tenant"),"%22","");
declare variable $tenant:tenant-path := "/db/pekoe/tenants/" || $tenant:tenant;