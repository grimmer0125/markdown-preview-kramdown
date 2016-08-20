path = require 'path'
_ = require 'underscore-plus'
cheerio = require 'cheerio'
fs = require 'fs-plus'
Highlights = require 'highlights'
{$} = require 'atom-space-pen-views'
roaster = null # Defer until used
{scopeForFenceName} = require './extension-helper'

{spawnSync} = require 'child_process'
{BufferedProcess} = require 'atom'

highlighter = null
{resourcePath} = atom.getLoadSettings()
packagePath = path.dirname(__dirname)

exports.toDOMFragment = (text='', filePath, grammar, callback) ->
  render text, filePath, (error, html) ->
    return callback(error) if error?

    template = document.createElement('template')
    template.innerHTML = html
    domFragment = template.content.cloneNode(true)

    # Default code blocks to be coffee in Literate CoffeeScript files
    defaultCodeLanguage = 'coffee' if grammar?.scopeName is 'source.litcoffee'
    convertCodeBlocksToAtomEditors(domFragment, defaultCodeLanguage)
    callback(null, domFragment)

exports.toHTML = (text='', filePath, grammar, callback) ->
  render text, filePath, (error, html) ->
    return callback(error) if error?
    # Default code blocks to be coffee in Literate CoffeeScript files
    defaultCodeLanguage = 'coffee' if grammar?.scopeName is 'source.litcoffee'
    html = tokenizeCodeBlocks(html, defaultCodeLanguage)
    callback(null, html)

render = (text, filePath, callback) ->
  command = null

  # original markdown:
  # roaster ?= require 'roaster'
  # options =
  #   sanitize: false
  #   breaks: atom.config.get('markdown-preview-kramdown.breakOnSingleNewline')

  # Remove the <!doctype> since otherwise marked will escape it
  # https://github.com/chjj/marked/issues/354
  text = text.replace(/^\s*<!doctype(\s+.*)?>\s*/i, '')

  # editor = atom.workspace.getActiveTextEditor() or getActivePaneItem
  # file = editor?.buffer.file
  # filePath = file?.path

  if !filePath
    console.log 'empty file path, may be unsaved file'
    command = 'ruby'
    filePath = atom.packages.getPackageDirPaths() + "/markdown-preview-kramdown/lib/kramHelper.rb"
    # console.log("package script path:", filePath)
    args = ["--external-encoding", "UTF-8", "-S", filePath, text]
    # this workaround way, specify UTF-8, is from https://github.com/gettalong/kramdown/issues/38
  else
    command = 'ruby'
    # console.log("filepath:", filePath)
    args = ["--external-encoding", "UTF-8", "-S", "kramdown", filePath]

  stdout = (html) ->
    # console.log("output:", html)
    html = sanitize(html)
    html = resolveImagePaths(html, filePath)
    callback(null, html.trim())

  stderr = (err) ->
    console.log("err:", err)
    # sometimes it will be undefined, then will happen exception for line 79
    return callback(err)

  exit = (code) ->
    console.log("exit:", code)

  # roaster text, options, (error, html) ->
  #   console.log 'redner 2.5-1:'
  #   console.log html
  #   return callback(error) if error?
  #
  #   console.log 'redner 2.5-2!'
  #
  #   html = sanitize(html)
  #   html = resolveImagePaths(html, filePath)
  #   callback(null, html.trim())

  process = new BufferedProcess({command, args, stdout, stderr, exit})

  console.log 'after BufferedProcess!'

sanitize = (html) ->
  o = cheerio.load(html)
  o('script').remove()
  attributesToRemove = [
    'onabort'
    'onblur'
    'onchange'
    'onclick'
    'ondbclick'
    'onerror'
    'onfocus'
    'onkeydown'
    'onkeypress'
    'onkeyup'
    'onload'
    'onmousedown'
    'onmousemove'
    'onmouseover'
    'onmouseout'
    'onmouseup'
    'onreset'
    'onresize'
    'onscroll'
    'onselect'
    'onsubmit'
    'onunload'
  ]
  o('*').removeAttr(attribute) for attribute in attributesToRemove
  o.html()

resolveImagePaths = (html, filePath) ->
  [rootDirectory] = atom.project.relativizePath(filePath)
  o = cheerio.load(html)
  for imgElement in o('img')
    img = o(imgElement)
    if src = img.attr('src')
      continue if src.match(/^(https?|atom):\/\//)
      continue if src.startsWith(process.resourcesPath)
      continue if src.startsWith(resourcePath)
      continue if src.startsWith(packagePath)

      if src[0] is '/'
        unless fs.isFileSync(src)
          if rootDirectory
            img.attr('src', path.join(rootDirectory, src.substring(1)))
      else
        img.attr('src', path.resolve(path.dirname(filePath), src))

  o.html()

convertCodeBlocksToAtomEditors = (domFragment, defaultLanguage='text') ->
  if fontFamily = atom.config.get('editor.fontFamily')

    for codeElement in domFragment.querySelectorAll('code')
      codeElement.style.fontFamily = fontFamily

  for preElement in domFragment.querySelectorAll('pre')
    codeBlock = preElement.firstElementChild ? preElement
    fenceName = codeBlock.getAttribute('class')?.replace(/^lang-/, '') ? defaultLanguage

    editorElement = document.createElement('atom-text-editor')
    editorElement.setAttributeNode(document.createAttribute('gutter-hidden'))
    editorElement.removeAttribute('tabindex') # make read-only

    preElement.parentNode.insertBefore(editorElement, preElement)
    preElement.remove()

    editor = editorElement.getModel()
    # remove the default selection of a line in each editor
    editor.getDecorations(class: 'cursor-line', type: 'line')[0].destroy()
    editor.setText(codeBlock.textContent.trim())
    if grammar = atom.grammars.grammarForScopeName(scopeForFenceName(fenceName))
      editor.setGrammar(grammar)

  domFragment

tokenizeCodeBlocks = (html, defaultLanguage='text') ->
  o = cheerio.load(html)

  if fontFamily = atom.config.get('editor.fontFamily')
    o('code').css('font-family', fontFamily)

  for preElement in o("pre")
    codeBlock = o(preElement).children().first()
    fenceName = codeBlock.attr('class')?.replace(/^lang-/, '') ? defaultLanguage

    highlighter ?= new Highlights(registry: atom.grammars)
    highlightedHtml = highlighter.highlightSync
      fileContents: codeBlock.text()
      scopeName: scopeForFenceName(fenceName)

    highlightedBlock = o(highlightedHtml)
    # The `editor` class messes things up as `.editor` has absolutely positioned lines
    highlightedBlock.removeClass('editor').addClass("lang-#{fenceName}")

    o(preElement).replaceWith(highlightedBlock)

  o.html()
