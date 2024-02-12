# ![microui](https://user-images.githubusercontent.com/3920290/75171571-be83c500-5723-11ea-8a50-504cc2ae1109.png)
A *tiny*, portable, immediate-mode UI library written in Zig

## Features
* Tiny: around `1100 sloc` of ANSI C
* Works within a fixed-sized memory region: no additional memory is allocated
* Built-in controls: window, scrollable panel, button, slider, textbox, label,
  checkbox, wordwrapped text
* Works with any rendering system that can draw rectangles and text
* Designed to allow the user to easily add custom controls
* Simple layout system

## Example
![example](https://user-images.githubusercontent.com/3920290/75187058-2b598800-5741-11ea-9358-38caf59f8791.png)
```c
if (cc.mu_begin_window(ctx, "My Window", mu_rect(10, 10, 140, 86)) != 0) {
  cc.mu_layout_row(ctx, 2, (int[]) { 60, -1 }, 0);

  cc.mu_label(ctx, "First:");
  if (mu_button(ctx, "Button1") != 0) {
    std.debug.print("Button1 pressed\n", .{});
  }

  cc.mu_label(ctx, "Second:");
  if (cc.mu_button(ctx, "Button2") != 0) {
    cc.mu_open_popup(ctx, "My Popup");
  }

  if (cc.mu_begin_popup(ctx, "My Popup") != 0) {
    cc.mu_label(ctx, "Hello world!");
    cc.mu_end_popup(ctx);
  }

  cc.mu_end_window(ctx);
}
```

## Screenshot
![screenshot](https://user-images.githubusercontent.com/3920290/75188642-63ae9580-5744-11ea-9eee-d753ff5c0aa7.png)

[**Browser Demo**](https://floooh.github.io/sokol-html5/sgl-microui-sapp.html)

## Usage
* See [`doc/usage.md`](doc/usage.md) for usage instructions
* See the [`demo`](demo) directory for a usage example

## Notes
The library expects the user to provide input and handle the resultant drawing
commands, it does not do any drawing itself.

## Contributing
The library is designed to be lightweight, providing a foundation to which you
can easily add custom controls and UI elements; pull requests adding additional
features will likely not be merged. Bug reports are welcome.

## License
This library is free software; you can redistribute it and/or modify it under
the terms of the MIT license. See [LICENSE](LICENSE) for details.

