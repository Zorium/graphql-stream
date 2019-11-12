_ = require 'lodash'
b = require 'b-assert'

SocketIO = require './mock/socket.io-client'
{api, nameGen, createClient} = require './util'

it = if window? then global.it else (-> null)

describe 'subscribe', ->
  it 'listens over websockets for changes, updating resources', ->
    client = createClient()
    name = nameGen()
    client.call api.CreateUser, {input: {name: name}}
    .then ({user}) ->
      client.stream api.User, {id: user.id}
      .take(1).toPromise()
      .then ({user}) ->
        b user.name, name
        client.subscribe {token: 'xxx'}, api.subscribe
        .take(1).toPromise()
      .then ->
        b SocketIO._history().length, 1
        event = _.first(SocketIO._history())
        b event.channel, 'graphql'
        b event.message.qs.token, 'xxx'

        b SocketIO._listeners().length, 1
        listener = _.first(SocketIO._listeners())
        b listener.channel, 'graphql'

        listener.callback({
          sid: event.message.sid
          data: {
            viewer:
              node: _.defaults({name: 'hatchet', __typename: 'User'}, user)
          }
        })
        client.subscribe {token: 'xxx'}, api.subscribe
        .take(1).toPromise()
      .then ({viewer}) ->
        node = viewer.node
        b node.id, user.id
        client.stream api.User, {id: user.id}
        .take(1).toPromise()
      .then ({user}) ->
        b user.name, 'hatchet'

  it 'handles errors passively', ->
    callCount = 0
    client = createClient({
      onStreamError: -> callCount += 1
    })
    client.subscribe {token: 'xxx'}, api.subscribe
    .take(1).toPromise()
    .then ->
      # XXX: other tests create listeners...
      listener = _.last(SocketIO._listeners())
      listener.callback({
        errors: [{
          message: 'something went horribly wrong'
        }]
      })
      client.subscribe {token: 'xxx'}, api.subscribe
      .take(1).toPromise()
    .then (res) ->
      b res, undefined
      b callCount, 1

  it 'logs sid errors', ->
    callCount = 0
    client = createClient({
      onStreamError: (err) ->
        callCount += 1
        b err.message, 'Missing handler for sid: abc'
    })
    client.subscribe {token: 'xxx'}, '''
      subscription {
        viewer {
          id
        }
      }
    '''
    .take(1).toPromise()
    .then ->
      # XXX: other tests create listeners...
      listener = _.last(SocketIO._listeners())
      listener.callback({
        sid: 'abc'
        data: {
          viewer:
            id: 1
        }
      })
      b callCount, 1
