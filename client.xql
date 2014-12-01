xquery version "3.0";
module namespace client = "http://pekoe.io/client";
(:
    Use the multi-tenant model. The subdomain is the key and their could be a surrogate
    
    <tenant name="cm">** UUID **</tenant>
    
    The tenant will have groups
    <<uuid>>_admin
    <<uuid>>_staff
    <<uuid>>_subset1_staff
    <<uuid>>_subset2_staff
    
    an UUID is recommended so that the Client can change their domain key without breaking things.
    The disadvantage of this as that the built-in tools for permission management are hard to use because 
    you have to look up the uuid prior to setting the group
    
    
    /db/clients/<<uuid1>>
    /db/clients/<<uuid2>>
    /db/pekoe is for commmon stuff - configuration
    /db/apps/pekoe is for the app.
    
    OR 
    /db/pekoe/clients/<<uuid1>>
    /db/pekoe/clients/<<uuid2>>
    /db/pekoe/config is for commmon configuration and resources
    /db/apps/pekoe is for the app.
    
    Advantage of second approach is that it plays nicely with other eXist-db apps.
    
    util:uuid
    41ba5d62-a5ee-4938-9e75-22882d04bcc0
:)

declare function client:key-from-user() {
    sm:get-user-primary-group(xmldb:get-current-user())
};

declare function client:path() {
    sm:list-groups()
};