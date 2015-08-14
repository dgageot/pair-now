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
    atom.commands.add 'atom-workspace', 'pair-now:test', => @test()

    atom.workspace.observeTextEditors (editor) =>
      @disposables.add editor.buffer.onDidChange (event) =>
        @pairSession?.updateText(event.oldRange, event.oldText, event.newRange, event.newText)
      @disposables.add editor.onDidChangeCursorPosition (event) =>
        @pairSession?.updateCursor(event.newBufferPosition.row, event.newBufferPosition.column)

  test: ->
    atom.notifications.addSuccess 'Test'
    editor = atom.workspace.getActiveTextEditor()
    if !editor
      atom.workspace.open().then (editor) ->
        editor.id = 'toto'
        console.log 'toto'

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

  participate: (action) ->
    return if @connected

    @pairSession = new PairSession()
    @pairSession[action] (cursorPosition) =>
      @showPairCursor(atom.workspace.getActiveTextEditor(), cursorPosition)
    , (textChange) =>
      atom.workspace.getActiveTextEditor().buffer.setTextInRange(textChange.oldRange, textChange.newText, undo: 'skip')

    @connected = true
