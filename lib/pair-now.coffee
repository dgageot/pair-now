{CompositeDisposable} = require 'atom'
PairSession = require './pair-session'

module.exports =
  disposables: null
  connected: false

  config:
    firebase_project:
      type: 'string'
      description: 'Firebase project'
      default: 'pair-now'

  activate: (state) ->
    @disposables = new CompositeDisposable

    atom.commands.add 'atom-workspace', 'pair-now:newSession', => @participate('start')
    atom.commands.add 'atom-workspace', 'pair-now:joinSession', => @participate('join')

    atom.workspace.observeTextEditors (editor) =>
      @disposables.add editor.buffer.onDidChange (event) =>
        @pairSession?.updateText(event.oldRange, event.oldText, event.newRange, event.newText)
      @disposables.add editor.onDidChangeCursorPosition (event) =>
        @pairSession?.updateCursor(event.newBufferPosition.row, event.newBufferPosition.column)

  deactivate: ->
    @disposables.dispose()

  showPairCursor: (editor, pairCursor) ->
    return if editor unless atom.workspace.getActiveTextEditor()

    row = pairCursor.row
    col = pairCursor.col
    return if editor.marker? and (editor.marker.row is row) and (editor.marker.col is col)

    editor.marker.destroy() if editor.marker?
    editor.marker = editor.markBufferRange([[row, 0], [row, col]], invalidate: 'never')
    editor.marker.row = row
    editor.marker.col = col

    type = if col > 0 then 'highlight' else 'line'
    editor.decorateMarker(editor.marker, {type: type, class: 'pair-now-cursor'})

  # action = 'join' or 'start'
  participate: (action) ->
    return if @connected

    @pairSession = new PairSession()
    @pairSession[action] (cursorPosition) =>
      @showPairCursor(atom.workspace.getActiveTextEditor(), cursorPosition)
    , (textChange) =>
      atom.workspace.getActiveTextEditor().buffer.setTextInRange(textChange.oldRange, textChange.newText, undo: 'skip')
    if action is 'start'
      @pairSession.share(atom.workspace.getActiveTextEditor())
    else
      @pairSession.onEditorChange (remoteEditor, editor) ->
        editor.setText(remoteEditor.text)
        editor.setCursorBufferPosition([0, 0])
        editor.setTabLength(remoteEditor.tabLength)
        editor.setSoftTabs(remoteEditor.softTabs)
        editor.setGrammar(atom.grammars.grammarForScopeName(remoteEditor.grammar))

    @connected = true
