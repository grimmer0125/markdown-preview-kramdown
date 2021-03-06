path = require 'path'
fs = require 'fs-plus'
temp = require('temp').track()
url = require 'url'
MarkdownPreviewView = require '../lib/markdown-preview-kramdown-view'

describe "MarkdownPreviewView", ->
  preview = null

  beforeEach ->
    # Makes _.debounce work
    jasmine.useRealClock()

    spyOn(atom.packages, 'hasActivatedInitialPackages').andReturn true

    filePath = atom.project.getDirectories()[0].resolve('subdir/file.markdown')
    preview = new MarkdownPreviewView({filePath})
    jasmine.attachToDOM(preview.element)

    waitsForPromise ->
      atom.packages.activatePackage('language-ruby')

    waitsForPromise ->
      atom.packages.activatePackage('language-javascript')

    waitsForPromise ->
      atom.packages.activatePackage('markdown-preview-kramdown')

  afterEach ->
    preview.destroy()

  describe "::constructor", ->
    it "shows a loading spinner and renders the markdown", ->
      preview.showLoading()
      expect(preview.element.querySelector('.markdown-spinner')).toBeDefined()

      waitsForPromise ->
        preview.renderMarkdown()

      runs ->
        expect(preview.element.querySelector(".emoji")).toBeDefined()

    it "shows an error message when there is an error", ->
      preview.showError("Not a real file")
      expect(preview.element.textContent).toMatch("Failed")

    it "rerenders the markdown and the scrollTop stays the same", ->
      waitsForPromise ->
        preview.renderMarkdown()

      runs ->
        preview.element.style.maxHeight = '10px'
        preview.element.scrollTop = 24
        expect(preview.element.scrollTop).toBe 24

      waitsForPromise ->
        preview.renderMarkdown()

      runs ->
        expect(preview.element.scrollTop).toBe 24

  describe "serialization", ->
    newPreview = null

    afterEach ->
      newPreview?.destroy()

    it "recreates the preview when serialized/deserialized", ->
      newPreview = atom.deserializers.deserialize(preview.serialize())
      jasmine.attachToDOM(newPreview.element)
      expect(newPreview.getPath()).toBe preview.getPath()

    it "does not recreate a preview when the file no longer exists", ->
      filePath = path.join(temp.mkdirSync('markdown-preview-kramdown-'), 'foo.md')
      fs.writeFileSync(filePath, '# Hi')

      preview.destroy()
      preview = new MarkdownPreviewView({filePath})
      serialized = preview.serialize()
      fs.removeSync(filePath)

      newPreview = atom.deserializers.deserialize(serialized)
      expect(newPreview).toBeUndefined()

    it "serializes the editor id when opened for an editor", ->
      preview.destroy()

      waitsForPromise ->
        atom.workspace.open('new.markdown')

      runs ->
        preview = new MarkdownPreviewView({editorId: atom.workspace.getActiveTextEditor().id})

        jasmine.attachToDOM(preview.element)
        expect(preview.getPath()).toBe atom.workspace.getActiveTextEditor().getPath()

        newPreview = atom.deserializers.deserialize(preview.serialize())
        jasmine.attachToDOM(newPreview.element)
        expect(newPreview.getPath()).toBe preview.getPath()

  describe "code block conversion to atom-text-editor tags", ->
    beforeEach ->
      waitsForPromise ->
        preview.renderMarkdown()

    it "removes line decorations on rendered code blocks", ->
      editor = preview.element.querySelector("atom-text-editor[data-grammar='text plain null-grammar']")
      decorations = editor.getModel().getDecorations(class: 'cursor-line', type: 'line')
      expect(decorations.length).toBe 0

    it "sets the editors as read-only", ->
      preview.element.querySelectorAll("atom-text-editor").forEach (editorElement) ->
        expect(editorElement.getAttribute('tabindex')).toBeNull()

    describe "when the code block's fence name has a matching grammar", ->
      it "assigns the grammar on the atom-text-editor", ->
        rubyEditor = preview.element.querySelector("atom-text-editor[data-grammar='source ruby']")
        expect(rubyEditor.getModel().getText()).toBe """
          def func
            x = 1
          end
        """

        # nested in a list item
        jsEditor = preview.element.querySelector("atom-text-editor[data-grammar='source js']")
        expect(jsEditor.getModel().getText()).toBe """
          if a === 3 {
          b = 5
          }
        """

    describe "when the code block's fence name doesn't have a matching grammar", ->
      it "does not assign a specific grammar", ->
        plainEditor = preview.element.querySelector("atom-text-editor[data-grammar='text plain null-grammar']")
        expect(plainEditor.getModel().getText()).toBe """
          function f(x) {
            return x++;
          }
        """

    describe "when an editor cannot find the grammar that is later loaded", ->
      it "updates the editor grammar", ->
        renderSpy = null

        unless typeof atom.grammars.onDidRemoveGrammar is 'function'
          # TODO: Remove once atom.grammars.onDidRemoveGrammar is released
          waitsForPromise ->
            atom.packages.activatePackage('language-gfm')

        runs ->
          renderSpy = spyOn(preview, 'renderMarkdown').andCallThrough()

        waitsForPromise ->
          atom.packages.deactivatePackage('language-ruby')

        waitsFor 'renderMarkdown to be called after disabling a language', ->
          renderSpy.callCount is 1

        runs ->
          rubyEditor = preview.element.querySelector("atom-text-editor[data-grammar='source ruby']")
          expect(rubyEditor).toBeNull()

        waitsForPromise ->
          atom.packages.activatePackage('language-ruby')

        waitsFor 'renderMarkdown to be called after enabling a language', ->
          renderSpy.callCount is 2

        runs ->
          rubyEditor = preview.element.querySelector("atom-text-editor[data-grammar='source ruby']")
          expect(rubyEditor.getModel().getText()).toBe """
            def func
              x = 1
            end
          """

  describe "image resolving", ->
    beforeEach ->
      waitsForPromise ->
        preview.renderMarkdown()

    describe "when the image uses a relative path", ->
      it "resolves to a path relative to the file", ->
        image = preview.element.querySelector("img[alt=Image1]")
        expect(image.getAttribute('src')).toBe atom.project.getDirectories()[0].resolve('subdir/image1.png')

    describe "when the image uses an absolute path that does not exist", ->
      it "resolves to a path relative to the project root", ->

        image = preview.element.querySelector("img[alt=Image2]")
        expect(image.src).toMatch url.parse(atom.project.getDirectories()[0].resolve('tmp/image2.png'))

    describe "when the image uses an absolute path that exists", ->
      it "doesn't change the URL when allowUnsafeProtocols is true", ->
        preview.destroy()

        atom.config.set('markdown-preview-kramdown.allowUnsafeProtocols', true)

        filePath = path.join(temp.mkdirSync('atom'), 'foo.md')
        fs.writeFileSync(filePath, "![absolute](#{filePath})")
        preview = new MarkdownPreviewView({filePath})
        jasmine.attachToDOM(preview.element)

        waitsForPromise ->
          preview.renderMarkdown()

        runs ->
          expect(preview.element.querySelector("img[alt=absolute]").src).toMatch url.parse(filePath)

    it "removes the URL when allowUnsafeProtocols is false", ->
      preview.destroy()

      atom.config.set('markdown-preview-kramdown.allowUnsafeProtocols', false)

      filePath = path.join(temp.mkdirSync('atom'), 'foo.md')
      fs.writeFileSync(filePath, "![absolute](#{filePath})")
      preview = new MarkdownPreviewView({filePath})
      jasmine.attachToDOM(preview.element)

      waitsForPromise ->
        preview.renderMarkdown()

      runs ->
        expect(preview.element.querySelector("img[alt=absolute]").src).toMatch ''


    describe "when the image uses a web URL", ->
      it "doesn't change the URL", ->
        image = preview.element.querySelector("img[alt=Image3]")
        expect(image.src).toBe 'http://github.com/image3.png'

  describe "gfm newlines", ->
    describe "when gfm newlines are not enabled", ->
      it "creates a single paragraph with <br>", ->
        atom.config.set('markdown-preview-kramdown.breakOnSingleNewline', false)

        waitsForPromise ->
          preview.renderMarkdown()

        runs ->
          expect(preview.element.querySelectorAll("p:last-child br").length).toBe 0

    describe "when gfm newlines are enabled", ->
      it "creates a single paragraph with no <br>", ->
        atom.config.set('markdown-preview-kramdown.breakOnSingleNewline', true)

        waitsForPromise ->
          preview.renderMarkdown()

        runs ->
          expect(preview.element.querySelectorAll("p:last-child br").length).toBe 1

  describe "text selections", ->
    it "adds the `has-selection` class to the preview depending on if there is a text selection", ->
      expect(preview.element.classList.contains('has-selection')).toBe false

      selection = window.getSelection()
      selection.removeAllRanges()
      selection.selectAllChildren(document.querySelector('atom-text-editor'))

      waitsFor ->
        preview.element.classList.contains('has-selection') is true

      runs ->
        selection.removeAllRanges()

      waitsFor ->
        preview.element.classList.contains('has-selection') is false

  describe "when core:save-as is triggered", ->
    beforeEach ->
      preview.destroy()
      filePath = atom.project.getDirectories()[0].resolve('subdir/code-block.md')
      preview = new MarkdownPreviewView({filePath})
      # Add to workspace for core:save-as command to be propagated up to the workspace
      waitsForPromise -> atom.workspace.open(preview)
      runs -> jasmine.attachToDOM(atom.views.getView(atom.workspace))

    it "saves the rendered HTML and opens it", ->
      outputPath = fs.realpathSync(temp.mkdirSync()) + 'output.html'
      expectedFilePath = atom.project.getDirectories()[0].resolve('saved-html.html')
      expectedOutput = fs.readFileSync(expectedFilePath).toString()

      createRule = (selector, css) ->
        return {
          selectorText: selector
          cssText: "#{selector} #{css}"
        }

      markdownPreviewStyles = [
        {
          rules: [
            createRule ".markdown-preview-kramdown", "{ color: orange; }"
          ]
        }, {
          rules: [
            createRule ".not-included", "{ color: green; }"
            createRule ".markdown-preview-kramdown :host", "{ color: purple; }"
          ]
        }
      ]

      atomTextEditorStyles = [
        "atom-text-editor .line { color: brown; }\natom-text-editor .number { color: cyan; }"
        "atom-text-editor :host .something { color: black; }"
        "atom-text-editor .hr { background: url(atom://markdown-preview-kramdown/assets/hr.png); }"
      ]

      expect(fs.isFileSync(outputPath)).toBe false

      waitsForPromise ->
        preview.renderMarkdown()

      runs ->
        spyOn(preview, 'getSaveDialogOptions').andReturn({defaultPath: outputPath})
        spyOn(atom.applicationDelegate, 'showSaveDialog').andCallFake (options, callback) ->
          callback?(options.defaultPath)
          # TODO: When https://github.com/atom/atom/pull/16245 lands remove the return
          # and the existence check on the callback
          return options.defaultPath
        spyOn(preview, 'getDocumentStyleSheets').andReturn(markdownPreviewStyles)
        spyOn(preview, 'getTextEditorStyles').andReturn(atomTextEditorStyles)
        atom.commands.dispatch preview.element, 'core:save-as'

      waitsFor ->
        fs.existsSync(outputPath) and atom.workspace.getActiveTextEditor()?.getPath() is outputPath

      runs ->
        expect(fs.isFileSync(outputPath)).toBe true
        expect(atom.workspace.getActiveTextEditor().getText()).toBe expectedOutput

    describe "text editor style extraction", ->

      [extractedStyles] = []

      textEditorStyle = ".editor-style .extraction-test { color: blue; }"
      unrelatedStyle  = ".something else { color: red; }"

      beforeEach ->
        atom.styles.addStyleSheet textEditorStyle,
          context: 'atom-text-editor'

        atom.styles.addStyleSheet unrelatedStyle,
          context: 'unrelated-context'

        extractedStyles = preview.getTextEditorStyles()

      it "returns an array containing atom-text-editor css style strings", ->
        expect(extractedStyles.indexOf(textEditorStyle)).toBeGreaterThan(-1)

      it "does not return other styles", ->
        expect(extractedStyles.indexOf(unrelatedStyle)).toBe(-1)

  describe "when core:copy is triggered", ->
    beforeEach ->
      preview.destroy()
      preview.element.remove()

      filePath = atom.project.getDirectories()[0].resolve('subdir/code-block.md')
      preview = new MarkdownPreviewView({filePath})
      jasmine.attachToDOM(preview.element)

      waitsForPromise ->
        preview.renderMarkdown()

    describe "when there is no text selected", ->
      it "copies the rendered HTML of the entire Markdown document to the clipboard", ->
        atom.commands.dispatch preview.element, 'core:copy'

        waitsFor ->
          atom.clipboard.read() isnt "initial clipboard content"

        runs ->
          expect(atom.clipboard.read()).toBe """
           <h1 id="code-block">Code Block</h1>
           <pre class="editor-colors lang-javascript"><div class="line"><span class="syntax--source syntax--js"><span class="syntax--keyword syntax--control syntax--js"><span>if</span></span><span>&nbsp;a&nbsp;</span><span class="syntax--keyword syntax--operator syntax--comparison syntax--js"><span>===</span></span><span>&nbsp;</span><span class="syntax--constant syntax--numeric syntax--decimal syntax--js"><span>3</span></span><span>&nbsp;</span><span class="syntax--meta syntax--brace syntax--curly syntax--js"><span>{</span></span></span></div><div class="line"><span class="syntax--source syntax--js"><span>&nbsp;&nbsp;b&nbsp;</span><span class="syntax--keyword syntax--operator syntax--assignment syntax--js"><span>=</span></span><span>&nbsp;</span><span class="syntax--constant syntax--numeric syntax--decimal syntax--js"><span>5</span></span></span></div><div class="line"><span class="syntax--source syntax--js"><span class="syntax--meta syntax--brace syntax--curly syntax--js"><span>}</span></span></span></div></pre>
           <p>encoding \u2192 issue</p>
          """

    describe "when there is a text selection", ->
      it "directly copies the selection to the clipboard", ->
        selection = window.getSelection()
        selection.removeAllRanges()
        range = document.createRange()
        range.setStart(document.querySelector('atom-text-editor'), 0)
        range.setEnd(document.querySelector('p').firstChild, 3)
        selection.addRange(range)

        atom.commands.dispatch preview.element, 'core:copy'
        clipboardText = atom.clipboard.read()

        # TODO: Remove this when Atom 1.25 hits stable. Prior to
        # https://github.com/atom/atom/pull/16511 there was a leading newline
        # for some reason I don't care to understand.
        if clipboardText[0] is '\n'
          clipboardText = clipboardText.slice(1)

        expect(clipboardText).toBe '''
          if a === 3 {
            b = 5
          }

          enc
        '''

  describe "when markdown-preview-kramdown:select-all is triggered", ->
    it "selects the entire Markdown preview", ->
      filePath = atom.project.getDirectories()[0].resolve('subdir/code-block.md')
      preview2 = new MarkdownPreviewView({filePath})
      jasmine.attachToDOM(preview2.element)

      waitsForPromise ->
        preview.renderMarkdown()

      runs ->
        atom.commands.dispatch(preview.element, 'markdown-preview-kramdown:select-all')
        {commonAncestorContainer} = window.getSelection().getRangeAt(0)
        expect(commonAncestorContainer).toEqual preview.element

      waitsForPromise ->
        preview2.renderMarkdown()

      runs ->
        atom.commands.dispatch(preview2.element, 'markdown-preview-kramdown:select-all')
        selection = window.getSelection()
        expect(selection.rangeCount).toBe 1
        {commonAncestorContainer} = selection.getRangeAt(0)
        expect(commonAncestorContainer).toEqual preview2.element

  describe "when markdown-preview-kramdown:zoom-in or markdown-preview-kramdown:zoom-out are triggered", ->
    it "increases or decreases the zoom level of the markdown preview element", ->
      jasmine.attachToDOM(preview.element)

      waitsForPromise ->
        preview.renderMarkdown()

      runs ->
        originalZoomLevel = getComputedStyle(preview.element).zoom
        atom.commands.dispatch(preview.element, 'markdown-preview-kramdown:zoom-in')
        expect(getComputedStyle(preview.element).zoom).toBeGreaterThan(originalZoomLevel)
        atom.commands.dispatch(preview.element, 'markdown-preview-kramdown:zoom-out')
        expect(getComputedStyle(preview.element).zoom).toBe(originalZoomLevel)
