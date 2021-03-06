path = require 'path'
cheerio = require 'cheerio'
createDOMPurify = require 'dompurify'
fs = require 'fs-plus'
Highlights = require 'highlights'
roaster = null # Defer until used
{scopeForFenceName} = require './extension-helper'

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
  content = null
  error = null

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
    # html = sanitize(html)
    html = createDOMPurify().sanitize(html, {ALLOW_UNKNOWN_PROTOCOLS: atom.config.get('markdown-preview-kramdown.allowUnsafeProtocols')})

    html = resolveImagePaths(html, filePath)
    content = html
    callback(null, html.trim())

  stderr = (err) ->
    console.log("err:", err)
    error = err

    if error and !content
      callback(err)

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

  process = new BufferedProcess({command, args, stdout, stderr})

resolveImagePaths = (html, filePath) ->
  [rootDirectory] = atom.project.relativizePath(filePath)
  o = document.createElement('div')
  o.innerHTML = html
  for img in o.querySelectorAll('img')
    # We use the raw attribute instead of the .src property because the value
    # of the property seems to be transformed in some cases.
    if src = img.getAttribute('src')
      continue if src.match(/^(https?|atom):\/\//)
      continue if src.startsWith(process.resourcesPath)
      continue if src.startsWith(resourcePath)
      continue if src.startsWith(packagePath)

      if src[0] is '/'
        unless fs.isFileSync(src)
          if rootDirectory
            img.src = path.join(rootDirectory, src.substring(1))
      else
        img.src = path.resolve(path.dirname(filePath), src)

  o.innerHTML

convertCodeBlocksToAtomEditors = (domFragment, defaultLanguage='text') ->
  if fontFamily = atom.config.get('editor.fontFamily')
    for codeElement in domFragment.querySelectorAll('code')
      codeElement.style.fontFamily = fontFamily

  for preElement in domFragment.querySelectorAll('pre')
    codeBlock = preElement.firstElementChild ? preElement
    fenceName = codeBlock.getAttribute('class')?.replace(/^lang-/, '') ? defaultLanguage

    editorElement = document.createElement('atom-text-editor')

    preElement.parentNode.insertBefore(editorElement, preElement)
    preElement.remove()

    editor = editorElement.getModel()
    lastNewlineIndex = codeBlock.textContent.search(/\r?\n$/)
    editor.setText(codeBlock.textContent.substring(0, lastNewlineIndex)) # Do not include a trailing newline
    editorElement.setAttributeNode(document.createAttribute('gutter-hidden')) # Hide gutter
    editorElement.removeAttribute('tabindex') # Make read-only

    if grammar = atom.grammars.grammarForScopeName(scopeForFenceName(fenceName))
      editor.setGrammar(grammar)

    # Remove line decorations from code blocks.
    for cursorLineDecoration in editor.cursorLineDecorations
      cursorLineDecoration.destroy()

  domFragment

tokenizeCodeBlocks = (html, defaultLanguage='text') ->
  o = document.createElement('div')
  o.innerHTML = html

  if fontFamily = atom.config.get('editor.fontFamily')
    for codeElement in o.querySelectorAll('code')
      codeElement.style['font-family'] = fontFamily

  for preElement in o.querySelectorAll("pre")
    codeBlock = preElement.children[0]
    fenceName = codeBlock.className?.replace(/^lang-/, '') ? defaultLanguage

    highlighter ?= new Highlights(registry: atom.grammars, scopePrefix: 'syntax--')
    highlightedHtml = highlighter.highlightSync
      fileContents: codeBlock.textContent
      scopeName: scopeForFenceName(fenceName)

    highlightedBlock = document.createElement('pre')
    highlightedBlock.innerHTML = highlightedHtml
    # The `editor` class messes things up as `.editor` has absolutely positioned lines
    highlightedBlock.children[0].classList.remove('editor')
    highlightedBlock.children[0].classList.add("lang-#{fenceName}")

    preElement.outerHTML = highlightedBlock.innerHTML

  o.innerHTML
