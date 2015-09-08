Firebase = require 'firebase'

module.exports =
class PairSession
  constructor: ->
    @pushChange = true

  start: (cursorChange, textChange) ->
    atom.notifications.addSuccess 'You started a Pair-Now session'
    @register('master', 'pair', cursorChange, textChange)

  join: (cursorChange, textChange) ->
    atom.notifications.addSuccess 'You joined a Pair-Now session'
    @register('pair', 'master', cursorChange, textChange)

  register: (localName, remoteName, cursorChange, textChange) ->
    firebase_project = atom.config.get 'pair-now.firebase_project'
    pairSession = new Firebase("https://#{firebase_project}.firebaseio.com/session/1")
    pairSession.remove() if localName is 'master'

    # Share local editor
    @editor = pairSession.child('editors/shared')

    # Expose local cursor
    @cursor = pairSession.child("cursors/#{localName}")

    # Listen for remote cursor
    pairSession.child("cursors/#{remoteName}").on 'value', (snapshot) =>
      cursorPosition = snapshot.val()
      cursorChange(cursorPosition) if cursorPosition?

    # Expose local changes
    @changes = pairSession.child("changes/#{localName}")

    # Listen for remote changes
    pairSession.child("changes/#{remoteName}").on 'child_added', (snapshot) =>
      change = snapshot.val()
      if change?
        @pushChange = false
        textChange(change)
        @pushChange = true

  share: (sharedEditor) ->
    @editor.set
      text: sharedEditor.getText()
      grammar: sharedEditor.getGrammar().scopeName
      tabLength: sharedEditor.getTabLength()
      softTabs: sharedEditor.getSoftTabs()

  onEditorChange: (callback) ->
    @editor.on 'value', (snapshot) =>
      remoteEditor = snapshot.val()
      if remoteEditor?
        atom.workspace.open().then (editor) =>
          @pushChange = false
          callback(remoteEditor, editor)
          @pushChange = true

  updateCursor: (row, col) ->
    @cursor.set
      row: row
      col: col

  updateText: (oldRange, oldText, newRange, newText) ->
    return unless @pushChange
    @changes.push
      oldRange: oldRange
      oldText: oldText
      newRange: newRange
      newText: newText
