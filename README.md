# Atom package -  Markdown Preview Kramdown (In development) 

Since different Markdown implementation will differ a little, I make this package to let people preview the articles on GitHub on Atom. It is modified from [Markdown Preview](https://github.com/atom/markdown-preview)  

Show the rendered HTML markdown to the right of the current editor using <kbd>ctrl-shift-m</kbd>.

It is currently enabled for `.markdown`, `.md`, `.mdown`, `.mkd`, `.mkdown`, `.ron`, and `.txt` files.

![markdown-preview](https://cloud.githubusercontent.com/assets/378023/10013086/24cad23e-6149-11e5-90e6-663009210218.png)

## Install

1. You need to install kramdown library first. Follow the instruction, http://kramdown.gettalong.org/installation.html. 
2. Install this atom package. 

## To-do List 

- [ ] Ignore the Front Matter of Jekyll.
- [ ] Other encoding check/support. Now it supports ASCII and UTF-8, and other encoding needed to added. 
- [ ] Add other types of Markdown support. 
- [ ] Automaticall install the needed kramdown library.
- [ ] [More GitHub Flavored Markdown support](https://help.github.com/articles/creating-and-highlighting-code-blocks/). Kramdown uses ~~~ for its [Fenced code block](http://kramdown.gettalong.org/syntax.html#fenced-code-blocks). GitHub Pages use Kmarkdown + Fenced Code Block(```) and Syntax highlighting of GitHub Flavored Markdown instead of those in Kramdown. 

## Other ways to preview the articles on GitHub Pages 
1. Run Local Jekyll
2. Paste markdown to https://trykramdown.herokuapp.com/
3. Paste markdown to https://kramdown.herokuapp.com/
