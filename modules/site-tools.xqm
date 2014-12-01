module namespace site = "http://gspring.com.au/pekoe/site-tools";
(: 
A module for managing site specific details 
:)
(:
    Custom tools for _this_ site. Initially, this is all about the Merge Results. 
    
    These functions will be called (among other things) by 
    the MERGE - where the final step _could_ be site-specific. 
    
    HOW do I change the behaviour here ?
    Output might be:
    - streamed
    - saved in job-folder
    - saved and streamed
    - emailed somehow.
    
    This behaviour may change in one installation according to:
    - jobtype (doctype)
    - user preference
    - template type
    
    Can I give the user a Choice? How can I present them with that Choice?
    
    In this current instance, the Site will handle both 
    - CA resource bookings
    - EDU school bookings
    ... and the behaviour will be different for each.
   
    So that means at the minimum I must examine the $job doctype.
    
    Choices - two obvious places where this can be created, and one obvious place to present them:
    -   The most obvious place to present these doctype- and template-options would be 
        in the "controls" of the form. 
        The choices will be provided on a per-template basis AND/OR site basis - which means that 
        they should be delivered when the Template ph-links are loaded. 
        
    -   This suggests that the options be delivered via the ph-links file,
        and that the ph-links schema be modified to suit.
    
    -   The next bit of the puzzle is working out how to link Commands to Actions;
        specifically, I want this "site-tools" Module to contain the actions which 
        are sent when the user clicks a button. 
        So the Button Label must be made accessible to the ph-links file - 
        or the ph-links file must be able to interrogate this Module. 
        
        This might be a good time to revisit the ph-links file - consider the Collection document. 
        
        
    
    
:)
(:~ function local:stream-result($template-file as item()*, $job as item()*, $merged-contents) :)
declare function local:stream-result($template-file, $job, $merged-contents) {
    
    let $mime := xmldb:get-mime-type(xs:anyURI($template-file))
    let $new-fn := local:make-file-name($job, $template-file)
    let $header :=  response:set-header('Content-disposition', concat('attachment; filename=',$new-fn))
    let $log := util:log("warn",concat("******************** MIME TYPE IS ", $mime))
    return response:stream-binary($merged-contents,$mime)
    
     
};

declare function local:save-in-job-folder($job, $template, $merged-content) {
    let $job-folder := util:collection-name($job)
    let $template-doc-name := local:make-file-name($job,$template)
    return xmldb:store($job-folder,$template-doc-name,$merged-content)
    
};

declare function local:add-to-email() {()};


(:

<mail>
                <from>Person 1 &lt;sender@domain.com&gt;</from>
                <to>recipient@otherdomain.com</to>
                <cc>cc@otherdomain.com</cc>
                <bcc>bcc@otherdomain.com</bcc>
                <subject>Testing send-email()</subject>
                <message>
                        <text>Test message, Testing 1, 2, 3</text>
                        <xhtml>
                                <html>
                                        <head>
                                                <title>Testing</title>
                                        </head>
                                        <body>
                                                <h1>Testing</h1>
                                                <p>Test Message 1, 2, 3</p>
                                        </body>
                                </html>
                        </xhtml>
                </message>
        </mail>


:)

declare function local:send-structured-email($job, $template, $merged-content) {
(:
    Are text attachments useful here?
    What if THIS template is a Text? Should it be embedded?
    
    At the moment, the plan is to assume THIS template is just another ATTACHMENT. 
    The <email> element can have additional attachments - including some pulled from the Job folder. 
    
    If the Job contains an Email, what will it look like?
    Will there be more than one?
    How can I tell the user that there's a Problem? (This comes back to the Merge error problem)
    
    if one exists, can we create another?
    
    
    
    let $email := $job/email[@sent ne '1']
:)
let $email := ($job/email[@sent ne '1'])[1] (:Guard against multiple emails:)
let $subject := util:eval($email/subject)
let $textmessage := util:eval($email/message)
let $fileName := tokenize($template,"/")[last()]
let $message :=  
<mail>
    <from>denrbgschools@sa.gov.au</from>
    <to>{$job//teacher-email/string(.)}</to>
    <cc>alisterhp@me.com</cc>
    <subject>{$subject}</subject>
    <message>
        <text>Attention:  {$job//teacher/string(.)}. Please find attached confirmation of your booking.</text>
        <xhtml>
            <html>
            <head>
             <title>Botanic Garden Education Booking</title>
            </head>
            <body>
             <h3>Attention:  {$job//teacher/string(.)}</h3>
             <p>Please find attached confirmation of your booking.</p>   
            </body>
            </html>
        </xhtml>
    </message>
    <attachment filename='{$fileName}' >{$merged-content}</attachment>
</mail>
return 
   if ( mail:send-email($message, (),())) then
   (system:as-user("admin", "4LafR1W2", (update value $job//status with "Complete", update value $email/@sent with '1') ),
   <result status='okay'>Sent!</result> 
   )
   else <result status='fail'>Message NOT sent</result>

};
(:
   This is the good one ... (2013-10-15)----------------------------------------------------------------
   NOTE: to DEBUG email:
   First, turn on debugging below...
   Then, tail -f /usr/local/exist/tools/wrapper/logs/wrapper.log
   
   The latest error occurred after moving the server - with a hostname change. 
   501 Syntactically invalid HELO argument(s)
   Solved by adding mail.smtp.localhost below...
:)
declare function local:send-email($job, $template, $merged-content) {
let $props := <properties>
                <property name="mail.debug" value="false" />
                <property name="mail.smtp.localhost" value="bgaedu3" />
                <property name="mail.smtp.ssl.enable" value="true"/>
                <property name="mail.smtp.auth" value="true"/>
                <property name="mail.smtp.port" value="465"/>
                <property name="mail.smtp.host" value="securemail.adam.com.au"/>
                <property name="mail.smtp.user" value="botanic-education@adam.com.au"/>
                <property name="mail.smtp.password"  value="Shanahan"/>
        </properties>
        
let $session := mail:get-mail-session($props)
let $subject := concat("Booking for ", $job//trail_event[1], " at Botanic Garden Education")
let $fileName := tokenize($template,"/")[last()]
let $recipient := $job//teacher-email/string(.)
(: There is a bug in the send-email($session,$message) method which causes the Content-type to be set according to the first content element.
    (This only applies when sending using the $session)
   This can be demonstrated by send a message which contains both text and xhtml - there will be no visible body.
   When the text is removed, the xhtml content will be sent with the correct Content type.
   However any attachment is incorrectly sent with Content-type: quoted-printable.
   
   The fix would appear to be a mod to the send-mail java function.
   This error was reported by Joop Ringleberg
   <attachment filename='{$fileName}' mimetype='APPLICATION/VND.OPENXMLFORMATS-OFFICEDOCUMENT.WORDPROCESSINGML.DOCUMENT' encoding='BASE64'>{$merged-content}</attachment>
   <attachment filename='{$fileName}' mimetype='APPLICATION/VND.OPENXMLFORMATS-OFFICEDOCUMENT.WORDPROCESSINGML.DOCUMENT'>{$merged-content}</attachment>
            
        
   :)
let $message :=  
<mail>
    <from>botanic-education@adam.com.au</from>
    <reply-to>Michael.Yeo2@sa.gov.au</reply-to>
    <to>{$recipient}</to>
    <subject>{$subject}</subject>
    
    <message>
        <text>Attention:  {$job//school/teacher/string(.)}. Please find attached confirmation of your booking.</text>      
        <xhtml type='text/plain' charset='UTF-8' encoding='8BIT'>
            <html>
            <head>
             <title>Botanic Garden Education Booking</title>
            </head>
            <body>
             <h3>Attention:  {$job//school/teacher/string(.)}</h3>
             <p>Please find attached confirmation of your booking.</p>   
             <p>{$job/notes-to-teacher/string(.)}</p>
            </body>
            </html>
        </xhtml>        
    </message>
    <attachment filename='{$fileName}' mimetype='APPLICATION/VND.OPENXMLFORMATS-OFFICEDOCUMENT.WORDPROCESSINGML.DOCUMENT'>{$merged-content}</attachment>
</mail>
(:let $send :=  util:catch("*", mail:send-email(xs:long($session), $message),util:log("debug", concat("************ ERROR *********** ", $util:exception, " - ",$util:exception-message))) :)
let $send :=  mail:send-email(xs:long($session), $message)

return 
    (
        system:as-user("admin", "4LafR1W2", update replace $job//status with <status date-stamp="{current-date()}">Completed</status>),
        <result status='okay'>Sent!</result> 
        )
   

};

declare function local:make-file-name($job, $template-file) {
    (: it doesn't need the job id if we're storing it in the job! :) 
    let $fileName := tokenize($template-file,"/")[position() eq last()]
    let $fn-parts := tokenize($fileName, "\.")
    let $job-id := $job/*/string(id)
    let $fn := concat($fn-parts[1], "-",$job-id, "-",replace(current-dateTime(), "-|T.*$",""),".",$fn-parts[2])
    return $fn
};

(:~  
 @param $job as element
 @param $template
  @param $merged-content
  :)
declare function site:delivery($job, $template as xs:string, $merged-content as xs:base64Binary) {
    let $action := request:get-parameter("action","")
    return 
    if ($action eq "download") 
        then local:stream-result($template, $job, $merged-content)
    else if ($action eq "save-in-job-folder") 
        then local:save-in-job-folder($job,$template, $merged-content)
    else if ($action eq "email-to-teacher") then
        local:send-email($job, $template, $merged-content)
    else ()
        
};