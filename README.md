# linked-references.nvim


### What is this

**Linked-References** is a Neovim plugin inspired by the Linked References feature in Roam Research, designed to bring a similar networked note-taking experience to markdown files in Neovim. This plugin allows you to view  and to gather lists of references across your markdown notes by leveraging shared front-matter values (ie tags or aliases). When you select a specific tag or alias, Linked-References creates a temporary buffer that gathers and displays all lines in your notes associated with that tag or alias. 

This feature allows you to quickly see the context of each mention across your directory or vault, helping you discover and access related information seamlessly. I also just wanted to write some code :)

### Goal

This for me to learn about building a good plugin for a new editor that I like. And to get away from paying for roam.


### Task List

- [x] got it linking to other markdown files
- [x]  Need to make sure that all links can be referenced
- [x] auto complete for tags and pages
- [x] Make file read-only 
- [ ] handle errors
- [ ] Support Indent level note
- [ ] Make it into an actual plugin

### Setup

Requires: ripgrep, yq, find, telescope neovim .0.9.0

If you use Lazy.nvim as your plugin manager:

```{
    'black-gato/linked-references.nvim',
    opts = {
      path = '.',
      mappings = {
        search_alias = '<leader>;',
      },
    },
  },
```
