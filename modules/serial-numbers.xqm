xquery version "3.0";

module namespace sn = "http://gspring.com.au/pekoe/serial-numbers";

import module namespace tenant = "http://pekoe.io/tenant" at "tenant.xqm";

declare variable $sn:collection := $tenant:tenant-path || "/config/serial-numbers";
declare variable $sn:open-for-editing        := 480; (:permissions:string-to-permissions("rwur-----");:)
declare variable $sn:closed-and-available    := 288; (:permissions:string-to-permissions("r--r-----");:) 
declare variable $sn:collection-permissions  := 504; (:permissions:string-to-permissions("rwurwu---");:)

declare function sn:pad-number($padding, $n) as xs:string {
    let $wanted-length := string-length($padding)
    let $n-string := string($n)
    let $over-stuffed := concat($padding,$n-string)
    return 
    if (string-length($n-string) ge $wanted-length) then $n-string
    else 
        let $excess := string-length($over-stuffed) - $wanted-length
        return substring($over-stuffed, $excess + 1)
};


declare function local:check-file($for) {
    let $f := collection($sn:collection)/serial-numbers[@for eq $for]
    return 
        if (empty($f)) 
        then 
            let $new := <serial-numbers for='{$for}'><next>1</next></serial-numbers>
            let $good-name := concat(replace($for, "[\W]","_"),".xml")
            let $file := xmldb:store($sn:collection, $good-name, $new)
            return collection($sn:collection)/serial-numbers[@for eq $for]
        else $f
};

(:
    TODO: create a function sn:get-next-padded("0000",$for)
    and a corresponding sn:release-padded($id, $for)
:)


declare function sn:get-next($for) { 
      xs:integer( util:exclusive-lock(local:check-file($for), local:safe-get-next($for))) 
};

declare function local:safe-get-next($for) {
    
    let $serial-numbers := local:check-file($for)
(:    let $snd := if ($serial-numbers) then $serial-numbers else xmldb:store($sn:collection, concat( :)
    let $next := 
        if ($serial-numbers/recycled) 
        then 
            let $this := $serial-numbers/recycled[1]/string()
            let $update := update delete $serial-numbers/recycled[1]
            return $this
        else
            let $this := $serial-numbers/next/string()
            let $update := update value $serial-numbers/next with xs:integer($this) + 1
            return $this
    return if (empty($next)) then <result status='error'>No numbers found</result> else $next
};

declare function sn:return($for, $sn) {
    util:exclusive-lock(collection($sn:collection)/serial-numbers[@for eq $for], local:safe-return($for,$sn))
};


declare function local:safe-return($for,$sn) {
    let $serial-numbers := collection($sn:collection)/serial-numbers[@for eq $for]
    let $update := update insert <recycled>{$sn}</recycled> into $serial-numbers
    return <result status='okay'>recycled</result>
};

(: file-release -------------------------------------------------- :)
declare function sn:unlock-file($href) {
    let $doc := doc($href)
    return util:exclusive-lock($doc, sn:really-unlock-file($href, $doc))
};


declare function sn:release-transaction($file) {
    if (not($file eq "")) 
    then 
        let $release-notes := util:log("info",concat("^^^^^^^^^^^^^^^^^^^^ SN RELEASING ", $file," ^^^^^^^^^^^^^^^^^"))
         let $done := sn:unlock-file($file)
         let $log := util:log("debug",concat(">>>>>>>>>>>>>>>>>>>>>> release says ",$done,"<<<<<<<<<<<<<<<<<<<<<<"))
         return <result status="okay" />
    else <result status='fail'>No file</result>
};

(: NOTE: This MUST be performed within a lock:)
declare function sn:really-unlock-file($href,$doc) {
    (: if we have (group) read/write permission :)
    (: and the file is owned by the current user :)
    let $pathParts := (util:collection-name($doc), util:document-name($doc))
    let $current-user := xmldb:get-current-user()
    let $valid-user := $current-user eq xmldb:get-owner($pathParts[1],$pathParts[2]) 
    let $group := xmldb:get-group($pathParts[1])
    
(:    let $locked := xmldb:document-has-lock($pathParts[1],$pathParts[2])  Not tested. Why? :)
    (: then use the super-user to change the owner to current-user:)

    let $current-permissions := xmldb:get-permissions($pathParts[1], $pathParts[2])
    let $log := util:log("debug",concat("REALLY UNLOCK: IS valid user?: ",$valid-user,", and group is ",$group)) 

    return if ($valid-user) (: and $current-permissions eq $sn:open-for-editing)  -- this doesn't seem useful. :) 
        then system:as-user("admin", "4LafR1W2", 
            xmldb:set-resource-permissions(
                $pathParts[1],
                $pathParts[2],
                $group, 
                $group, 
                $sn:closed-and-available) )
        else false()            
};