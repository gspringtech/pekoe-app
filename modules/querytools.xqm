module namespace pqt="http://gspring.com.au/pekoe/querytools";
import module namespace sn="http://gspring.com.au/pekoe/serial-numbers" at "serial-numbers.xqm";
import module namespace prefs="http://gspring.com.au/pekoe/user-prefs" at "ui-prefs.xqm";


declare variable $pqt:admin-pass := "4LafR1W2"; (: TODO replace with setUid script :)

declare function pqt:ancestry($n as node()) {
    for $p in $n/ancestor-or-self::* return (name($p))
};

declare function pqt:get-request-as-number($param as xs:string, $default as xs:integer) as xs:integer {
    let $requested := request:get-parameter($param, "")
    return if ($requested castable as xs:integer) then xs:integer($requested) else $default 
};


declare function pqt:get-paged-items($items) {
(:  I would like to keep the records-per-page (rp) as a user-pref.
    AND if possible, that should be per-list, not just per-user.
    
    So the first thing I'll need is to store a default. Or provide it. 
    It might be better to provide it on a per-list basis (in the Query) because
    some queries might be "bigger" than others. 
    
    To store the preference, I'll need the List-name and the user name.
    
    let $rp-pref := collection("/db/pekoe/config/users")/config[@for eq xmldb:get-current-user()]/pref[@for eq $list-name]/string()
    
    So the tricky part is that there's the default user pref, the current user-pref and possibly a different value supplied.
    If the get-request value is different to the user-pref, then we should update the user-pref. 
    BUT, first time around, it will always be different. Or missing.
    Okay - first load, there's no value - so we get a default here....
    
    let $rp-pref := ....
    let $rp := get-req-as-num("rp",$rp-pref)
    let $update-user := if ($rp ne $rp-pref) then ... else ()
    
:)

(:  These params will be supplied automatically - they are hard-wired in the Javascript. :)

    let $rp-pref := prefs:get-pref(request:get-effective-uri())
    let $good-default := (if ($rp-pref castable as xs:integer) then xs:integer($rp-pref) else (), 10)[1] (: used the sequence here as a guard for a missing default :)
    let $rp := pqt:get-request-as-number("rp",$good-default)
    let $update-user := 
        if (empty($rp-pref) or (string($rp) ne $rp-pref)) 
        then prefs:set-pref(request:get-effective-uri(), $rp) 
        else ()
 (:   let $log := util:log("debug",concat("1111111111111111111111111  PQTGETPAGEDITEMS got rp",$rp, " and rp-pref",$rp-pref, "1111111111111"))
    :)
    let $cp := pqt:get-request-as-number("p",1) (: current-page obviously defaults to 1 :)
    let $total-pages := ceiling(count($items) div $rp)
    let $start-index := ($cp - 1) * $rp + 1 
    let $end-index := $start-index + $rp - 1
    return  ($start-index, $end-index ,$rp, $cp, $total-pages)
};

(: Assumes that attributes "pekoe-lock" and "pekoe-locked-by" may have been applied to the element. Desired result is (true, false) :)
declare function pqt:item-is-locked($item) { 
    let $old-lock := current-dateTime() - xs:dayTimeDuration("PT1H") (: one hour ago :)
    let $valid-lock-time := ($item/@pekoe-lock castable as xs:dateTime) and (xs:dateTime($item/@pekoe-lock) gt $old-lock) (: lock was set less than an hour ago :)
    let $locked-by-someone-else := $valid-lock-time and ( ($item/@pekoe-locked-by ne "") and ($item/@pekoe-locked-by ne xmldb:get-current-user()))
    return ($valid-lock-time, $locked-by-someone-else )
};

(: return the locking user or empty string. THIS seems the BEST APPROACH :)
declare function pqt:locked-by($item) { 
    let $old-lock := current-dateTime() - xs:dayTimeDuration("PT1H") (: one hour ago :)
    return 
        if (($item/@pekoe-lock castable as xs:dateTime) and (xs:dateTime($item/@pekoe-lock) gt $old-lock)) (: lock was set less than an hour ago :)
        then $item/string(@pekoe-locked-by)
        else ()
};

declare function pqt:item-is-locked-by-someone-else($item) { 
    pqt:item-is-locked($item)
};

declare function pqt:locked-and-mine($item) { 
    let $old-lock := current-dateTime() - xs:dayTimeDuration("PT1H") (: one hour ago :)
    let $valid-lock-time := ($item/@pekoe-lock castable as xs:dateTime) and (xs:dateTime($item/@pekoe-lock) gt $old-lock) (: lock was set less than an hour ago :)
    let $locked-by-someone-else := $valid-lock-time and ( ($item/@pekoe-locked-by ne "") and ($item/@pekoe-locked-by ne xmldb:get-current-user()))
    return ($valid-lock-time, not($locked-by-someone-else) )
};

declare function pqt:unlock-item($job) {
    let $locked-by := pqt:locked-by($job)
    let $me := xmldb:get-current-user()
    return if (pqt:locked-by($job) eq $me) 
        then system:as-user("admin",$pqt:admin-pass,
                 let $update-time := update delete $job/@pekoe-lock
                 let $update-lock-by := update delete $job/@pekoe-locked-by
                 return <result status='okay'>Unlocked {$job/string(id)}</result>
                 )
         else <result status='fail'>Either not locked or owned by someone else</result>       
};

declare function pqt:check-lock-and-load($resources){
    for $resource in $resources
    let $is-locked-by-someone := pqt:locked-by($resource)
   
    let $user := xmldb:get-current-user()
    return 
        if (empty($is-locked-by-someone) or  ($is-locked-by-someone eq $user) ) 
        then     
            system:as-user("admin",$pqt:admin-pass,
                let $update-time := update insert attribute {"pekoe-lock"} {current-dateTime()} into $resource
                let $update-user := update insert attribute {"pekoe-locked-by"}  {$user} into $resource
                return $resource
            )
        else         
            ( response:set-status-code(403),
              <result status='fail'>Locked by {$is-locked-by-someone} </result>
            )
};

declare function pqt:format-as-aust-date($d) {
    if ($d castable as xs:date) then format-date($d,"[D01]-[M01]-[Y0001]")
    else if ($d castable as xs:dateTime) then format-dateTime($d,"[D01]-[M01]-[Y0001]") else ""
};


(: Produce (2012/06, booking-0000273.xml) from ("booking", "0000273") and today's date :)
declare function pqt:year-month-file-path($prefix, $id) {
    let $currentD := current-date()
    return (
        concat(year-from-date($currentD), "/", sn:pad-number("00",month-from-date($currentD))),
        concat($prefix, "-", $id, ".xml"))
};

(: Produce '2012/06/booking-000273' from 'booking', '000273' and today's date :)
declare function pqt:year-month-with-id-as-path($prefix, $id) {
    let $currentD := current-date()
    return 
        concat (
            year-from-date($currentD), '/', 
            sn:pad-number("00",month-from-date($currentD)), '/', 
            concat($prefix, "-", $id))
            
};


declare function pqt:monday() {
    (: Get the date of the closest monday including today
    monday is 2nd day of week :)
    let $day-of-week := 1 + (( current-date() - xs:date("1901-01-06")) div xdt:dayTimeDuration("P1D") mod 7)
    let $days-to-next-monday := (9 - $day-of-week) mod 7
    let $duration := xdt:dayTimeDuration(concat("P",$days-to-next-monday,"D"))
    return adjust-date-to-timezone((current-date() + $duration),())
    
};

declare function pqt:split-three($str) {
    if ($str ne "") then (
        let $last-three := substring($str, string-length($str) - 2)
        let $first := substring($str, 1, string-length($str) -3)
        return (pqt:split-three($first),$last-three)
    ) else ()
};

declare function pqt:currency($any-val) {
if (not($any-val castable as xs:decimal)) then $any-val else 
    
    let $val := if ($any-val castable as xs:decimal) then xs:decimal($any-val) else number("NaN")
    let $is-negative := $val lt 0.0
    let $as-cents := abs($val) * 100.0 (: MUST have the decimal 0 otherwise $val is converted to integer before multiplication :)
    let $cents := $as-cents mod 100
    let $dollars := $as-cents idiv 100
    let $cents-string := if ($cents lt 10) then concat("0",$cents) else string($cents)
    let $int := if (exists($dollars)) then string-join(pqt:split-three(string($dollars)),",") else "0"
         
    return 
        if ($is-negative) 
            then concat("-$",string($int),".",$cents-string) 
            else concat( "$",string($int),".",$cents-string)

};

declare function pqt:long-date($date) {
    if ($date castable as xs:date) 
    then 
        let $day := day-from-date($date)
        let $month := month-from-date($date)
        let $year := year-from-date($date)
        let $month-words := tokenize("January February March April May June July August September October November December"," ")
        return concat($day, " ", $month-words[$month], ", ", $year)
    else
        "Choose a Date below"
};

declare function pqt:string-or-space($n) {
  if (empty($n) or ($n eq "")) then "&#160;" else string($n)
};
