xquery version "3.0";

module namespace resource-permissions = "http://pekoe.io/resource-permissions";

declare function resource-permissions:permissions($href) {
    let $uri := xs:anyURI($href)
    let $permissions := sm:get-permissions($uri)
    
    let $parent := util:collection-name($href)
    let $collection-permissions := sm:get-permissions(xs:anyURI($parent))
    

    let $current-user := sm:id()//sm:real/sm:username/text()
    let $permissions := map { 
        "collection" := util:collection-name($href),
        "docname" := util:document-name($href),
        "owner" := string($permissions/@owner),
        "group" := string($permissions/@group),
        "parent-group" := string($collection-permissions/@group),
        "mode" := string($permissions//@mode),
        "user" := $current-user
    }
    return $permissions      
};