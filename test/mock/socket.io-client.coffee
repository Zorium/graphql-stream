history = []
listeners = []

module.exports = (url) ->
  {
    emit: (channel, message) ->
      history.push {channel, message}
    on: (channel, callback) ->
      listeners.push {channel, callback}
  }

module.exports._history = -> history
module.exports._listeners = -> listeners
