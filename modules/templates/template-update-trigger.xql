xquery version "1.0";

declare namespace xmldb="http://exist-db.org/xquery/xmldb";

declare variable $local:triggerEvent external;
declare variable $local:eventType external;
declare variable $local:collectionName external;
declare variable $local:documentName external;

util:log('debug', concat('TEMPLATE-UPDATE-TRIGGER.xql received ', $local:eventType, ' trigger for ',$local:documentName, ' at ', current-dateTime()))
(:util:log('debug', concat('TEMPLATE-UPDATE-TRIGGER.xql received something at ', current-dateTime())):)