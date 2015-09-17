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

  # activate will be called once when the plugin is loaded
  activate: (state) ->
    @disposables = new CompositeDisposable

    # Install the shortcuts to start and join a pair session
    atom.commands.add 'atom-workspace', 'pair-now:newSession', => @participate('start')
    atom.commands.add 'atom-workspace', 'pair-now:joinSession', => @participate('join')

    # React to local text and cursor changes
    atom.workspace.observeTextEditors (editor) =>
      @disposables.add editor.buffer.onDidChange (event) =>
        @pairSession?.localTextChanged(event.oldRange, event.oldText, event.newRange, event.newText)
      @disposables.add editor.onDidChangeCursorPosition (event) =>
        @pairSession?.localCursorChanged(event.newBufferPosition.row, event.newBufferPosition.column)

  # deactivate will clean things up at the end
  deactivate: ->
    @disposables.dispose()

  # showPairCursor displays a secondary cursor with a different color
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

  # participate will be called either when the user starts (action = 'start')
  # or joins (action = 'join') a shared session
  participate: (action) ->
    return if @connected

    # onRemoteCursorChange callback will be called when remote cursor is moved
    onRemoteCursorChange = (cursorPosition) =>
      return unless cursorPosition?
      @showPairCursor(atom.workspace.getActiveTextEditor(), cursorPosition)

    # onRemoteTextChange callback will be called when remote text is changed
    onRemoteTextChange = (textChange) =>
      return unless textChange?
      @pairSession.withoutPush ->
        atom.workspace.getActiveTextEditor().buffer.setTextInRange(textChange.oldRange, textChange.newText, undo: 'skip')

    @pairSession = new PairSession()
    @pairSession[action](onRemoteCursorChange, onRemoteTextChange)

    if action is 'start'
      atom.notifications.addSuccess 'You started a Pair-Now session'

      # If we start a session we start with sharing the active editor
      activeEditor = atom.workspace.getActiveTextEditor()
      text = activeEditor.getText()
      grammar = activeEditor.getGrammar().scopeName
      tabLength = activeEditor.getTabLength()
      softTabs = activeEditor.getSoftTabs()

      @pairSession.shareLocalEditor(text, grammar, tabLength, softTabs)
    else
      atom.notifications.addSuccess 'You joined a Pair-Now session'

      # If we join a session we start with cloning the remote shared editor
      @pairSession.onRemoteEditorShared (remoteEditor) =>
        return unless remoteEditor?
        atom.workspace.open().then (editor) =>
          @pairSession.withoutPush ->
            editor.setText(remoteEditor.text)
            editor.setGrammar(atom.grammars.grammarForScopeName(remoteEditor.grammar))
            editor.setTabLength(remoteEditor.tabLength)
            editor.setSoftTabs(remoteEditor.softTabs)
            editor.setCursorBufferPosition([0, 0])

    @connected = true
