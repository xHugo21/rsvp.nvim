# rsvp.nvim

A Neovim plugin for Rapid Serial Visual Presentation (RSVP). Read through text faster by flashing words one by one in a centered floating window, keeping your eyes focused on a single point.

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "xhugo21/rsvp.nvim",
  opts = {
    wpm = 300,        -- Initial words per minute
    width = 60,       -- Window width
    height = 20,      -- Window height
    border = "solid", -- Border style: "none", "single", "double", "rounded", "solid", "shadow"
  },
}
```

## Usage

### Commands

- `:Rsvp`: Start the RSVP presentation for the current buffer.

### Controls

Once the RSVP window is open, you can use the following keymaps:

| Key | Action |
| :--- | :--- |
| **`<Space>`** | Toggle Play / Pause |
| **`k`** | Increase WPM by 50 |
| **`j`** | Decrease WPM by 50 |
| **`r`** | Reset to the first word |
| **`q`** | Close the window |

## Configuration

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `wpm` | `number` | `300` | The reading speed in Words Per Minute. |
| `width` | `number` | `60` | Width of the floating window. |
| `height` | `number` | `20` | Height of the floating window. |
| `border` | `string` | vim.opt.winborder or `"solid"` | Border style for the window. |

## Dependencies

- **Neovim >= 0.10.0**

## License

MIT
