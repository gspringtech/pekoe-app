(: 
    Module: get and set user-configurations.
:)
module namespace config="http://pekoe.io/pekoe/config";

import module namespace pekoe-http = "http://pekoe.io/http" at "http.xqm";
import module namespace security ="http://www.gspring.com.au/pekoe/security"  at "security.xqm";
 
 (: Will need to guard against permissions errors :)
 (: http codes we return :)



declare variable $config:path := "xmldb:exist:///db/pekoe/config/users";
declare variable $config:default := "/db/pekoe/config/app.xml";
declare variable $config:tenants := doc('/db/pekoe/tenants.xml')/tenants;
(: 
    This module works as desired. it has get and set for arbitrary name:value pairs. 
    There is currently no checking of either name or value for safety.
    A new "name:value" will be added to the User's config file.
    An updated "name:value" will replace the previous one. 
    A new "name" will be automatically added to the default config file. 
    An update value will not be added to the default file. Call config:set-default($setting, $value) to 
    update the default.
    
    A requested value will be obtained from the User or, failing that, the default (if the value exists).
:)
  



declare function config:new-set($user, $userDoc, $setting, $value) {
    let $log := util:log("debug", concat("updating config for ",$userDoc))
	let $fullPath := concat($config:path, '/', $userDoc)
	let $step1 :=   if ( not ( doc( $fullPath ) ) ) then 
					      xmldb:store( $config:path, $userDoc, <config owner="{$user}" /> )
	                 else ()
	 
	let $step2 := update delete doc($fullPath)/config/attribute[@name=$setting]
	let $attr := <attribute name="{$setting}" value="{$value}" />
	let $step3 := update insert $attr into doc($fullPath)/config
    return true()     
};

declare function config:set($setting, $value) as xs:boolean {
    let $credentials := security:get-xhr-credentials($config:path)  
    return if (empty ($credentials))
    	then false()
    	else (
    	    let $user := $credentials[1]
    	    let $pass := $credentials[2]
    (:		let $collection := xmldb:collection($config:path , $user, $pass ):)
    		let $userDoc := concat("config-",$user,".xml")
    	    
    	    (: Check to see if this value is the same as has been previously set. If not, then add it. :)
    	    let $setUser := 
    	        if (not(doc($userDoc)/config/attribute[@name=$setting]/@value eq $value)) 
    	        then config:new-set($user, $userDoc, $setting, $value)
    	        else ()
    	                       
    	    (: same applies for the default - but we don't care if the value is different - only whether
    	    the setting exists  :)
    	    let $defaults := $config:default
    	    let $setDefault := 
    	        if (not (doc($defaults)/config/attribute[@name=$setting])) 
    	        then config:new-set($user, "config-default.xml", $setting, $value)
    	        else ()
    	    return true()
    )
};

declare function config:set-default($setting, $value) as xs:boolean {
let $dummy := util:log("debug","user-config:set-default CHECK USER")
    let $credentials := security:checkUser()
    return if (empty($credentials)) then (security:login-request())
    else (
	    (: who has permission to set-defaults? Can the $user's group be checked to see if they're management?) :)

	    let $userDoc := "config-default.xml"

        (: Check to see if this value is the same as has been previously set. If not, then add it. :)
        let $setDefault := 
            if (not(doc($userDoc)/config/attribute[@name=$setting]/@value eq $value))
            then config:new-set($user, $userDoc, $setting, $value)
            else ()
        return true()
    )
};

(: e.g. called by main-app to insert the transaction directory into the page :)
declare function config:get($requiredValue)  {
let $dummy := util:log("debug","user-config:get CHECK USER")
	let $credentials := security:checkUser()
    return if (empty($credentials)) then (security:login-request())
    else (
		let $u := $credentials[1] (:session:get-attribute("user"):)
	
		let $conf := collection($config:path)
		let $results := for $user in ($u, 'default') 
		                return $conf/config[@owner=$user]/attribute[@name=$requiredValue]/data(./@value)
		return ($results[1])
	)
};

declare function config:user-has-prefs() as xs:boolean {
let $credentials := security:checkUser()
 return    exists(doc(concat($config:path,'/config-',$credentials[1],'.xml'))/config)
};


declare function config:set-prefs($user as xs:string, $prefs as item()) {
    let $userConf := doc(concat($config:path,'/config-',$user,'.xml'))/config
    for $p in $prefs/attribute
    return if (exists($userConf/attribute[@name eq $p/@name]))
            then (update replace  $userConf/attribute[@name eq $p/@name] with $p)
            else (update insert $p into $userConf)
};

declare function config:set-lists($user as xs:string, $prefs as item()) {
    if (exists($prefs//lists)) then 
        let $userConf := doc(concat($config:path,'/config-',$user,'.xml'))/config
        return if (exists($userConf/lists))
            then (update replace  $userConf/lists with $prefs//lists)
            else (update insert $prefs//lists into $userConf)
    else ()
};

declare function config:update-prefs($data as item()) {
    let $credentials := security:checkUser()
    return if (empty($credentials)) then (security:login-request())
    else 
        let $user := $credentials[1]
        let $action := config:set-prefs($user,$data)
        let $lists := config:set-lists($user,$data)
        return (<result>updated prefs for {$user}</result>)
}; 

(: gather all preferences - including defaults for the named user :)
declare function config:collectPrefsFor($configForCurrentUser as xs:string)  {
    let $userConf := doc(concat($config:path,'/config-',$configForCurrentUser,'.xml'))/config/attribute
    let $defaultConf := doc($config:default)/config/attribute
    let $combined := distinct-values(($userConf/@name/string(.),$defaultConf/@name/string(.)))
    for $n in $combined
    order by $n
    return
    (
        if (exists($userConf[@name eq $n])) 
        then $userConf[@name eq $n]
        else $defaultConf[@name eq $n]
    )
};

declare function config:current-user-name() as xs:string {
    "Tran Dang"
};

(: Using the "l" is an unattractive hack. Is there a better way? ***************************************** :)

declare function config:collectListsFor2($configForCurrentUser) {
"<l></l>"
};

declare function config:collectListsFor($configForCurrentUser as xs:string) {
    (: Want to combine the default lists with the users:)
util:serialize(<l xmlns="">{
        util:eval(
            util:serialize(                
                 doc(concat($config:path,'/config-',$configForCurrentUser,'.xml'))/config/lists
                ,())
            ) 
       }</l> ,())
};

(: Ah - some Javascript ... :)
declare function config:script() {
(: this appears to be the best security model ... :) 
let $credentials := security:checkUser()
return if (empty($credentials)) then () 
    else
<script type="text/javascript" xmlns="http://www.w3.org/1999/xhtml"> 
if ( gs === undefined ) var gs = {{ }};
if (!gs.Pekoe) gs.Pekoe = {{}};

if (!gs.Pekoe.Config) gs.Pekoe.Config = {{
    
    props : {{prop:"val"
{

    let $attrs := config:collectPrefsFor($credentials[1])
    for $a in $attrs
    return (concat(',"',$a/@name, '": "', $a/@value, '"'))
} }}
}};
// an E4X object:

gs.Pekoe.Config.lists_default = {config:collectListsFor("default") }; 
gs.Pekoe.Config.lists_user = {config:collectListsFor($credentials[1]) }; 

</script>

};

(:
    User settings. 
    Values will be stored in an xml file - per user - plus a default file.
    To keep things simple initially, if the default file DOESN'T contain the value, then
    add it to the default as well as the user. 
    If the user is not available then  ???
    
    The config:get function will query the user's config followed by the default. 
    It will return the first value in the result sequence - this will be either the user's value
    or the default.
    
    Bugger - I think the values will need to be stored in attribute/value pairs. Otherwise
    I'll need to use an 'eval()' to follow the path. 
    
    <config user='default' id='0'>
        <attribute name='filesize' value='21' />
        
        </config>
    This will probably mean some shitty response times.
    
    

:)