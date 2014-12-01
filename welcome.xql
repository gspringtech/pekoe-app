xquery version "3.0" encoding "UTF-8";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";


declare  
%rest:GET
%rest:path("/pekoe/welcome")
%output:media-type("text/html")
%output:method("html5")

function local:welcome() {
<html><head>

<link rel='stylesheet' href='/pekoe-common/dist/css/bootstrap.css' />
<style type='text/css'>/* <![CDATA[ */
html, body {margin:0; padding:5px;}
/* ]]> */
</style>
<meta charset="UTF-8"/>
<title>Welcome to Pekoe</title>
</head>
<body>
<div style='width:600px'>
    <h1>Welcome to the Pekoe Job Manager.</h1>
    <div>Please choose an item from the bookmarks on the left.</div> 
    <h2>Overview</h2>
    <p>The Pekoe Job Manager is essentially a browser within your Browser. Just like your browser, it has Bookmarks and a Tabbed Workspace. You can have several tabs open at any time
    for Lists, Forms and Reports.</p>
    <h2>Bookmarks</h2>
    <div><p>The bookmarks area is your starting point. The first item in the list will automatically open when you start Pekoe
    (eg. this Welcome).</p>
    <p>You can have multiple folders (<span class='bg-info'>Favourites</span>, Reports etc) - normally only one will be open at a time. The first folder will always be open when you start Pekoe.</p>
    <p>You can make changes by clicking the <span class='bg-info'><i class="glyphicon glyphicon-edit"></i> (Edit)</span> button. Once in Edit mode, you can either 
    <span class='bg-info'><i class='glyphicon glyphicon-save'></i> (Save)</span> or <span class='bg-info'><i class='glyphicon glyphicon-refresh'></i> (Revert)</span> .</p>
    <p>In Edit mode: 
    <ul>
        <li><b>Create a folder</b> by typing a name into the New Bookmarks folder box and pressing Return</li>
        <li><b>Reorder</b> an item by dragging and dropping to where you want it. If you open up another Folder, you can drag it there.</li>
        <li><b>Reorder the folders</b> by dragging them. (Easier when they are closed.)</li>
        <li><b>Add a Bookmark</b> by: <ul><li>dragging a Tab into the Bookmarks list, or</li>
        <li>use the <span class='bg-info'><i class='glyphicon glyphicon-bookmark'></i> (Bookmark)</span> button (far right) to add the current (front) Tab.</li></ul></li>
        <li><b>Rename</b> a bookmark by clicking on its name and editing.</li>
        <li><b>Delete</b> a bookmark using the <span ><i class="glyphicon glyphicon-remove"></i> (Remove)</span> button</li>

    </ul>
    </p>
    <p>Note: when you delete or remove the last item from a folder, you'll be asked whether to keep the Folder. You can't delete the last item of the first folder.</p>
    <p>Tips: 
        <ul>
            <li>Try moving the <span class='bg-info'>Files</span> folder to the top of the first list, then Save and reload Pekoe.</li>
            <li>Make only one or two changes before Saving or Reverting.</li>
            <li class='bg-info'>Hold down the command (Mac) or Control (Win) -key and click on an item in the Files list to open it in a new Tab</li>
            <li>You can't add a Tab to a Bookmark list if it's already there.</li>
            <li>Can't drag an existing bookmark into a new Folder. Must save first.</li>
            <li>Can't rename a folder. Create a new one, Save, then drag items into it.</li>
        </ul>
    </p>
    <p></p>
    </div>
    <h2>Lists</h2>
    <p>When you double-click any <span class='xml' >xml-file</span> a new tab will be opened for that item. To edit the data, you'll need to find an appropriate Template
    from the Template Selector. Applicable Templates will be highlighted - you may need to click on a subsection to find one. 
    </p>
    <p>Templates provide different views of the data.</p>
    <h2>Forms</h2>
    <p></p>
</div>
</body>
</html>

};

()