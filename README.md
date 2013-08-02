SyntaxKit
========

SyntaxKit is a Cocoa framework with the following features:

* Syntax highlighting
* Basic code editing, particularly concerning indentation
* On-screen line numbering

The syntax highlighting and code editing features are based on [UKSyntaxColoredTextViewController][uksyntax], and the line numbering is based on [NoodleLineNumberView][noodleline]. However, both of these have been extensively modified, and are no longer fully compatible with the original versions.

SyntaxKit works with an ordinary `NSTextView`. It is completely compatible with the Cocoa Text System and doesn't keep you from customizing text handling yourself.

SyntaxKit was originally written for [Ingist][ingist], a gist creation tool. If you like SyntaxKit, please check out Ingist—you might find it handy.

Usage
----

1. Open SyntaxKit-Info.plist and find the "Exported Type UTIs" (`UTExportedTypeDeclarations`) key. Copy the two entries into the "Imported Type UTIs" (`UTImportedTypeDeclarations`) key of your app's Info.plist. (Sadly, frameworks like SyntaxKit can't declare UTIs.)
2. Drag an Object into the "Objects" section of the Interface Builder dock and set its class to `ASKSyntaxViewController`.
3. Drag an `NSTextView` into your window and connect your Syntax View Controller's `view` outlet to it.
4. Add an outlet to your `NSWindowController` or `NSDocument` subclass of type ASKSyntaxViewController and connect it to your nib's Syntax View Controller.
5. In code, set the `syntax` property to an `ASKSyntax` object to enable syntax highlighting. (There are a bunch of other useful properties on `ASKSyntaxViewController` that you can set as well—take a look at the header. There are even actions that modify these properties in a Cocoa Bindings-friendly fashion; you'll just need to bind them with `-bind:toObject:withKeyPath:options:`.)
6. Load source code into the text view, either by setting the contents of its text storage or by binding the NSTextView.
7. If desired, set the Syntax View Controller's delegate. The Syntax View Controller will set itself to be the NSTextView's delegate, but it will pass all NSTextViewDelegate messages through to its own delegate. It also implements its own delegate methods in ASKSyntaxViewControllerDelegate.

Syntaxes
-------

SyntaxKit's `ASKSyntax` object represents a particular set of syntax highlighting rules. Each syntax is represented by a property list file with a `.syntaxDefinition` extension and contains several fields:

* Components: An array of rules to be applied.
* OneLineCommentPrefix: A string that can be added to or removed from a line to comment it out. Used by `-[ASKSyntaxViewController toggleCommentForSelection:]`.
* PreferredUTIs: An array of UTIs for file types this syntax is intended to handle. For example, an Objective-C syntax would specify public.objective-c-source as a preferred UTI.
* CompatibleUTIs: An array of UTIs for file types this syntax can also handle, though perhaps not completely accurately. For example, an Objective-C syntax might specify public.c-source as a compatible UTI; Objective-C is very similar to C and it would be better than nothing, but a syntax specifically intended for C would be a better choice if available.

Syntaxes are stored in a folder called "Syntax Definitions". SyntaxKit will look for such a folder in three places:

1. ~/Library/Application Support (within the sandbox for a sandboxed application)
2. The application bundle's Contents/Resources folder.
3. The SyntaxKit framework's Contents/Resources folder.

SyntaxKit will load all of the syntaxes in all of these folders. You can use the `+[ASKSyntax syntaxForType:]` method to fetch a syntax for a given UTI. `+syntaxForType:` will always return a preferred UTI over a compatible UTI. If there's a tie, it will return a syntax from a folder higher in the list above instead of one lower in the list. If there's still a tie, the syntax loaded first will win. Since this is nondeterministic, pay attention to the syntaxes shipped with your app to ensure they don't conflict.

SyntaxKit watches the user-accessible Syntax Definitions folder for changes, and if it sees one, it invalidates the list of syntaxes. You should observe `ASKSyntaxWillInvalidateSyntaxesNotification` and `ASKSyntaxDidInvalidateSyntaxesNotification` to find out when this happens and possibly re-assess which syntax you should use. If you make your own changes to this folder (which you can access through the `+userSyntaxesURL` method), you should call `+invalidateSyntaxes` yourself.

SyntaxKit currently ships with three syntaxes:

* "CSS 1", which includes `org.w3.cascading-style-sheet` as a preferred UTI. (Since there is no system-wide UTI for stylesheets, SyntaxKit declares this one.)
* "HTML", which includes `public.html` as a preferred UTI and `public.xml` as a compatible UTI.
* "Objective C", which includes `public.objective-c-source`, `public.objective-c-plus-​plus-source`, and `public.c-header` as preferred UTIs and `public.c-source`, `public.c-plus-plus-source`, and `public.c-plus-plus-header` as compatible UTIs.

I would be thrilled to accept pull requests adding more syntaxes.

To Do
-----

The current version of SyntaxKit is basically functional, and is used in [Ingist][ingist] for code editing. However, many things are broken or suboptimal:

* There are some rendering glitches in ASKLineNumberView, usually brought out by scrolling.
* -[ASKSyntaxViewController indentSelection:] and -[ASKSyntaxViewController unindentSelection:] do not fully support ASKSyntaxViewController's indentation-controlling properties.
* I might rework the syntax marking to base it on regexes.
* While the ASKSyntaxColorPalette object now encapsulates mapping syntax components to colors, there's currently no mechanism to handle editing color palettes.
* Documentation is generally either nonexistent or out of date.

Although this version is labeled as 1.0, I don't expect the API to remain especially stable, particularly around ASKSyntax. Be careful.

Branches
-------

The SyntaxKit git repository includes the following branches:

* `1.x`: This is a stable release version of SyntaxKit with a broadly 1.0-like API.
* `1.x-develop`: This branch includes additional features and bug fixes that will be integrated into the next release of SyntaxKit. These changes are basically complete, but may not be totally ready to go.

It may also include some branches like the following, although these are usually deleted when finished:

* `feature/whatever`: These feature branches are for features that are currently being developed. They are usually *not* finished.
* `release/1.n`: These release branches include final preparations for a future version of SyntaxKit.

If this sort of thing doesn't look familiar to you, you may want to look into [git-flow][gitflow]. (Here, `1.x` is the "master" branch and `1.x-develop` is the "develop" branch.)

Versioning
--------

Like all frameworks, this one has two version numbers:

* `CFBundleShortVersionString` is the "API version" of the library. The first digit is for very large changes that would probably require apps using SyntaxKit to substantially rework their interactions with the library. The second digit is for changes that might require a little bit of work to integrate. The third digit (if present) is for small patches with no serious impact on the functioning of apps using SyntaxKit.
* `CFBundleVersion` is a build number. It should increase over time, and although it follows a particular format ([nnn]n.nn.n), there's no real meaning to the placement of the decimal points; build 1.23.9 will be followed by build 1.24.0. When merging two branches, you should choose the higher build number, and the build number should always increase at least once on a branch. (On my own Mac, the build number is literally incremented every time the project is built, but you don't have to do that.)

Tests
----

The test suite is empty. I wouldn't mind fixing that.

CocoaPod
-------

There isn't one yet. Submit a pull request and I'll likely accept it.

License
------

Because SyntaxKit is assembled from different sources, different parts are under different licenses. **All of these licenses permit commercial distribution of binaries without requiring payment or credit**, and none of them require your changes to be released as open source, so if you are simply using SyntaxKit in an app you have nothing to worry about.

Portions of the code that are original to SyntaxKit are distributed under the MIT license:

> Copyright (c) 2013 Architechies.
> 
> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
> 
> The above copyright notice and this permission notice shall be included in
> all copies or substantial portions of the Software.
> 
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
> THE SOFTWARE.

`NoodleLineNumberView`, the basis for `ASKLineNumberView`, is also MIT licensed, but is copyrighted 2008-2012 Noodlesoft, LLC.

`UKSyntaxColoredTextViewController`, the basis for `ASKSyntaxViewController` and `ASKSyntax`, is covered by the zlib license, which requires credit be given to Uli Kusterer in all source code distributions of those files.

In general, consult the comments at the top of each file to see how that file is licensed; if you don't see a comment, you may assume it's SyntaxKit code carrying the MIT license.

[uksyntax]: https://github.com/uliwitness/UKSyntaxColoredTextDocument
[noodleline]: http://www.noodlesoft.com/blog/2008/10/05/displaying-line-numbers-with-nstextview/
[ingist]: https://itunes.apple.com/us/app/ingist/id680035328?mt=12
[gitflow]: http://nvie.com/git-model/

