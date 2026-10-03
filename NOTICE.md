# Third-party notices

## Stray

Parts of `Sources/DevMonitorCore/ProcessScanner.swift`, `ProcessArguments.swift` and
`ListeningPorts.swift` — the code that reads the process list, a process's command line, its
working directory and its listening ports through `libproc` — are adapted from
[Stray](https://github.com/steppannws/Stray), which is released under the MIT License:

```
MIT License

Copyright (c) 2026 Stepan Nikulenko

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Logos

The logos embedded in `Sources/DevMonitorUI/BrandIcon.swift` (Docker, Claude, OpenAI, Model
Context Protocol, Node.js, Python, Bun, Deno) were sourced from
[Simple Icons](https://simpleicons.org). Each logo is the property of its owner and subject to
that owner's brand terms; the licence of Simple Icons covers that project, not the marks
themselves. They are used only to identify the tool a row belongs to. DevMonitor is not
affiliated with or endorsed by any of these owners.
