xquery version "3.0";
(: REMEMBER TO SET PERMISSIONS ON THIS FILE 
 
 THIS IS NOT PEKOE LIST. This is the data source for /files
 PEKOE LIST is an Angular Application.
 
:)
module namespace browse = "http://pekoe.io/browse";
import module namespace pekoe-http = "http://pekoe.io/http" at "modules/http.xqm";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace json="http://www.json.org";
(: If you get here and there's no subdomain that's an error:)
declare variable $browse:selected-tenant := req:header("tenant");
declare variable $browse:tenant-path := "/db/pekoe/tenants/" || $browse:selected-tenant ;



declare  
%rest:GET
%rest:path("/pekoe/browse")
%rest:query-param("collection","{$colpath}", "/files")
%rest:produces("application/json")
%output:media-type("application/json")
%output:method("json")
function browse:browse($colpath) {
<list>
<headings><field sort="true" name="name"/><field name="size"/></headings>
<row><name>Time</name><size>{current-dateTime()}</size></row>
<row><name>collection</name><size>{$browse:tenant-path}{$colpath}</size></row>
<row><name>barry</name><size>6</size></row>
<row><name>Sharry</name><size>8</size></row>
<row><name>Clarry</name><size>61</size></row>
<row><name>Harry</name><size>2</size></row>
<row><name>Raspberry</name><size>26</size></row>
<row><name>Cheese</name><size>43</size></row>
<row><name>Pie</name><size>1</size></row>
</list>
};

