# Coding Rules
Some rules to be followed when developing specs and plans

## Files to examine
- ./lib/theme.dart
- ./lib/core/constants.dart

## Suppported Platforms
- Only MacOS Desktop is supported. Mobile and compact layouts are not in scope.

## ObjectBox Rules
- objectbox.g.dart is never to be edited. All changes to ObjectBox must be carried out by editing the ObjectBox entities.

## Constants
- All constants are to be defined and maintained in constants.dart

## Theme and styling
- refer to theme.dart 

## Sizing

## Keyboard Shortcuts
These are macOS only so use the Cmd+ sequence rather than Ctrl+ which is used for Windows.
In general Vim style keys are used.

### GlobalShortcuts
Search - Cmd+F
Escape/Cancel - Esc, Ctrl+C
Left - Left, h
Right - Right, l  
Up - Up, k
Down - Down, j

## UI
### Number and Date Formatting
- use 
### Text Fields
### FABs
### Icon + Text and Text Buttons

### Popups
- Simple popups should use /lib/core/widgets/popup_shell.dart
- Complex popups should use  shared numeric/style tokens such as border radius, padding, and close icon sizing in `./lib/core/constants.dart` rather than duplicating them inside the shell widget
### Dialogues
### Icons
Common Icons to be used are listed below and the default colour is onSurface unless overridden:
- Add: Icons.add (used for adding an item or incrementing a value)
- Drag Indicator: Icons.drag_indicator (used to indicate an item can be dragged to a new location)
- Close: Icons.close
- Delete, Trash: Icons.delete_forever colour red.
- Edit: Icons.edit
- Home: Icons.home 
- Import: assets/svg/import.svg
- Info: Icons.info
- Redo: Icons.redo
- Refresh: Icons.refresh
- Remove, Minus: Icons.remove (used for removing an item or decrementing a value)
- Search: Icons.search
- Settings: Icons.settings
- Undo: Icons.undo
- Upload: Icons.upload
- View: Icons.visibility_outlined
- Zoom In: Icons.zoom_in
- Zoom Out: Icons.zoom_out
