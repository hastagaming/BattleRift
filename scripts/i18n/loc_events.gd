class_name LocEvents
extends RefCounted

# Screens connect to this to redraw themselves when the language changes.

signal language_changed(code: String)