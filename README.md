# tag-replacer.nvim

A Neovim plugin for replacing HTML-style tags globally(within a file) or in selections.

## Installation

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use 'BarriosXJavier/tag-replacer.nvim'
```

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    'BarriosXJavier/tag-replacer.nvim',
    config = function()
        require('tag-replacer').setup()
    end
}
```

Using [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'BarriosXJavier/tag-replacer.nvim'
```

## Usage

- Replace tags in entire buffer: `:ReplaceTag from_tag to_tag`
- Replace tags in visual selection: `:ReplaceTagVisual from_tag to_tag`

Example: `:ReplaceTag a Link`
