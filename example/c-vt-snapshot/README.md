# Example: Terminal Snapshots in C

This example creates a terminal with continuation tracking, encodes its full
state, and restores the snapshot using both the one-shot and incremental C
decoder APIs. The incremental path uses a synchronous `SpectreProReader` callback
and reports each restored history page. The standalone project links the static
libspectrepro-vt artifact so it can run consistently on every supported host.

## Usage

Run the example:

```shell-session
zig build run
```
