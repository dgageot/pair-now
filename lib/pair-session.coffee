Firebase = require 'firebase'

module.exports =
class PairSession
  constructor: ->
    @pushChange = true

  # start will initiate a pairing session. It need to know what to do
  # when the remote cursor location changes and the remote text is edited.
  start: (onRemoteCursorChange, onRemoteTextChange) ->
    @register('master', 'pair', onRemoteCursorChange, onRemoteTextChange)

  # join will join an existing pairing session.
  join: (onRemoteCursorChange, onRemoteTextChange) ->
    @register('pair', 'master', onRemoteCursorChange, onRemoteTextChange)

  register: (localName, remoteName, onRemoteCursorChange, onRemoteTextChange) ->
    # Connect to Firebase
    firebaseProject = atom.config.get 'pair-now.firebase_project'
    pairSession = new Firebase("https://#{firebaseProject}.firebaseio.com/session/1")

    # The master should remove the previous session
    pairSession.remove() if localName is 'master'

    # Share the editor
    @editor = pairSession.child("editor/shared")

    # Share local cursor location
    @localCursorLocation = pairSession.child("cursors/#{localName}")

    # Share local text changes
    @localTextChanges = pairSession.child("changes/#{localName}")

    # Listen for remote cursor
    pairSession.child("cursors/#{remoteName}").on 'value', (remoteCursorPosition) ->
      onRemoteCursorChange(remoteCursorPosition.val())

    # Listen for remote text changes
    pairSession.child("changes/#{remoteName}").on 'child_added', (remoteTextChange) ->
      onRemoteTextChange(remoteTextChange.val())

  # shareLocalEditor will mark a local editor as shared so that remote user can read its
  # content. It publishes the text and important settings such as the file type
  # and tab/space settings.
  shareLocalEditor: (text, grammar, tabLength, softTabs) ->
    @editor.set
      text: text
      grammar: grammar
      tabLength: tabLength
      softTabs: softTabs

  # onRemoteEditorShared will react to a remote editor being shared.
  onRemoteEditorShared: (configureLocalEditorFromRemoteEditor) ->
    @editor.on 'value', (remoteEditor) ->
      configureLocalEditorFromRemoteEditor(remoteEditor.val())

  # localCursorChanged will be notified when the local cursor changes.
  # Let's save latest local cursor position to Firebase
  localCursorChanged: (row, col) ->
    @localCursorLocation.set
      row: row
      col: col

  # localTextChanged will be notified when the local text changes.
  # Let's save another local text change to Firebase
  localTextChanged: (oldRange, oldText, newRange, newText) ->
    return unless @pushChange
    @localTextChanges.push
      oldRange: oldRange
      oldText: oldText
      newRange: newRange
      newText: newText

  # withoutPush will execute an action without notification to firebase
  # This is useful to avoid cycles.
  withoutPush: (callback) ->
    @pushChange = false
    callback()
    @pushChange = true
