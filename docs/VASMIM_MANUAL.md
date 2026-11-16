# Vasmim User Manual

Windows desktop edition | Version 0.1.0-beta.2

Vasmim is a local-first visual thinking app for Windows. It brings editable Notes, reference Images, documents, audio, movies, and YouTube links onto spacious Boards, where you can arrange ideas, connect related material, and build visual project plans. Named Scenes help you revisit and present particular views. Portable Board files and clean image exports let you carry or share your work.

This manual explains the app's current abilities and common workflows.

## Contents

1. Understand the workspace
2. Start and organize Boards
3. Navigate and arrange a Board
4. Write and format Notes
5. Collect Images and web references
6. Work with documents and local media
7. Make relationships visible
8. Draw and organize Shapes
9. Keep related items in Groups
10. Save views and present with Scenes
11. Find material and explore ideas
12. Save, copy, transfer, and back up
13. Share clean Board images
14. Everyday workflows
15. Controls and shortcuts

## 1 Understand the workspace

### Library

The Library is your starting point for creating, opening, finding, and organizing Boards. Each Board has its own content and managed assets. Project folders organize the Library; favorites keep important Boards easy to reach.

### Board

A Board is a fixed 6,000 by 4,500 unit work area. You can pan across it and zoom between detailed work and a wider view. The Board is large but finite. Its quiet dot grid gives placement references without taking attention away from the material.

### Content and visual structure

Notes hold editable text. Images hold visual references. Canvas Headings label areas. Attachment cards keep documents and local media close to the relevant ideas. YouTube cards retain a video URL and thumbnail. Connectors express relationships between Notes and Images. Background Shapes create lanes, frames, symbols, and other visual structure.

Groups collect related items for repeated selection and coordinated actions. Scenes save named views of a Board. Shape Layers organize the background Shapes independently of foreground content.

**Practical distinction:** a Scene remembers a view, a Group remembers a set of items, and a Library folder organizes Boards.

## 2 Start and organize Boards

### Create a blank Board

1. Open the Library and select the project folder you want to use.
2. Choose **New board**.
3. Enter a name and confirm creation.
4. Begin with Notes, Images, or other material. A new blank Board provides a gentle starting prompt.

A new Board belongs to the selected project folder. In **All Boards**, creation falls back to the latest-created folder when one exists. Select **Unfiled** to create a Board without folder membership. When there are no folders, the Board is unfiled. Canceling the name dialog creates nothing.

### Use a starter layout

The **Starter board** menu offers four editable layouts:

| Starter | Starting structure | Example use |
| --- | --- | --- |
| Kanban | To do, In progress, Done | Arrange work by its current stage |
| Eisenhower Matrix | Four areas combining importance and urgency | Compare priorities |
| SWOT matrix | Strengths, Weaknesses, Opportunities, Threats | Explore a project or proposal |
| Campaign brief | Goal, audience, message, channels, schedule, measures | Organize campaign planning |

These starters use ordinary Shapes and Canvas Headings. You can change their labels and layout and add your own content. They provide spatial structure; moving a Note into a lane does not assign a task status or trigger automation.

### Manage the Library

- Search Board names and change the time ordering between newest first and oldest first.
- Mark Boards as favorites. Favorites are grouped ahead of other Boards within the chosen ordering.
- Create and rename flat project folders, move Boards between them, and filter by a folder or Unfiled.
- Delete an empty project folder after moving its Boards elsewhere.
- Use whole-Board thumbnails to recognize projects visually.
- Open a larger read-only Board preview before entering its editor.
- Rename, duplicate, export, or delete a Board through its actions menu.
- Double-click a Board name to rename it in the Library or editor. The editor also has a Rename control.
- Choose **Find in Explorer** to open the Board's app-managed folder containing its saved document.

Library folders are organizational labels. Moving a Board between them does not move its underlying disk directory. A duplicated Board is a separate copy for exploring another version of a project.

## 3 Navigate and arrange a Board

### Move between detail and overview

Use the mouse wheel to zoom and right-drag to pan. The zoom controls support direct changes, including a manual percentage. **Zoom to Fit** can frame a selected set; the next use returns to the whole-Board view. The **Overview** map helps you understand where material sits and navigate the Board.

### Select and move material

Click an item to select it. Ctrl+click supports multiple selection. Drag a marquee across the Board to select items intersecting the selection area. Move a mixed selection together while retaining the spacing between its members.

Notes and Images have resize controls. Image resizing preserves the source aspect ratio. Notes can be resized using their direct resize rail. Background Shapes have their own bounds or endpoint handles. Other object types use their specific controls rather than a universal free-resize tool.

### Snap and alignment guides

Turn **Snap** on when you want help aligning the layout. Foreground movement can snap to the dot grid and eligible visible peer objects; temporary guides show the alignment. A moving selection uses its combined bounds. Shapes also honor Snap while drawing, resizing, and moving.

Turn Snap off for free placement. The Board remembers the setting, and the toolbar visibly indicates when it is on.

### Protect a layout with Position Lock

Right-click an eligible Note, Image, Canvas Heading, Attachment, or YouTube card and choose **Lock position**. Position Lock protects that item's position and size while leaving its content and opening actions available. Choose **Unlock position** to move it again.

A selection containing a locked item cannot move as a whole. The app avoids moving only part of the arrangement. Position Lock does not prevent deletion and is not a content or password lock.

### Choose appearance

Switch the app between Light and Dark Mode. Each Board also has a saved **Paper tone**: Default, Warm, Blue, or Green. Each tone has a matching shade in both modes. The grid remains aligned to Board coordinates as you navigate.

Canvas content has restrained foreground shadows. Notes and Shapes have their own appearance controls; changing the paper does not recolor your content.

## 4 Write and format Notes

### Capture an idea

Choose **New note**, or right-click an empty Board area and choose **Add note here** to place a Note at that location. Type directly into the Note. Use multiline text and paragraph breaks for longer material.

Notes support optional titles. Double-click a title to edit it directly. Leave a title empty when the body alone is sufficient. Choose a Sticky Note Colour to distinguish categories or give ideas a visual emphasis.

### Format selected text

The text-selection controls support bold, italic, and underline, plus web links on selected text. You can apply manual bullet or numbered-list transformations to complete selected lines. These are deliberate text edits, so you retain control of the result.

### Bring in Markdown-style text

Basic Markdown-style input can become editable Note content: headings become bold text, and supported bullets, inline bold, italic, and web links retain useful presentation. This is a basic subset, rather than a complete Markdown document editor. Use it for bringing structured text into Notes; do not depend on advanced tables, code blocks, or other unimplemented Markdown elements.

### Paste text where you need it

Copy text in another app, then right-click an empty area and choose the contextual text-paste command when available. The app creates an editable Note at that point. When you are editing a Note, clipboard and keyboard operations act on its text instead of the Board selection.

### Label an area with a Canvas Heading

Add a Canvas Heading when you want a standalone label above a topic, lane, or cluster. It is a separate single-line item with preset sizes and backgrounds. Double-click it to edit the text, size, and background together. Select and move it independently, include it in a Group, or lock its position once the layout is settled. A Canvas Heading is distinct from a Note title and from a Heading attached to a Shape.

## 5 Collect Images and web references

### Import an Image

Use **Add image** to bring a PNG, JPEG, or GIF onto the Board. Vasmim keeps a managed copy, so moving or deleting the original source file does not remove the imported reference. Select, move, resize, duplicate, and group Images alongside Notes. Optional captions let you add context to a visual reference.

### Paste a Windows clipboard image

Copy a bitmap or screenshot in another app and use the empty-Board clipboard-image paste command. The result is a managed static PNG. Clipboard image paste does not preserve GIF animation; use **Add image** to import an original GIF file.

### Play a GIF deliberately

Imported GIFs show their first frame at rest. Use the labeled on-Board Play and Pause control, or the corresponding context-menu action, to animate them. GIF playback is temporary; it does not become a saved playback state. Shared Board images show the GIF's first frame.

### Keep website references in Notes

Copy a supported HTTP or HTTPS URL and choose **Paste website here** from the empty-Board context menu. A list containing one supported URL per non-empty line can be pasted into one Note with the website-list command. Duplicate URLs in the list are collapsed.

Website Notes keep the URLs available for deliberate external opening. A multi-link Note identifies that it contains several links and provides an ordered chooser. Links can also be placed on selected Note text. These are references to websites, rather than downloaded offline copies of their pages.

### Keep a YouTube reference

Add a supported YouTube URL to create a thumbnail card. Click its image to open the saved video URL through the system browser or app. **Open in YouTube** is also available in the context menu.

Use the bottom strip to select or drag the card. Ctrl+click selects it. The saved URL and cached thumbnail stay with the Board. If opening fails, Vasmim shows an error and keeps the card usable.

YouTube playback happens externally. The Board does not store a downloaded video or provide an embedded YouTube player.

## 6 Work with documents and local media

### Supported attachments

Use the attachment import action to copy supported files into Board-managed storage. Cards identify their type and original filename and can be arranged alongside related Notes and Images.

| Content | Accepted file extensions | Main behavior |
| --- | --- | --- |
| PDF | .pdf | First-page preview and focused in-app reader |
| Word documents | .doc, .docx | Reference card and external opening |
| Spreadsheets | .xls, .xlsx | Reference card and external opening |
| Movies | .mp4, .m4v, .mov, .mkv, .avi, .webm | Reference card; opens in your default player |
| Audio | .mp3, .wav, .m4a, .flac, .ogg | Reference card; opens in your default player |

Office cards use genuine embedded previews when available and type-specific fallbacks otherwise. Whether an audio or movie file plays depends on the player installed on your computer.

### Read a PDF

Open the PDF card to enter the focused reader. Use previous and next page controls and the page count to navigate. Close the reader to return to the Board. An external-open option is available as a fallback.

The PDF reader is for reading. It does not edit, annotate, perform OCR, or provide full-text PDF search.

### Open audio and movies

Audio and Movie cards keep a managed copy of the file on the Board. Choose **Open in player** on the card, double-click the card, or use **Open in default player** in its context menu. The file opens in the application Windows associates with that file type. Vasmim does not include a built-in audio or movie player.

### Understand managed copies

An imported attachment is a Board-managed copy of the source file. Vasmim does not edit Office documents in place or synchronize changes from the original file. The managed file travels with a portable Board export. This is useful when you want a project to keep its reference material together.

## 7 Make relationships visible

### Connect Notes and Images

Select exactly two eligible Notes or Images and use the contextual connection command. Supported pairs are Note to Note, Note to Image, and Image to Image. Connectors stay attached as the items move or resize.

Add a label to explain the relationship. You can create a connection with a label, click a connection to name or rename it, and use its context menu for relevant actions. Hover feedback helps identify the exact connection.

### Explore connected material

Use **Select connected objects** from an eligible item's context menu to select material connected through the Board's relationships. This helps you review an idea cluster or work with a connected set.

Connectors are straight, undirected relationships. Background arrow Shapes can communicate a visual direction, but they are separate from Connectors. Headings, Attachment cards, YouTube cards, Shapes, and Groups are not Connector endpoints.

## 8 Draw and organize Shapes

### Draw a Shape

Open **Shapes** mode, expand **Choose a Shape**, select a tool, and draw on the Board. Shapes sit behind Connectors and ordinary content, making them useful for areas, lanes, frames, diagrams, and visual emphasis.

A plain click or drag on an exposed visible Shape can also enter Shapes mode on that Shape's layer. Foreground content and Group handles retain interaction priority. Hidden Shapes cannot be activated this way.

### Available catalogue

| Family | Shapes and tools |
| --- | --- |
| Basic geometry | Rectangle, Rounded rectangle, Ellipse, Circle tool, Triangle, Right triangle, Diamond, Parallelogram, Trapezoid, Hexagon |
| Lines and arrows | Straight line, Arrow, Elbow line, Elbow arrow, Double-ended arrow, Double-ended elbow arrow, Curved line, Multi-bend line |
| Directional block arrows | Right, Left, Up, Down, Turn, U-turn, Split, Merge, Circular |
| Flowchart symbols | Terminator, Document, Database, Predefined process |
| Symbols and labels | Pentagon, Octagon, Heart, Lightning, Left bracket, Right bracket, Smiley, Moon, Cloud, Star, Banner, Callout |

The Circle tool starts an ellipse with equal width and height. A later free resize can make it oval. Curved and Multi-bend lines use predefined routes; they do not offer freely editable curve points.

### Edit appearance and geometry

Select a Shape to access its controls near the top of the panel. Change its fill, outline, colors, and attached Heading. Color controls include swatches and a hue wheel. Use bounds or endpoint handles for resizing, and the center handle for movement. Elbow routes provide Across first or Down first routing and a spine handle.

Shape Headings provide text, size, color, alignment, and placement controls. New Headings start white in Dark Mode and black in Light Mode. Saved black or white Heading colors adapt for display across mode changes; other saved colors remain exact.

Use Shape order controls to arrange Shapes within a layer. The Choose a Shape, Layers, and Shape order sections fold independently so the editing controls remain accessible.

### Manage Shape Layers

- Add and rename layers and change their front-to-back order.
- Select the active layer for editing; other layers can stay visible while remaining inactive.
- Move a Shape to another layer.
- Hide or show a layer with its visibility control.
- Set layer opacity to 25%, 50%, 75%, or 100% by clicking its visible percentage.
- Use **Solo** to view one visible Shape Layer while keeping ordinary Board content visible.
- Exit Solo to restore the underlying visible and hidden layer pattern.
- Delete an empty layer after moving its Shapes elsewhere.

Layer opacity affects Shape fills, outlines, arrowheads, and attached Headings. Hidden Shapes are retained in the Board. Solo is a temporary viewing aid; it does not rewrite saved layer visibility. Shapes are visual elements rather than semantic diagram nodes or containers that automatically own Notes.

## 9 Keep related items in Groups

### Create and reuse a Group

Select related eligible items and use the Group command. The Groups list lets you return to that saved set, rename it, hide or show it, and perform coordinated actions. Groups can include foreground items and Shapes, while every Shape retains its Shape Layer membership.

### Edit membership deliberately

Add eligible ungrouped foreground items to one existing Group through the contextual selection controls. Remove an exact member with **Remove from group**. In Shapes mode, select a Shape and choose **Add to group** to pick an existing visible Group.

Removing a member keeps the item on the Board. If fewer than two members would remain, the Group dissolves and its items remain independent. Ungrouping similarly separates the items without deleting their content; deleting a Group is a different action.

### Move together or edit one member

Select the complete Group and drag its central handle to move all members together. Dragging an individual foreground member moves that item; editing one Shape in Shapes mode targets that Shape. This lets you refine a layout while keeping its saved membership.

Whole-Group movement is unavailable if a member is position-locked or a member Shape is excluded by hidden-layer or Solo settings. Show the layer, end Solo, or unlock the relevant member before moving the complete Group.

Groups are flat saved sets. They do not nest, resize all members together, automatically collect overlapping items, or act as visible containers.

## 10 Save views and present with Scenes

### Capture a view

Pan and zoom to the area you want, then save a named Scene. A Scene records that view so you can return to it without manually finding the same position and zoom.

Rename and reorder Scenes to build a useful sequence. **Update view** replaces a Scene's stored view with your current framing. The editor indicates when the current view matches a Scene and uses animated navigation between Scene views.

### Use Walkthrough

Start a Walkthrough to visit saved Scenes in order, or start from a particular Scene. Move through the sequence to explain the project area by area. Exiting returns to your working view.

A Scene is a navigation bookmark, not a separate Board, content snapshot, or slideshow export. Editing an item changes the Board material you see through every Scene that includes it.

## 11 Find material and explore ideas

### Search the current Board

Use **Find on board** or Ctrl+F to locate supported content. Search modes cover Note text and titles, Image filenames and captions, Canvas Headings, labeled connections, and Shape Headings. Navigate from a result to the relevant material instead of searching visually across the whole work area. Attachment cards and YouTube cards are not dedicated Find search categories.

Hidden material remains retained. Search reports relevant hidden state rather than silently showing hidden Shape Layers. Use explicit visibility controls to bring that material back into view.

### Search across Boards

Library tools find supported Notes, Images, Canvas Headings, labeled connections, Scenes, and Shapes across healthy Boards. Results identify the source Board and let you open the relevant location or saved view. Board-name search remains the simple way to find a project itself.

These searches use supported Board metadata and text. They do not search the full contents of imported Office documents, PDF pages, audio, or movies.

### Try Fresh Pair

When the Board contains at least three Notes with written text, **Fresh Pair** shows excerpts from two different Notes together. Choose **Another pair** to explore a different juxtaposition. **Use this pair** selects those two Notes so you can work with them. Closing leaves your earlier selection intact.

Fresh Pair is a lightweight prompt for noticing possible relationships. It does not generate text, create a connection automatically, or change the Notes.

### Recover off-board material

When the editor identifies material outside the Board's usable bounds, the recovery control offers a way to bring it back. This is an object-placement aid, not a substitute for a backup or a guarantee that damaged files can be repaired.

## 12 Save copy transfer and back up

### Save and revise

Boards autosave. Use **Save now** or Ctrl+S when you want an immediate write. Undo and Redo support Board editing actions such as creation, movement, styling, membership changes, and deletion. App viewing state and certain saved Board settings, such as Snap and Paper tone, do not behave like ordinary content-history actions.

### Copy within a Board

Use contextual Copy, Paste, and Duplicate commands for eligible selected items. Copied material receives independent object identities. Internal connections are included when both eligible endpoints are copied. Shapes use their own editing and clipboard path within the Board.

### Copy between Boards

Copy a visible selection of Notes, Images, Canvas Headings, Attachments, and YouTube cards, return to the Library, open the destination Board, and paste. Mixed selections and multiple managed assets are supported. Eligible Groups, Position Locks, and internal Note/Image connections are preserved in the copied selection.

The app's cross-Board clipboard is temporary. Background Shapes and Shape Layer mapping are outside this copying path. Use whole-Board duplication or portable export when you need the complete Shape structure.

### Transfer a complete Board

Export a portable **.vasmim** file from the Library. It packages the Board and its managed assets for import into another Library. Import validates the package and does not overwrite a Board with the same identity. Where a duplicate identity is found, **Import as Copy** creates a separate named copy.

Portable transfer preserves Board content, layout, Scenes, Groups, Shape Layers, and relevant saved settings. Website and YouTube references remain links; their external destinations are not bundled as offline content. Library project-folder organization is separate from the portable Board.

### Back up the Library

1. Choose **Export all boards** and select a destination folder.
2. Keep the resulting portable Board packages and backup manifest together.
3. Choose **Verify backup folder** and select that folder to check it.
4. Store a copy separately from the working Library according to your own backup routine.

Export All covers the Library rather than only the current search or folder view. Backup verification checks the inventory, package safety, Board identity, and file hashes without importing or changing the Library. Unavailable Boards block a complete Library export so the app does not report an incomplete backup as complete.

## 13 Share clean Board images

Right-click an empty Board area and choose **Share Board image**. Select one of four actions:

| Area | Save | Copy |
| --- | --- | --- |
| Current view | Save PNG of your current framing | Copy the current view as an image |
| Whole Board | Save the complete 6,000 by 4,500 Board as PNG | Copy the complete Board as an image |

The shared image excludes editor controls and selection overlays. The current view follows your pan and zoom. Whole-Board sharing covers the fixed Board at one pixel per Board unit, independent of the working view.

Visibility, Solo, layer opacity, and the selected paper tone affect the composition. Hidden material is omitted. A shared image is a static output, not an editable Board or a recording of media playback. GIFs use their first frame.

For a marketing screenshot, finish your layout, select a suitable theme and paper tone, set the intended layer visibility, and choose a framing that makes the example easy to understand. Share the current view for a focused example, or the whole Board for an overall plan.

## 14 Everyday workflows

### Build a research Board

Create a Board in a project folder. Add a question as a Canvas Heading, collect website Notes, import reference Images, and attach source PDFs. Write your own observations in Notes. Connect related Notes and Images, then name Scenes for major themes. Export the Board when you need to carry the complete collection to another computer.

### Plan creative work

Place Images, written concepts, GIF references, audio clips, and movie references beside one another. Use colored Notes to distinguish ideas or alternatives. Group related material and create background areas with Shapes. Use Fresh Pair when you want to reconsider relationships between written ideas.

### Organize a campaign

Start with the Campaign brief layout. Populate the six areas with Notes, example visuals, source links, and supporting documents. Add Shapes or labels where the project needs more structure. Save Scenes to explain the goal, audience, creative direction, and schedule in a chosen order.

### Compare priorities

Create an Eisenhower Matrix Board. Put each proposed action into a Note and move it into the appropriate quadrant. Keep supporting references nearby. Revise placement as your judgment changes. This is a visual planning process; Vasmim does not automatically calculate priority or schedule work.

### Present an evolving project

Arrange the project on one Board and save an ordered Scene sequence. Run a Walkthrough to explain it. Share clean PNG views for documents or messages. Use a portable Board package when the recipient needs editable content and has Vasmim, rather than only a static picture.

## 15 Controls and shortcuts

| Control | Action |
| --- | --- |
| Mouse wheel | Zoom |
| Right-drag | Pan |
| Ctrl+click | Add or toggle items in a multiple selection |
| Drag a marquee | Select items intersecting the selection area |
| Right-click | Open commands for the item, selection, or empty area |
| Ctrl+S | Save now |
| Ctrl+F | Find on the open Board |
| Ctrl+Z | Undo |
| Ctrl+Y or Ctrl+Shift+Z | Redo |
| Ctrl+C | Copy the eligible Board selection |
| Ctrl+V | Paste copied Board objects |
| Delete | Delete the selection |
| Double-click a Board name | Rename the Board |
| Double-click a Note title | Edit that title |
| Double-click a Canvas Heading | Edit its text, size, and background |
| Double-click an Audio or Movie card | Open it in your default player |
| Group center handle | Move the complete Group |

Text-editing shortcuts take priority when a Note editor has focus. Click outside the text editor before issuing a Board-level selection command. Use the Help control in the Library or Board for the built-in offline guide and common shortcuts.
