xquery version "3.0"; 

import module namespace tmpl     ="http://www.gspring.com.au/pekoe/admin-interface/templates" at "modules/templates.xqm";

declare option exist:serialize "method=xml media-type=application/xml";

declare variable $local:include-defaults := true();

declare variable $local:tenant := replace(request:get-cookie-value("tenant"),"%22","");
declare variable $local:tenant-path := "/db/pekoe/tenants/" || $local:tenant ;
declare variable $local:templates-path := $local:tenant-path || "/templates";



declare function local:add-attribute($element as element(), $name as xs:string, $value as xs:anyAtomicType?) as element() {
    element { node-name($element) }
            { attribute {$name} {$value},
                $element/@*,
                $element/node() }
};

declare function local:list() as element() {
    let $simple-listing := tmpl:get-simple-listing($local:templates-path)
    let $log := util:log("debug", "TEMPLATE SIMPLE LISTING " )
    let $log := util:log("debug",$simple-listing)
    let $result := if (not($simple-listing)) then <ul/> else $simple-listing
    return local:add-attribute($result,"class","hiernav")  
}; 


declare function local:get-template() {
    let $template := request:get-parameter("template", "")
    let $template-meta := concat($template,'/pekoe-meta.xml')
    return doc($template-meta)
};

declare function local:get-site-commands() {
    let $site-commands-path := $local:tenant-path || '/config/site-commands.xml'
    let $doc := doc($site-commands-path)
    return if (exists($doc//commands)) then $doc/commands/* else ()
};

declare function local:get-ph-links($template) {
        <template name='{$template}' >
            <commands>
                {local:get-site-commands()}
            </commands>
            {tmpl:get-phlinks($template)}
        </template>
};

(:declare function local:get-phtree() as element() {
    let $root-element := request:get-parameter("for",())
    let $template := request:get-parameter("template", "")
    return tmpl:get-phlist($template,$local:include-defaults,$root-element)
};:)
(:
declare function local:get-fragment-names(){ 
	(\:<fragmentNames> {   the path doesn't start with a /  :\)
	let $i :=  distinct-values(for $i in doc('/db/pekoe/config/schema.xml')/phtree/ph/@path[matches(., '^[^/]')] return substring-before($i,'/'))
	return trace($i, "fragment names")
	(\:} </fragmentNames>:\)
};

declare function local:get-schema() {
    doc('/db/pekoe/config/schema.xml')
};:)

(: TODO remove deprecated xmldb:authenticate function :)
declare function local:ss() {
	<params>{
	let $auth := request:get-header("Authorization")
	let $credentials := if (starts-with($auth, "Basic")) then
	                        let $creds := util:binary-to-string(substring-after($auth, "Basic ") cast as xs:base64Binary)
	                        return (substring-before($creds, ":"),substring-after( $creds, ":"))
	                  else (request:get-header-names()) 
	let $dummy := xmldb:authenticate("xmldb:exist://$local:templates-path", $credentials[1],$credentials[2])
	return $credentials
	}
	</params>
}; 
(: --------------------------------------------------      MAIN QUERY      ------------------------- :)

let $r := response:set-header("Content-type","application/xml")
return 		
		(: get-parameter(name, default-val) :)
		let $requestFor := request:get-parameter("get", "list")
		(:let $dummy := local:ss():)
		return
		        if ($requestFor eq "list") then  (: called by main.js :)
		            local:list()
		        else if ($requestFor eq "content") then
		            local:get-template()
		        (:else if ($requestFor eq "flash-template-list") then
		            local:f-list()
		        else if ($requestFor eq "revlist") then
		            local:rev-list():)
(:		        else if ($requestFor eq "phtree") then
		            local:get-phtree():)
	            else if ($requestFor eq "phlinks") then 
		            tmpl:get-phlinks(request:get-parameter("template",""))
(:		        else if ($requestFor eq "fragmentNames") then
		            local:get-fragment-names():)
(:		        else if ($requestFor eq "schema") then
		            local:get-schema():)
		        else ()

    (:    The request:  (needs work - not very clever)
    - templates.xql -> simple-listing of top-level templates and collections
    - templates.xql?root=txo -> filter for /txo documents
    - templates.xql?template=template-name -> get the template content
    - templates.xql?template=tname&add=phtree -> get the phtree listing for the template :)