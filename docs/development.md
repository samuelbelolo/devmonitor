# Development

[← Back to the README](../README.md)

- [Commands](#commands)
- [Layout of the code](#layout-of-the-code)
- [How things are read](#how-things-are-read)
- [Tests](#tests)
- [Regenerating the images](#regenerating-the-images)

## Commands

```bash
make run        # build the app and launch it in the menu bar, from build/
make stop       # quit the app
make install    # build the app, copy it to the Applications folder and launch it
make test       # run the tests
make dump       # print in the terminal what the app would show
make snapshot   # render the memory and agents windows to build/, from this Mac
make media      # render the documentation's images to docs/media/, from sample data
make clean      # remove build output
make help       # every command
```

You need macOS 14 or later and Apple's command line developer tools. There is no Xcode project:
the package builds with `swift build`.

## Layout of the code

| Folder | What it holds |
| --- | --- |
| `Sources/DevMonitorCore` | The scanning, grouping, stop and version logic. No interface. |
| `Sources/DevMonitorUI` | The SwiftUI views and the stores they read. |
| `Sources/DevMonitorApp` | The entry point: the two menu bar items and their windows. |
| `Sources/devmon-dump` | A command that prints what the app sees. |
| `Sources/devmon-snapshot` | A command that renders the windows to PNG files. |
| `Tests/DevMonitorCoreTests`, `Tests/DevMonitorUITests` | The tests of the first two. |
| `scripts/` | `make-app.sh` builds the app bundle, `install.sh` installs it. |

Each file holds one type or one function, named after it.

## How things are read

- **Processes** are read through `libproc` (no `ps` or `lsof`), every 3 seconds while a window
  is open and every 30 seconds otherwise.
- **Docker** is read through its CLI, against the local socket only.
- **Skills** are compared the way `skills update` does it: the git tree hash of each skill's
  folder against GitHub's trees API. The skills lock file and Claude Code's plugin files are
  watched, so the list follows an update as soon as the command that made it is done.
- **Plugins** are compared with their marketplace's catalog: by commit, by declared version, or
  file by file when a plugin has neither.
- **Swap** and the time of the last start come from `sysctl` (`vm.swapusage`, `kern.boottime`).

## Tests

```bash
make test
```

Two tests ask GitHub for real and are skipped by default. To run them:

```bash
DEVMON_LIVE_NETWORK=1 swift test --filter LiveRepoHeadsTests
```

The interface tests host a view in a window and click it: see
`Tests/DevMonitorUITests/HostedView.swift`.

## Regenerating the images

The images of the README and of the guides are rendered from the app's own views:

```bash
make media
```

It writes these files to `docs/media/`, in English and in dark mode, whatever the Mac it runs on:

| File | What it shows |
| --- | --- |
| `memory-window.png` | The memory window |
| `memory-window-swap-critical.png` | The memory window with a critical swap |
| `swap-line-states.png` | The Swap line in its three states |
| `agents-window.png` | The agents window |
| `menu-bar.png`, `menu-bar-swap-high.png`, `menu-bar-swap-critical.png` | The two menu bar items, by state of the swap |

The projects, sessions and extensions in them are made up: they come from
`Sources/DevMonitorUI/SampleData.swift`. The stores behind these views never scan the Mac, ask
the network or stop anything, and `SampleStoresTests` fails if one does. Nothing of the Mac that
renders the images ends up in them.

**Run `make media` whenever a change alters what a window or a menu bar item looks like, and
commit the images with the change.** When the change adds something the sample Mac does not
have, add it to `SampleData.swift` first.

`demo.gif`, `demo.jpg` and `demo.mp4` are a hand-made animation of the same sample Mac. They are
composed outside this repository and `make media` does not touch them: after a visible change,
they have to be redone by hand.
