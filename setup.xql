xquery version "3.0";

import module namespace dbutil = "http://exist-db.org/xquery/dbutil" at '/db/apps/shared-resources/content/dbutils.xql';

declare function local:fix-collection-and-resource-permissions($col,$groupUser) {
(:  dbutil:scan doesn't process binaries  :)
    dbutil:scan(xs:anyURI($col),
        function ($collection, $resource) { 
            if ($resource ne '') then 
                (sm:chown($resource, $groupUser),sm:chgrp($resource, $groupUser),sm:chmod($resource,'r--r-----'))
            else 
                (sm:chown($collection, $groupUser),sm:chgrp($collection,$groupUser))
        }),
    dbutil:find-by-mimetype(xs:anyURI($collection), "application/xquery", 
        function ($resource) {
            sm:chown($resource, $groupUser), sm:chgrp($resource, $groupUser), sm:chmod($resource,'r--r-----')
        }
    )
};

declare function local:common-schemas() {
  let $path := xs:anyURI('/db/pekoe/schemas')
  let $owner := sm:chown($path,"admin")
  let $group := sm:chgrp($path,"pekoe-staff")
  let $mode := sm:chmod($path, 'rwxr-x---')
  return sm:get-permissions($path)
};


(:tenant:create('bkfa','Birthing Kit Foundation Australia'):)
(:sm:get-permissions(xs:anyURI('/db')):)
(:sm:chmod(xs:anyURI('/db'),'rwxrwxr-x'):)

(:sm:chmod(xs:anyURI('/db/pekoe/schemas'),'rwxr-x---'),:)

(:sm:chmod(xs:anyURI('/db/apps/pekoe/tenant-template/templates'),'rwxrwx---'):)
(: sm:set-account-enabled('tdbg_staff',true()):)
(:util:int-to-octal(sm:get-umask('tdbg_staff')):)
(:sm:set-umask('tdbg_staff',util:base-to-integer('006', 8)):)
(: system:as-user('tdbg_staff','staffer',xmldb:create-collection('/db/pekoe/tenants/tdbg/files','froglet')):)
 
 local:common-schemas()