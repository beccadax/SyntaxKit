SyntaxKit
========

SyntaxKit is a Cocoa framework with the following features:

* Syntax highlighting
* Basic code editing, particularly concerning indentation
* On-screen line numbering

The syntax highlighting and code editing features are based on [UKSyntaxColoredTextViewController][uksyntax], and the line numbering is based on [NoodleLineNumberView][noodleline]. However, both of these have been extensively modified, and are no longer fully compatible with the original versions.

Usage
----

1. In your nib file, drag an `NSTextView` into your window.
2. Drag an Object into the "Objects" section of the Interface Builder dock and set its class to `ASKSyntaxViewController`.
3. Connect your Syntax View Controller's `view` outlet to your `NSTextView`.
4. Add an outlet to your `NSWindowController` or `NSDocument` subclass of type ASKSyntaxViewController and connect it to your nib's Syntax View Controller.
5. In code, you can set some or all of the following on the Syntax View Controller:
    a. Set the `syntax` property to an `ASKSyntax` object to enable syntax highlighting.
    b. Set the `maintainIndentation` property to control auto-indentation.
    c. Set the `indentsWithSpaces` property to determine whether pressing the Tab key inserts a tab character or several space characters.
    d. Set the `tabDepth` property to determine how many spaces deep a tab character should indent your code, and how many spaces should be inserted when you hit Tab if `indentsWithSpaces` is set.
    e. Set the `wrapsLines` property to decide whether or not lines should be wrapped. If they are wrapped, continued lines will be indented four spaces deeper than the first line.
    f. Set the `showsLineNumbers` property to determine if a line number gutter will be shown alongside your text view.
6. Optionally, hook up the various ASKSyntaxViewController actions to menu items. This may require you to implement `-supplementalTargetForAction:sender:` in your `NSWindowController` to route these methods to it. These actions are compatible with Cocoa Bindings, so you can use `-bind:toObject:withKeyPath:options:` to bind the `maintainIndentation`, `indentsWithSpaces`, `tabDepth`, `wrapsLines`, and `showsLineNumbers` properties.
7. Load source code into the text view, either by setting the contents of its text storage or by binding the NSTextView.
8. If desired, set the Syntax View Controller's delegate. The Syntax View Controller will set itself to be the NSTextView's delegate, but it will pass all NSTextViewDelegate messages through to its own delegate. It also implements its own delegate methods in ASKSyntaxViewControllerDelegate.

To Do
-----

The current version of SyntaxKit is basically functional, and is used in [Ingist][ingist] for code editing. However, many things are broken or suboptimal:

* There are some rendering glitches in ASKLineNumberView, usually brought out by scrolling.
* -[ASKSyntaxViewController indentSelection:] and -[ASKSyntaxViewController unindentSelection:] do not fully support ASKSyntaxViewController's indentation-controlling properties.
* ASKSyntax(syntaxForType) does not have any mechanism for loading syntaxes shipped in an app or in a user directory, and the mapping between UTIs and syntaxes is kind of hacky.
* ASKSyntax should probably be refactored into components for labeling syntax and for coloring based on those labels. It may make sense to turn the syntax defintion into a set of objects, too.
* I might rework the syntax coloring to base it on regexes.
* SyntaxKit desperately needs more syntaxes. Currently it only supports HTML, CSS, and Objective-C; it uses the Objective-C syntax highlighting for other C variants.

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

