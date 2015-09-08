Firebase = require 'firebase'

module.exports =
class PairSession
  constructor: ->
    @pushChange = true

  # start will initiate a pairing session. It need to know what to do
  # when the remote cursor location changes and the remote text is edited.
  start: (onRemoteCursorChange, onRemoteTextChange) ->
    atom.notifications.addSuccess 'You started a Pair-Now session'
    @register('master', 'pair', onRemoteCursorChange, onRemoteTextChange)

  # join will join an existing pairing session.
  join: (onRemoteCursorChange, onRemoteTextChange) ->
    atom.notifications.addSuccess 'You joined a Pair-Now session'
    @register('pair', 'master', onRemoteCursorChange, onRemoteTextChange)

  register: (localName, remoteName, onRemoteCursorChange, onRemoteTextChange) ->
    firebase_project = atom.config.get 'pair-now.firebase_project'
    pairSession = new Firebase("https://#{firebase_project}.firebaseio.com/session/1")
    pairSession.remove() if localName is 'master'

    # Share local editor
    @editor = pairSession.child('editors/shared')
    # Expose local cursor
    @cursor = pairSession.child("cursors/#{localName}")
    # Expose local changes
    @changes = pairSession.child("changes/#{localName}")

    # Listen for remote cursor
    pairSession.child("cursors/#{remoteName}").on 'value', (cursorPosition) =>
      onRemoteCursorChange(cursorPosition.val())
    # Listen for remote changes
    pairSession.child("changes/#{remoteName}").on 'child_added', (textChange) =>
      @pushChange = false
      onRemoteTextChange(textChange.val())
      @pushChange = true

  # share will mark a local editor as shared so that remote user can read its
  # content.
  share: (sharedEditor) ->
    @editor.set
      text: sharedEditor.getText()
      grammar: sharedEditor.getGrammar().scopeName
      tabLength: sharedEditor.getTabLength()
      softTabs: sharedEditor.getSoftTabs()

  # configureEditor will set the text and parameters of a local editor
  # given the status of a remote editor.
  # It should NOT trigger a sync since this is already a sync.
  configureEditor: (editor, remoteEditor) ->
    @pushChange = false
    editor.setText(remoteEditor.text)
    editor.setGrammar(atom.grammars.grammarForScopeName(remoteEditor.grammar))
    editor.setTabLength(remoteEditor.tabLength)
    editor.setSoftTabs(remoteEditor.softTabs)
    editor.setCursorBufferPosition([0, 0])
    @pushChange = true

  # onEditorChange will react to a change on a remote shared editor.
  onEditorChange: (callback) ->
    @editor.on 'value', (remoteEditor) =>
      callback(remoteEditor.val())

  # updateCursor will be notified when the local cursor changes.
  updateCursor: (row, col) ->
    @cursor.set
      row: row
      col: col

  # updateText will be notified when the local text changes.
  updateText: (oldRange, oldText, newRange, newText) ->
    return unless @pushChange
    @changes.push
      oldRange: oldRange
      oldText: oldText
      newRange: newRange
      newText: newText
