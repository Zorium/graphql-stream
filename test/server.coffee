_ = require 'lodash'
b = require 'b-assert'

{api, nameGen, createClient} = require './util'

it = if window? then (-> null) else global.it

describe 'cache', ->
  it 'initializes from cache', ->
    cacheClient = createClient()
    cacheClient.call api.CreateUser, {input: {name: nameGen()}}
    .then ({user}) ->
      cacheClient.stream api.User, {id: user.id}
      .take(1).toPromise()
    .then ({user}) ->
      cacheClient.cacheStream().take(1).toPromise()
      .then (cache) ->
        b _.keys(cache).length, 1
        cacheKey = _.keys(cache)[0]
        b String(parseInt(cacheKey)), cacheKey

        # XXX: ugly...
        _.map cache, (cached) ->
          cached.callCount = 0

        client = createClient {cache}
        stream = client.stream api.User, {id: user.id}

        stream.take(1).toPromise()
        .then ({callCount}) ->
          b callCount, 0
        .then ->
          client.call api.UpdateUser, {input: {id: user.id, name: 'axe'}}
        .then ({callCount}) ->
          b callCount, 1
          stream.take(1).toPromise()
        .then ({user}) ->
          b user.name, 'axe'

describe 'subscribe', ->
  it 'returns undefined server side', ->
    client = createClient()
    b undefined,
      await client.subscribe({token: 'xxx'}, api.subscribe).take(1).toPromise()
