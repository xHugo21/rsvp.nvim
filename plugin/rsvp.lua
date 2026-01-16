vim.api.nvim_create_user_command("Rsvp", require("rsvp").rsvp, { nargs = "?", complete = "file" })
