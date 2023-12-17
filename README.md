# repl.nvim

<p align="center">
<a href="https://github.com/neovim/neovim/releases/v0.7.0"><img alt="Neovim" src="https://img.shields.io/badge/Neovim-v0.7-57A143?logo=neovim&logoColor=57A143" /></a>
<a href="https://github.com/almahoozi/repl.nvim/search?l=lua"><img alt="Language" src="https://img.shields.io/github/languages/top/almahoozi/repl.nvim?label=Lua&logo=lua&logoColor=fff&labelColor=2C2D72" /></a>
<a href="https://github.com/almahoozi/repl.nvim/actions/workflows/ci.yml"><img alt="ci.yml" src="https://img.shields.io/github/actions/workflow/status/almahoozi/repl.nvim/ci.yml?label=GitHub%20CI&labelColor=181717&logo=github&logoColor=fff" /></a>
</p>

My first attempt at a Neovim plugin. It's a simple plugin that allows you to run code in a REPL ([Read-Eval-Print Loop](https://en.wikipedia.org/wiki/Read%E2%80%93eval%E2%80%93print_loop)) from within Neovim. I know there are probably existing alternatives, but my point here is to write something that I want to use, and learn a bit of Lua, (N)vim, and plugin development.

At this point in time the focus is to just have a working MVP that can run the selected Go code (since that's what I spend most of my time doing). I am also not doing enough(/any?) validations, so not checking prerequisites for example (yet) but hopefully this won't be the case once this has been fleshed out more.

The end goal is to provide a plugin that can cater to any language; the way this is acheived is by providing configurable templates for each language, in addition to the run command. The plugin then just creates temporary files and runs them however a normal program in that language is run (as configured).

## Installation

Requirements:

- Neovim >= 0.5.0 (I don't know which version actually, just picked one)
- go
- gofmt
- goimports

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
return require('packer').startup(function(use)
  use {
    'almahoozi/repl.nvim',
    config = function()
      require('repl').setup()
    end,
  }
end)
```

### [vim-plug](https://github.com/junegunn/vim-plug)

```vim
call plug#begin()
Plug 'almahoozi/repl.nvim'
call plug#end()
lua require('repl').setup()
```

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
require("lazy").setup({
  {
    'almahoozi/repl.nvim',
    config = function()
      require('repl').setup()
    end,
  },
})
```

## Usage

The plugin doesn't make any assumptions about your mapping preferences (well that's somewhat of a lie)
and so doesn't define any mappings nor commands. You can however set up mappings easily (normal & visual) using the setup function.

The plugin currently provides the following functions, which you can map to or call from anywhere:

- `repl.run(opts)` - Execute the current line (or current selection if in visual mode). Or you can use the opts table to explicitly set the code and language to run `{ code = "{{code to run}}", lang = "go" }`. `run` returns the output of the execution.

```lua
require('repl').setup({
    Mappings = {
        Run = '<leader><cr>',
    }
})
```

Behind the scenes this is just a regular `keymap.set`:

```lua
vim.keymap.set({ "n", "v" }, mapping, function()
    debug("Running REPL", M)
    M.run()
end)
```

## Configuration

The plugin is configured using the `setup` function, which takes a table of options. The following options are available:

- `Debug` - Enable debug logging. Default: `false`. This is pretty verbose, and probably not useful unless you're debugging the plugin.
- `Display` - Creates a new popup window and displays the output of the execution. Default: `true`.
  - Note: I also attach two default keymaps on this window: `<esc>` to close the window, and `<c-]>` to jump to the executed/generated code file. These may be temporary but they're helpful to me.
- `Repls` - The configuration for each language that is supported. This is a table of languages, where each language defines a `template` table and a `run` command to execute. This will eventually be extracted so that it is more extensible without touching the core codebase, but for now here it is. Also could use a better name.
- `Mappings` - Provides a convenient way to keymap to the core functionality with sane defaults and useful utility. No default mappings are provided (for now).
  - `Run` - Keymap to run the current line or selection.
