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
      @disposables.add editor.onDidChangeCursorPosition (event) =>
        @pairSession?.updateCursor(event.newBufferPosition.row, event.newBufferPosition.column)
      @disposables.add editor.buffer.onDidChange (event) =>
        @pairSession?.updateText(event.oldRange, event.oldText, event.newRange, event.newText)

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

    onCursorChange = (cursorPosition) =>
      return unless cursorPosition?
      @showPairCursor(atom.workspace.getActiveTextEditor(), cursorPosition)

    onTextChange = (textChange) =>
      return unless textChange?
      atom.workspace.getActiveTextEditor().buffer.setTextInRange(textChange.oldRange, textChange.newText, undo: 'skip')

    @pairSession = new PairSession()
    @pairSession[action](onCursorChange, onTextChange)

    if action is 'start'
      @pairSession.share(atom.workspace.getActiveTextEditor())
    else
      @pairSession.onEditorChange (remoteEditor) =>
        return unless remoteEditor?
        atom.workspace.open().then (editor) =>
          @pairSession.configureEditor(editor, remoteEditor)

    @connected = true
