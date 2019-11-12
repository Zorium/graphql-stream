# graphql-stream

Intelligently streams updates based on object `id`, such that updated values from other queries propagate to all listeners.

```coffee
Client = require 'graphql-stream'
client = new Client
  api: 'http://localhost:1337/graphql'
  fetch: (url, opts) -> request url, opts
  cache: cacheSerialization # see `cacheStream()` below
  socketUrl: 'http://localhost:1337/'
  onStreamError: (err) -> console.error err

# call(query, variables) -> Promise
# never served from cache
{createUser} = await client.call('''
  mutation CreateUser($input: CreateUserInput!) {
    createUser(input: $input) {
      user {
        id
        email
      }
    }
  }
''', input: {email, password})

# stream(query, variables) -> RxObservable
# does not error client-side, instead returns `undefined` and calls onStreamError()
client.stream('''
  query {
    user: viewer {
      id
      email
    }
  }
''').map ({user} = {}) -> user

# subscribe(qs, query, variables) -> RxObservable
# creates a websocket subscription
# qs is the querystring for the socket.io url
# this emits {sid, qs, query, variables} over the channel 'graphql'
# responses should arrive on 'graphql' and be of the form {sid, errors, data}
client.subscribe('''
  subscription {
    viewer {
      sid
      event
      node {
        id
        email
      }
    }
  }
''').do ({viewer} = {}) => viewer

# invalidateAll()
# re-requests all active stream queries
client.invalidateAll()

# cacheStream() -> RxObservable
# send from server to client (as escaped json) to populate cache
client.cacheStream().map (cache) -> cache
```
