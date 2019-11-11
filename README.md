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

# subscribe(query, variables) -> RxObservable
# creates a websocket subscription
# $sid is passed in by graphql-stream, and must be returned at the top level of all results
client.subscribe('''
  subscription ($sid: String!) {
    viewer(sid: $sid) {
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
