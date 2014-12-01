xquery version "1.0";


module namespace merge="http://www.gspring.com.au/pekoe/merge";
declare variable $merge:host := "localhost:8080/exist/pekoe";



(:  Generate a module of functions from the schema provided. Store the module in the same collection as the schema. eg school-booking.xqm 
    This should be automatic - run by a trigger. It could also be checked in the query below...
:)
declare function merge:generate-xquery-module-for-schema($schema-file) {
    let $schema-doc := doc($schema-file)
    let $schema-last-mod := xmldb:last-modified(util:collection-name($schema-file), util:document-name($schema-file)) 
    let $xql-name := concat($schema-doc/schema/@for, ".xqm")
    let $xql-last-mod := xmldb:last-modified(util:collection-name($schema-file), $xql-name)
    
    return 
        if (empty($schema-doc)) then <div>A schema for {$schema-file} isn't available</div>
        else if (empty($xql-last-mod) or ($schema-last-mod gt $xql-last-mod))
        then
        let $coll := util:collection-name($schema-doc)
        let $log := util:log("warn", concat("GENERATING SCHEMA MODULE for ",$schema-file, " path: ", request:get-effective-uri()))
        let $transformer := xs:anyURI("generate-xquery-module-from-schema.xsl")
        let $result := transform:transform($schema-doc, $transformer, ())
        let $serialized := util:serialize($result, "method=xml")
        let $stored := xmldb:store($coll, $xql-name, $serialized, "application/xquery")
        return $stored 
        else  <div>Schema module for ${$schema-file} is up to date</div>
};

(: Given a template path, generate an xquery from its Links file :)
declare function merge:make-merge-xql($template) {
    
    let $template-info := merge:template-parts($template)
    let $links := doc($template-info/links/string())
    
    let $schema-for := $links/ph-links/string(@for)
    let $schema := collection("/db/pekoe")/schema[@for eq $schema-for]
    let $schema-path := util:collection-name($schema)
    let $update-schema := merge:generate-xquery-module-for-schema(string(document-uri($schema/root())))
    let $meta-coll := $template-info/links/path
    let $gen-path := concat("http://",$merge:host, "/templates/generate-links-xql.xsl")
    let $links-query := transform:transform($links, xs:anyURI($gen-path),
            <parameters>
                <param name='path-to-schema' value='{$schema-path}' />
                <param name='template-file' value='{$template}' />
            </parameters>)
    let $serialized := util:serialize($links-query, "method=xml")
    let $serialized2 := if (empty($serialized)) then current-dateTime() else $serialized
    let $stored := xmldb:store($meta-coll, $template-info/merge/name/string(), $serialized2, "application/xquery")
    return $stored

};

declare function merge:template-parts($template) as element() {
    let $template-file := util:document-name($template)
    let $name := substring-before($template-file,".")
    let $template-path := util:collection-name($template)
    let $sub-path := substring-after($template-path, "templates")
    
    return 
    <parts>
        <merge><path>/db/pekoe/config/template-meta{$sub-path}</path>/<name>{$name}.xql</name></merge>
        <links><path>/db/pekoe/config/template-meta{$sub-path}</path>/<name>{$name}.xml</name></links>
        <content><path>/db/pekoe/config/template-content{$sub-path}</path>/<name>{$name}</name>.xml</content>  
        <type>{substring-after($template-file, ".")}</type>
    </parts>
};

(:
    TO MERGE a Job with a Template <name>:
    need the template content (for Word or ODT this is xml) from    config/template-content/path/name.xml       (extracted when the file is uploaded)
    need the template LINKS file from                               config/template-meta/path/name.xml          (created when? Edited by admin user - manual process)
    need the glue query (the "merge-xql") from                      config/template-meta/path/name.xql          (generated automatically if it doesn't exist or is outdated)
    
    The merge request is actually a command stored in config/site-commands.xml:
        var path = o.template + "?action=download&amp;job=" + o.file.getPath();
        window.location.href= "merge" + path;
        
    The LINKS file is a tuple of (placeholder-name, field-path, output-name?)
    
    This query simply ensures that the merge-xql is available and up-to-date. The fun
:)

(: Called by controller.xql when processing a /merge path.
/merge/path/to/template?job=/path/to/job
$template-query = merge:get-links-query(/path/to/template)
<forward url=/rest{$template-query} > this is where the merge happens

This function makes sure there's an up-to-date merge-xql file available and returns its path.
The merge file will perform the actual merge.
:)

declare function merge:get-links-query($template) { (: e.g. given /db/pekoe/templates/Education/Tax-Invoice.docx, return  :)

    let $template-info := merge:template-parts($template)
    
    (: if the Template ph-links file has been modified since the merge-xql was generated, then merge-xql should be refreshed. :)
    let $ph-links-last-mod := xmldb:last-modified($template-info/links/path, $template-info/links/name) 
    let $xql-last-mod := xmldb:last-modified($template-info/merge/path, $template-info/merge/name)
    
    return 
        if (empty($xql-last-mod) or ($ph-links-last-mod gt $xql-last-mod))  
        then merge:make-merge-xql($template)
        else concat($template-info/merge/string())
};



