xquery version "3.0";

(: Consider using SSE to send updates.
    Trigger?
    Wait loop with checks? (same as trigger?)
    
    Trigger writes something to a file
    Node.js watches the file
    Node.js handles the Server Sent Events
    When the file changes, Node.js sends the event
    
    What am I watching?
    
    File Browser
    Booking List
    All lists
    
    But what about specific lists?
    e.g. watching page 2 of a list. Should this be updated?
    Currently, I'm doing an update when the Tab is activated. Is there anything wrong with that?
    
    Too hard -
   limited value.
:)
()