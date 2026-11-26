# Notes

A Godot Editor plugin that lets you attach short text notes to files and folders in the **FileSystem** dock.

Notes are shown in the editor tooltips, so you can keep reminders, explanations, TODOs, and other project-specific information close to the resources they describe.

The plugin interface supports **English and Russian**. It follows the Godot editor locale: Russian is used when the editor locale starts with `ru`; English is used for all other locales.

## Features

- Add or edit a note from the FileSystem dock's right-click context menu.
- Display notes in file and folder tooltips.
- Preserve notes for files by their Godot resource UID, with the file path used as a fallback.
- Keep folder notes associated with folders and update their paths when folders are moved.
- Store notes locally in the project as JSON.
- Read existing notes in the legacy path-to-text JSON format and migrate them to the current format when possible.

## Requirements

- Godot Engine **4.4** or higher. (Recommended 4.7.2)
- This is an **EditorPlugin**. It runs inside the Godot editor and does not add runtime functionality to exported games.

## Installation

1. Copy or clone this repository into your project's add-ons directory.
2. Make sure the plugin files are located at:

   ```text
   your_project/
   ├── addons/
   │   └── notes/
   │       ├── plugin.cfg
   │       └── plugin.gd
   └── project.godot
   ```

   The folder name `notes` is important because the plugin stores its data at `res://addons/notes/notes.json`.

   To clone directly into the expected folder:

   ```bash
   git clone https://github.com/RolicsVin/godot_notes.git addons/notes
   ```

3. Open the project in Godot.
4. Go to **Project → Project Settings → Plugins**.
5. Find **Notes** and enable it.

## Usage

1. Open the **FileSystem** dock in the Godot editor.
2. Right-click a file or folder.
3. Select **Edit Note…** (or **Изменить подсказку…** when the editor is set to Russian).
4. Enter your note and confirm the dialog.
5. Hover over the resource or folder to see the note in its tooltip.

To change a note, repeat the same steps and edit the existing text. Clear the text to remove the note.

## Data storage

Notes are saved in:

```text
res://addons/notes/notes.json
```

Each entry stores the note text, the resource UID (when available), and the last known path.

For files, the plugin uses the resource UID as the primary identifier. This helps keep a note attached to the same resource when it is moved or renamed. The path is used as a fallback. Folders do not have resource UIDs, so their notes are tracked by path and updated when the editor reports a folder move.

The JSON file is project-local. Include it in version control if you want to share notes with your team; exclude it if the notes should remain local.

## Troubleshooting

- **The plugin does not appear in the Plugins list:** Check that `plugin.cfg` is inside `res://addons/notes/` and that the directory is named `notes`.
- **Notes are not visible:** Make sure the plugin is enabled, then move the pointer over the file or folder in the FileSystem dock.
- **A note no longer matches a file:** The plugin resolves file notes by UID first. If a resource was replaced with a different resource, its UID may also have changed.

## License

See [LICENSE](LICENSE) for license information.
