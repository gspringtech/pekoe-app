xquery version "3.0";
module namespace prefs="http://gspring.com.au/pekoe/user-prefs"; 

import module namespace tenant = "http://pekoe.io/tenant" at "tenant.xqm";

declare variable $prefs:user := xmldb:get-current-user();
declare variable $prefs:config-collection-name := $tenant:tenant-path || "/config/users";

declare variable $prefs:default-prefs := collection($prefs:config-collection-name)/config[@for eq 'default'];

declare variable $prefs:user-prefs := collection( $prefs:config-collection-name )/config[@for eq $prefs:user];

declare function prefs:good-name($u) {
    replace($u, "[\W]+","_")
};


(: use get-doc-content instead of directly accessing the config file because it will make a new file if none exists. :)
declare function prefs:get-doc-content($docname) {
    let $fullpath := concat($prefs:config-collection-name,"/",$docname)
    
    let $doc := doc($fullpath)/config
    let $content := 
        if (exists($doc)) then $doc
        else xmldb:store($prefs:config-collection-name, $docname, <config for='{$prefs:user}'/>)
    return doc($fullpath)/config
};

declare function prefs:set-pref($for, $pref-item) {
    let $good-pref := if (($pref-item instance of element()) and name($pref-item) eq "pref") then $pref-item else 
        <pref for='{$for}'>{$pref-item}</pref>
        
    let $docname := concat(prefs:good-name($prefs:user), ".xml")
    let $conf := prefs:get-doc-content($docname)
    
    let $update-or-replace := if (exists($conf/pref[@for eq $for])) 
        then (util:log("debug" ,"^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ UPDATING PREF ^^^^^^^^^^^^^^^^^^"), update replace $conf/pref[@for eq $for] with $good-pref)
        else (util:log("debug" ,"^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ REPLACING PREF ^^^^^^^^^^^^^^^^^^"),update insert $good-pref into $conf)
    return ()
};

declare function prefs:get-pref($for) {
    let $pref := $prefs:user-prefs/pref[@for eq $for]
    return 
        if (exists($pref)) then $pref
        else $prefs:default-prefs/pref[@for eq $for]
};

