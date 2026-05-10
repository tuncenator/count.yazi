# count.yazi

Show the number of entries inside each directory in the linemode column. Like ranger's `automatically_count_files`, but async so it never blocks the render thread.

## Requirements

Yazi >= 26.1.22.

## Installation

```sh
ya pkg add tuncenator/count.yazi
```

Or clone manually:

```sh
git clone https://github.com/tuncenator/count.yazi.git ~/.config/yazi/plugins/count.yazi
```

## Setup

Add to `~/.config/yazi/init.lua`:

```lua
require("count"):setup()
```

Register the fetcher in `~/.config/yazi/yazi.toml`:

```toml
[[plugin.prepend_fetchers]]
id  = "count"
url = "*/"
run = "count"
```

And switch your linemode to `count` in the same file:

```toml
[mgr]
linemode = "count"
```

The `count` linemode delegates to the built-in `size` linemode for files, so file sizes still display normally; directories show their entry count once the fetcher populates the cache.

## Options

`require("count"):setup { ... }` accepts:

| Option              | Type           | Default  | Description                                                                                                                          |
| ------------------- | -------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `limit`             | integer        | `10000`  | Maximum entries counted per directory. Larger directories short-circuit and display `overflow_label` instead.                        |
| `overflow_label`    | string         | `"10k+"` | Label for directories with more than `limit` entries.                                                                                |
| `unreadable_label`  | string         | `"?"`    | Label when the directory cannot be read (permission denied, broken symlink, etc).                                                    |
| `show_hidden_aware` | boolean        | `true`   | When the manager has `show_hidden = false`, dotfiles are excluded from the count so the displayed number matches what is on screen.  |
| `style`             | `ui.Style()`  | `nil`    | Optional style applied to the count label.                                                                                           |

Example:

```lua
require("count"):setup {
	limit = 5000,
	overflow_label = "5k+",
	style = ui.Style():fg("blue"),
}
```

## Behavior

- Counts are computed once per directory per session and cached by `(url, mtime)`. Modifying a directory invalidates its count automatically on the next fetch.
- The fetcher runs only for entries whose URL pattern matches `*/` (directories), so file rows incur no extra work.
- `fs.read_dir` is called inside the async fetcher, never from the render path. The linemode method is a pure cache read.
- Symlinks are not resolved (`resolve = false`); a symlink to a directory is counted as the link target's entries on Linux because the kernel returns the target's `getdents`. Set yazi's `mgr.show_symlink` independently if you want different visual treatment.

## Why this plugin exists

Yazi's built-in `size` linemode shows directory entry counts only after a directory has been visited, and only when sorting by size. ranger does it eagerly via `os.listdir`, which is fine on local filesystems but blocks the UI on hung NFS or sshfs mounts. This plugin recreates ranger's eager behavior using yazi's async fetcher API, so counts populate in the background without blocking renders.

## License

MIT.
