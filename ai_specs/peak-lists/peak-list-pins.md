# Peak List Pins

- update the peak list buttons in the select peaks drawer to add a trailing pin icon from assets/pin.svg which will pin the peak list to the appbar for the currently viewed region.
- when switching to a new region update the appbar with the pinned peak list for that region
- update the peak list buttons in the appbar to show a trailing unpin button from assets/unpin.svg which will unpin and remove the selected peak list button from the appBar
- This means the peak list button has two behaviours 1. Clicking on the text part of hte button will toggle the button state (selected <-> deselected) and clicking on the pin/unpin will have a separate action.
- if a button is selected from select peaks then show the button in the appBar with the pin icon showing, allowing the peak list to be pinned if desired. On Clicking the button remove the button from the appbar if it is not pinned.

