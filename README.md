# rsvp.nvim

A Neovim plugin for Rapid Serial Visual Presentation (RSVP). Read through text faster by flashing words one by one in a centered floating window, keeping your eyes focused on a single point.

https://github.com/user-attachments/assets/a8d5b70a-eaae-4ef9-a2dd-5ba8776a955b

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "xhugo21/rsvp.nvim",
  opts = {
    wpm = 300,        -- Initial words per minute
    width = 60,       -- Window width
    height = 20,      -- Window height
    border = "none",  -- Border style
    show_progress = true, -- Show progress bar
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
| **`p`** | Toggle progress bar visibility |
| **`r`** | Reset to the first word |
| **`?`** | Show help popup |
| **`q`** | Close the window |

## Configuration

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `wpm` | `number` | `300` | The reading speed in Words Per Minute. |
| `width` | `number` | `60` | Width of the floating window. |
| `height` | `number` | `20` | Height of the floating window. |
| `border` | `string` | vim.opt.winborder or `"none"` | Border style for the window. |
| `show_progress` | `boolean` | `true` | Whether to show the progress bar by default. |

## Dependencies

- **Neovim >= 0.10.0**

## License

MIT
