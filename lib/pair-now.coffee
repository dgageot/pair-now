PairNowView = require './pair-now-view'
{CompositeDisposable} = require 'atom'

module.exports = PairNow =
  pairNowView: null
  modalPanel: null
  subscriptions: null

  activate: (state) ->
    @pairNowView = new PairNowView(state.pairNowViewState)
    @modalPanel = atom.workspace.addModalPanel(item: @pairNowView.getElement(), visible: false)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'pair-now:toggle': => @toggle()

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @pairNowView.destroy()

  serialize: ->
    pairNowViewState: @pairNowView.serialize()

  toggle: ->
    console.log 'PairNow was toggled!'

    if @modalPanel.isVisible()
      @modalPanel.hide()
    else
      @modalPanel.show()
