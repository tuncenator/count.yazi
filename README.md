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
| `style`             | `ui.Style()`  | `nil`    | Optional style applied to the count label.                                                                                           |

The displayed number always reflects what is on screen: when `show_hidden` is off the count excludes dotfiles, when on it includes them. Toggling `show_hidden` updates the label without re-fetching, since both counts are cached together.

Example:

```lua
require("count"):setup {
	limit = 5000,
	overflow_label = "5k+",
	style = ui.Style():fg("blue"),
}
```

## Behavior

- Counts are cached by `(url, mtime)`. Modifying a directory invalidates its count on the next fetch automatically.
- Read failures (permission denied, broken symlink, etc) are stored with the `unreadable_label` so the row is not blank, and are retried on every subsequent fetch event so transient errors recover without restarting yazi.
- The fetcher is registered for `url = "*/"` only, so file rows incur no fetcher cost.
- `fs.read_dir` runs inside the async fetcher; the linemode method is a pure cache read with no I/O.
- Symlinks are not resolved (`resolve = false`); a symlink to a directory is counted as the link target's entries on Linux because the kernel returns the target's `getdents`. Set yazi's `mgr.show_symlink` independently if you want different visual treatment.

## Why this plugin exists

Yazi's built-in `size` linemode shows directory entry counts only after a directory has been visited, and only when sorting by size. ranger does it eagerly via `os.listdir`, which is fine on local filesystems but blocks the UI on hung NFS or sshfs mounts. This plugin recreates ranger's eager behavior using yazi's async fetcher API, so counts populate in the background without blocking renders.

## License

MIT.
