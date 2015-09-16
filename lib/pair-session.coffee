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

    atom.notifications.addSuccess 'Connect to Firebase'
    atom.notifications.addSuccess 'Remove previous session when starting a new one'
    atom.notifications.addSuccess 'Share local editor (editors/shared)'
    atom.notifications.addSuccess 'Publish local cursor (cursors/#{localName})'
    atom.notifications.addSuccess 'Publish local text changes (changes/#{localName})'
    atom.notifications.addSuccess 'Listen for remote cursor location'
    atom.notifications.addSuccess 'Apply remote cursor location'
    atom.notifications.addSuccess 'Listen for remote text changes'
    atom.notifications.addSuccess 'Apply remote text changes'
    atom.notifications.addSuccess 'Make sure we can\'t connect twice'

    # Connect to Firebase
    # TODO
    pairSession = new Firebase("https://#{firebase_project}.firebaseio.com/session/1")

    # Remove previous session
    # TODO
    pairSession.remove() if localName is 'master'

    # Share local editor
    # TODO
    @editor = pairSession.child("editor/shared")

    # Publish local cursor
    # TODO
    @cursor = pairSession.child("cursors/#{localName}")

    # Publish local text changes
    # TODO
    @changes = pairSession.child("changes/#{localName}")

    # Listen for remote cursor
    # TODO
    pairSession.child("cursors/#{remoteName}").on 'value', (cursorPosition) ->
      onRemoteCursorChange(cursorPosition.val())

    # Listen for remote text changes. When applying those changes locally
    # don't forget to NOT push those changes to Firebase.
    # TODO
    pairSession.child("changes/#{remoteName}").on 'child_added', (textChange) ->
      onRemoteTextChange(textChange.val())

  # shareLocalEditor will mark a local editor as shared so that remote user can read its
  # content. It publishes the text and important settings such as the file type
  # and tab/space settigns.
  shareLocalEditor: (text, grammar, tabLength, softTabs) ->
    console.log "Share the editor text and settings"
    # TODO
    @editor.set
      text: text
      grammar: grammar
      tabLength: tabLength
      softTabs: softTabs

  # onRemoteEditorShared will react to a remote editor being shared.
  onRemoteEditorShared: (cloneTheEditor) ->
    # TODO
    @editor.on 'value', (remoteEditor) ->
      cloneTheEditor(remoteEditor.val())

  # localCursorChanged will be notified when the local cursor changes.
  localCursorChanged: (row, col) ->
    console.log "Cursor moved row=${row}, col=${col}. We should push that to firebase"
    # TODO
    @cursor.set
      row: row
      col: col

  # localTextChanged will be notified when the local text changes.
  localTextChanged: (oldRange, oldText, newRange, newText) ->
    return unless @pushChange
    console.log "Text changed oldRange=${oldRange}, oldText=${oldText}, newRange=${newRange}, newText=${newText}"
    console.log "We should push that to firebase"
    # TODO
    @changes.push
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
