xquery version "3.0";
declare namespace rxq = "http://exquery.org/ns/restxq/exist";
(:rest:resource-functions():)
(:rxq:find-resource-functions(xs:anyURI("/db/apps/peeco")),:)
rest:resource-functions()/rest:resource-function[contains(@xquery-uri ,"pekoe")]
