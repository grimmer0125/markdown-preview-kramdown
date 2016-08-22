# Atom package -  Markdown Preview Kramdown

Since different Markdown implementation will output differetn HTML sometimes, I make this package to let people preview the articles on GitHub Pages on Atom. It is modified from [Markdown Preview](https://github.com/atom/markdown-preview)  

Show the rendered HTML markdown to the right of the current editor using <kbd>ctrl-shift-m</kbd>.

It is currently enabled for `.markdown`, `.md`, `.mdown`, `.mkd`, `.mkdown`, `.ron`, and `.txt` files.

![markdown-preview](https://cloud.githubusercontent.com/assets/378023/10013086/24cad23e-6149-11e5-90e6-663009210218.png)

## Install

1. You need to install kramdown library first. Follow the instruction, http://kramdown.gettalong.org/installation.html. 
2. Install this atom package. 
3. (Optional) You may disable the default built-in Markdown-Preview to avoid confusion on shortcuts. They use the same shortcuts and this package will override those in Markdown-Preview.   

## To-do List 

- [ ] Ignore the Front Matter of Jekyll.
- [ ] Other encoding check/support. Now it supports ASCII and UTF-8, and other encoding needed to added. 
- [ ] Automaticall install the needed kramdown library.
- [ ] Debug and Add back syntax highlight.  

## Other ways to preview the articles on GitHub Pages 
1. Run Local Jekyll (e.g. bundle exec jekyll serve --config _config_dev.yml)
2. Paste markdown to https://trykramdown.herokuapp.com/
3. Paste markdown to https://kramdown.herokuapp.com/

## About Fenced code block
1. [Syntax highlighting of GitHub Flavored Markdown ](https://help.github.com/articles/creating-and-highlighting-code-blocks/). It uses ```.
2. [Fenced code block of Kramdown](http://kramdown.gettalong.org/syntax.html#fenced-code-blocks). It uses ~~~.

GitHub Pages and some/all markdown files on GitHub can accept these two types and show correctly. But this atom package only handles Kramdown type(~~~). Please keep in mind, and my opinion is to use ~~~. Also They both support non-fenced standard code block (indented 4 spaces) and single line code span.   

## About Kramdown
According [https://github.com/blog/2100-github-pages-now-faster-and-simpler-with-jekyll-3-0](https://github.com/blog/2100-github-pages-now-faster-and-simpler-with-jekyll-3-0), *Starting May 1st, 2016, GitHub Pages will only support kramdown, Jekyll's default Markdown engine.*

## License

Markdown Preview Kramdown is released under the [MIT license][license].

[license]: LICENSE.md
