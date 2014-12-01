(:
    Top-level query manages access to files. 
:)
xquery version "3.0"; 

(: 
    I need to sit down with pencil and paper and work out these permissions.
    Then, they should be stored in a file, and the queries that use these permissions should refer to the file.
    Just like Apple's Disk Utility "Repair Permissions", the settings for folders and special files should be
    kept in one place. 
    
    I want this to be easily transferred from my installation to the Live ones. 
    That's why the defaults should be stored elsewhere. 
:)


declare variable $local:default-user := "pekoe-staff"; (: will want to use the collection-owner instead :)
declare variable $local:default-group := "pekoe-staff";
declare variable $local:default-pass := "staffer";
declare variable $local:open-for-editing        := permissions:string-to-permissions("rwur-----");
declare variable $local:closed-and-available    := permissions:string-to-permissions("r--r-----"); 
declare variable $local:collection-permissions  := permissions:string-to-permissions("rwurwu---");
declare variable $local:basepath := ""; (: must end with slash :)
declare variable $local:method := request:get-method();
declare variable $local:action := request:get-parameter("action","");
declare variable $local:path := request:get-parameter("realpath","");

(: What is the desired behaviour?
    Want to lock a file and return it.
    If we can't lock the file, what do we return? 
    Nothing?
    A message?
    An error?
    
    Should either return a 403 "Forbidden" or 409 "Conflict"
    both can contain an explanation document (body)
    
:)

declare function local:split-into-coll-and-fn($href) as item()* {
(util:collection-name($href), util:document-name($href))
   (: let $parts := tokenize($href,'/')
    let $fn := $parts[last()]
    let $coll := $parts[position() ne last()]
    return (string-join($coll,'/'),$fn):)
};

declare function local:unlock-file($href) {
    let $doc := doc($href)
    return util:exclusive-lock($doc, local:really-unlock-file($href))
};

declare function local:lock-file() {
    let $href := $local:path
    let $pathParts := local:split-into-coll-and-fn($href)
    return if ($href eq "") then <result status="fail">no file</result>
    else 
        let $doc := doc($href)
        let $local:action :=  util:exclusive-lock($doc, local:really-lock-file($href))
        return if (local:confirm-my-lock($href)) 
            then $doc   (: Try returning the document itself! :)
            else (
                response:set-status-code(404),
                response:set-header("Content-type","application/xml"),
                <result status="fail" >Couldn&apos;t lock the file for user {xmldb:get-current-user()}
                    as current owner is 
                    {   xmldb:get-owner($pathParts[1],$pathParts[2])
                    } 
            </result>) 
};

declare function local:confirm-my-lock($href) { (: Am I now the owner of the file? :)
    let $pathParts := local:split-into-coll-and-fn($href)
    return xmldb:get-current-user() eq xmldb:get-owner($pathParts[1],$pathParts[2])
};

(: NOTE: This MUST be performed within an exclusive-lock.  :)
declare function local:really-lock-file($href) {
    (: if we have (group) read/write permission :)
    
    (: the file must be owned by the collection-group user (ie the user who has the same name as the group which owns the collection.) :)
    let $pathParts := local:split-into-coll-and-fn($href)
    let $group-owner := xmldb:get-group($pathParts[1]) 
    let $valid-user := $group-owner eq xmldb:get-owner($pathParts[1],$pathParts[2]) 
    
    (: document-has-lock returns name of owner - if locked:)
    let $locked := xmldb:document-has-lock($pathParts[1],$pathParts[2]) 
    (: then use the super-user to change the owner to current-user:)
    (:
    xmldb:set-resource-permissions(
        $a as xs:string, 
        $b as xs:string, 
        $c as xs:string, 
        $d as xs:string, 
        $e as xs:integer) empty() !!!!!!!!!!!!!!!!!  NO RESULT - just an error
        
    (So this means that we must test everything before attempting to set permissions.)
        
    Sets the permissions of the specified resource. 
        $a is the collection, which can be specified as a simple collection path or an XMLDB URI. 
        $b denotes the resource tochange. 
        $c specifies the user which will become the owner of the resource, 
        $d the group. 
        $e contains the permissions, specified as an xs:integer value. 
    PLEASE REMEMBER that 0755 is 7*64+5*8+5, NOT decimal 755. 
    
    system:as-user($a as xs:string, $b as xs:string?, $c as item()*) item()*
A pseudo-function to execute a limited block of code as a different user. 
    The first argument is the name of the user, the second is the password. 
    If the user can be authenticated, 
    the function will execute the code block given in the third argument 
    with the permissions of that user and returns the result of the execution. 
    Before the function completes, it switches the current user back to the old user. 
    
    :)
    let $current-user := xmldb:get-current-user()
    let $current-permissions := xmldb:get-permissions($pathParts[1], $pathParts[2])
    let $group := xmldb:get-group($pathParts[1])
    return if ($valid-user and not($locked) and ($current-permissions eq $local:closed-and-available)) 
        then system:as-user("admin", "4LafR1W2", 
            xmldb:set-resource-permissions(
                $pathParts[1],
                $pathParts[2],
                $current-user, 
                $group, 
                $local:open-for-editing) )
        else util:log("warn", concat("Not able to capture the file for user valid?", $valid-user, " locked? ", $locked, "."))            

};

declare function local:check-user-permissions($subdir) {
(: Can the current user create a new dir in here?:)
true()
};

(:/db/pekoe/files/test/testing   FN  /db/pekoe/files/2009/2/Tx-00037.xml  
:)
declare function local:get-good-transaction-directory($fullpath) { 
(: If the directory at $fullpath exists, return it. :)
    if (xmldb:collection-exists($fullpath)) then $fullpath
    else 
    let $newcoll :=  local:create-collection($local:basepath,substring-after($fullpath,$local:basepath))
    return $newcoll
    (: create a collection within /db/pekoe/files/ :)
};

(: basepath must already exist (basepath: /db/pekoe/files/ subpath: test/testing )  :)
(: basepath is /db/pekoe/files/ subpath is 2009/2
:)
declare function local:create-collection($basepath as xs:string, $subpath as xs:string) as xs:string {
if ( $subpath = ("","/" ) ) 
then $basepath (: We're already there. No need to create :)
else 
    let $subdirname := tokenize($subpath,'/')[1] (: e.g. 2009/2 -> 2009 :)
    let $subdir := concat($basepath, $subdirname,"/") (: e.g. /db/pekoe/files/2009/ :)

    let $newcoll :=
        if (xmldb:collection-exists($subdir))  (: then continue down the path to the next subdir:)
        then () (: no need to make it :)
        else 
         let $newcoll := xmldb:create-collection($basepath,$subdirname) (: Returns the path to the new collection as a string - or the empty sequence :)
         let $group := xmldb:get-group($basepath)
         let $set-rules := xmldb:set-collection-permissions(
                    $subdir,
                    $group, 
                    $group, 
                    $local:collection-permissions)
                
        return ()   
    return local:create-collection($subdir, string-join(tokenize($subpath,'/')[position() gt 1],'/'))    
};

declare function local:check-name() {
    let $fn := concat($local:basepath,request:get-parameter("fn", ()))
    return
        if (exists(doc($fn))) 
            then 
                let $pathParts := local:split-into-coll-and-fn($fn)
                let $current-user := xmldb:get-current-user()
                let $valid-user := $current-user eq xmldb:get-owner($pathParts[1],$pathParts[2]) 
                let $current-permissions := xmldb:get-permissions($pathParts[1], $pathParts[2])
                let $available := if ($valid-user  and $current-permissions eq $local:open-for-editing) 
                    then "okay" else "fail"
                return <result status="{$available}">{$fn}</result>
            else 
                <result status="okay" />
   
(:  If file doesn't exist then check the directory to see if we can write it. Return yes or no (??)
    If file does exist then check to see if we have it open and locked (for update). Return yes or no.
    :)
};

(: NOTE: This MUST be performed within a lock:)
declare function local:really-unlock-file($href) {
    (: if we have (group) read/write permission :)
    
    (: and the file is owned by the current user :)
    let $pathParts := local:split-into-coll-and-fn($href)
    let $current-user := xmldb:get-current-user()
    let $valid-user := $current-user eq xmldb:get-owner($pathParts[1],$pathParts[2]) 
    let $group := xmldb:get-group($pathParts[1])
(:  I think there's something wrong with this...   :)
    let $group-as-user := if (xmldb:exists-user($group)) then $group else $local:default-user
    let $current-permissions := xmldb:get-permissions($pathParts[1], $pathParts[2])
    let $is-open-for-editing := $current-permissions eq $local:open-for-editing
   (: then use the super-user to change the owner to current-user:)

   
    return if ($valid-user) (: and $is-open-for-editing)  -- this caused problems with files that didn't close correctly initially.:) 
        then system:as-user("admin", "4LafR1W2", 
            xmldb:set-resource-permissions(
                $pathParts[1],
                $pathParts[2],
                $group-as-user, 
                $group, 
                $local:closed-and-available) )
        else false()            
};

(: Some basic parameter checking might be a good idea!! file path, for starters :)

declare function local:store-post() {
(: Client sends path (eg. /db/pekoe/config/template-meta/CM/Residential-Cover.xml) and action if any :)
(:    let $data := request:get-parameter("data",()):)
    let $data := request:get-data()
    return 
        local:store($data, $local:path)
};

(: this should be okay - only the owner can modify :)


declare function local:store($data, $fullpath) {

    let $pathParts := local:split-into-coll-and-fn($fullpath) (: (/db/pekoe/files/test/testing, test1.xml) :)
(:  There's no dummy checking here - no security!!! ******************************************  :)
    let $goodCollection := local:get-good-transaction-directory($pathParts[1]) (: it's the full path to the dir : /db/... :)
    let $result := if (count(($data,$pathParts)) ge 2) 
        then xmldb:store($goodCollection,$pathParts[2], $data)
        else false()
    let $update-permissions :=   xmldb:set-resource-permissions( 
                $goodCollection,$pathParts[2],
                xmldb:get-current-user(), 
                $local:default-group, 
                $local:open-for-editing) 
    return if ($result) then
             <result status="okay" >{$result}</result>
             else <result status='fail' />
    }; 
    
    
declare function local:release-transaction() {
    let $file := request:get-parameter('path',"")
    return if (not($file eq "")) 
    then 
         let $done := local:unlock-file($file)
         return <result status="okay" />
    else <result status='fail'>No file</result>
};


declare function local:lookup() { (: JESUS - What the hell am I doing here ************************************ :)
    let $query := request:get-parameter('query',"")
    let $src := request:get-parameter('src',"")
 
    (: This is a potentially unsafe action. !!!!!!!!!!!! It would be good to filter it first!:)
    return util:eval-inline(xs:anyURI($src),$query)
};

(: List all the files associated with the selected transaction.
    This might be better in print-merge or some other module as it doesn't relate to files. :)
    
(:declare function local:list-associated-files() as element() 
{

    let $currentTx := request:get-parameter("transaction","") (\: Don't need the basepath here :\)
    (\: this ... is supposed to be customizable for each user (so - not config-default ) :\)
    let $userDirectory := doc('/db/pekoe/config/config-default.xml')/config/transaction-dir[@user='client']
    
    return 
    	<files txp="{$userDirectory}" txf="{$currentTx}">{
    
    	(\: get the files directory from pekoe/config :\)
    	let $goodDirectory := filestore:is-directory(doc('/db/pekoe/config/config-default.xml')/config/transaction-dir[@user='server']) 
    
    	let $transactionFiles := filestore:list-directory(concat($goodDirectory,'/',$currentTx)) 
    	let $transactionFolder := $transactionFiles[1]
    	let $files := remove($transactionFiles, 1)
        (\:	I'm filtering out the versioned copies in Javascript :\)
    	for $f in $files
        	let $mod-date := substring-after($f," mod:")
        	let $name := substring-before($f, " mod:")
        	return <file path="{concat($userDirectory,'/',$currentTx,'/',$name)}" 
        	        display-name="{$name}" mod-date="{$mod-date}" />
    	}</files>

};:)

declare function local:count-items() {
    system:as-user("admin","4LafR1W2",count(collection($local:path)))
    
};

declare function local:delete-file($collection, $resource)  {
    let $doc := doc($local:path)
    let $lock := util:exclusive-lock($doc, local:really-lock-file($local:path))
    return (xmldb:remove($collection,$resource),concat("file: ",$local:path))
};



declare function local:delete() {
    let $resource := util:document-name($local:path)
    let $collection := util:collection-name($local:path)
    return 
        if (empty($resource))  (: must be a collection. BE VERY CAREFUL. $collection is the PARENT!!! I inadvertently removed ALL /db/pekoe/files !!! :)
        then (xmldb:remove($local:path),concat("collection: ",$local:path))
        else local:delete-file($collection, $resource)
};

declare function local:try-something() {
request:set-attribute("id",1871),request:set-attribute("action","capture"), trace(util:eval(xs:anyURI("/db/pekoe/files/Frog-list.xql")),"********* TRACE **************")

};

(: -----------------------------------  MAIN TRANSACTION QUERY --------------------- :)
let $credentials :=  security:checkUser('/db/pekoe/files')
let $r := response:set-header("Content-type","application/xml")
return 
    if (empty($credentials))
    then security:login-request()
    else 
        if ($local:method eq "GET") then 
		    if ($local:action eq 'test') then
    	        local:try-something()    	        
            else if ($local:action eq 'capture') then	    
                local:lock-file()
            else if ($local:action eq 'release') then
                local:release-transaction()
            else if ($local:action eq 'checkname') then
                local:check-name()
            else if ($local:action eq 'lookup') then
                local:lookup()
		   (: else if ($local:action eq 'files') then
		        local:list-associated-files():) (:'list-files' is not a transaction-list. It examines the transaction's folder.:)
            else if ($local:action eq 'delete') then 
                local:delete()
            else if ($local:action eq 'count') then 
                local:count-items()

	        else (response:set-status-code(400),<result>GET Action { if ($local:action eq "") then "missing" else concat("unknown: ", $local:action) }</result>)
        else if ($local:method eq "POST") 
        then local:store-post()
        else (response:set-status-code(405),<result>Method not recognised: {$local:method}</result>)

(: It's now supposed to look like this:
if ($local:method eq "GET")
    then 
        if ($local:action eq "list")
        then local:do-list()
        else if ($local:action eq "list-item")
        then local:do-one-item(request:get-parameter("id",""))
        else if ($local:action eq "capture") 
        then local:do-capture()
        else if ($local:action eq "release")
        then local:do-release()
        else <result>Action is { if ($local:action eq "") then "missing" else concat("unknown: ", $local:action) }</result>
    else if ($local:method eq "POST") 
    then local:do-save()
    else if ($local:method eq "PUT")
    then local:do-new()
    else if ($local:method eq "DELETE")
    then local:do-delete()
    else <result>Method not recognised: {$local:action}</result>
    :)
