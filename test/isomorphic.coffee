_ = require 'lodash'
b = require 'b-assert'
Rx = require 'rxjs/Rx'

{api, nameGen, createClient} = require './util'

describe '__streamResult', ->
  it 'stream-ify simple object', ->
    client = createClient()
    streams = {}
    s1 = client.__streamResult {
      user:
        id: 1
        name: 'top'
        ref:
          edges: [
            node:
              id: 2
              name: 'nested'
          ]
    }, client.__parseGQL('query {
      user {
        id
        name
        ref {
          edges {
            node {
              id
              name
            }
          }
        }
      }
    }').definitions[0], streams

    s1.take(1).toPromise()
    .then (val) ->
      b val, {
        user:
          id: 1
          name: 'top'
          ref:
            edges: [
              node:
                id: 2
                name: 'nested'
            ]
      }
      client.__streamResult {
        user:
          id: 1
          name: 'top-updated'
      }, client.__parseGQL('query {
        user {
          id
          name
        }
      }').definitions[0], streams
      .take(1).toPromise()
      .then -> s1.take(1).toPromise()
    .then (val) ->
      b val, {
        user:
          id: 1
          name: 'top-updated'
          ref:
            edges: [
              node:
                id: 2
                name: 'nested'
            ]
      }
      client.__streamResult {
        user:
          id: 2
          name: 'nested-updated'
      }, client.__parseGQL('query {
        user {
          id
          name
        }
      }').definitions[0], streams
      .take(1).toPromise()
    .then (val) ->
      b val, {
        user:
          id: 2
          name: 'nested-updated'
      }

      s1.take(1).toPromise()
    .then (val) ->
      b val, {
        user:
          id: 1
          name: 'top-updated'
          ref:
            edges: [
              node:
                id: 2
                name: 'nested-updated'
            ]
      }

  it 'stream-ify deeply nested object', ->
    client = createClient()
    streams = {}
    s1 = client.__streamResult {
      user:
        id: 1
        name: 'top'
        edges: [
          {
            node:
              id: 2
              name: 'nested'
          }
          {
            node:
              edges: [
                node:
                  id: 3
                  name: 'super-nested'
              ]
          }
        ]
    }, client.__parseGQL('query {
      user {
        id
        name
        edges {
          node {
            id
            name
            edges {
              node {
                id
                name
              }
            }
          }
        }
      }
    }').definitions[0], streams

    s1.take(1).toPromise()
    .then (val) ->
      b val, {
        user:
          id: 1
          name: 'top'
          edges: [
            {
              node:
                id: 2
                name: 'nested'
            }
            {
              node:
                edges: [
                  node:
                    id: 3
                    name: 'super-nested'
                ]
            }
          ]
      }
      client.__streamResult {
        user:
          id: 2
          name: 'nested-updated'
      }, client.__parseGQL('query {
        user {
          id
          name
        }
      }').definitions[0], streams
      .take(1).toPromise()
    .then (val) ->
      b val, {
        user:
          id: 2
          name: 'nested-updated'
      }
      client.__streamResult {
        user:
          id: 3
          name: 'super-nested-updated'
      }, client.__parseGQL('query {
        user {
          id
          name
        }
      }').definitions[0], streams
      .take(1).toPromise()
    .then (val) ->
      b val, {
        user:
          id: 3
          name: 'super-nested-updated'
      }
    .then ->
      s1.take(1).toPromise()
    .then (val) ->
      b val, {
        user:
          id: 1
          name: 'top'
          edges: [
            {
              node:
                id: 2
                name: 'nested-updated'
            }
            {
              node:
                edges: [
                  node:
                    id: 3
                    name: 'super-nested-updated'
                ]
            }
          ]
      }

  it 'handles deeply nested arrays', ->
    client = createClient()
    streams = {}
    s1 = client.__streamResult {
      user:
        id: 1
        ref:
          id: 2
          arr: ['a']
    }, client.__parseGQL('query {
      user {
        id
        ref {
          id
          arr
        }
      }
    }').definitions[0], streams

    s1.take(1).toPromise()
    .then ->
      client.__streamResult {
        user:
          id: 2
          arr: []
      }, client.__parseGQL('query {
        user {
          id
          arr
        }
      }').definitions[0], streams
      .take(1).toPromise()
    .then (val) ->
      b val, {
        user:
          id: 2
          arr: []
      }
      s1.take(1).toPromise()
    .then (val) ->
      b val, {
        user:
          id: 1
          ref:
            id: 2
            arr: []
      }

  it 'handles array reference re-ordering', ->
    client = createClient()
    streams = {}
    s1 = client.__streamResult {
      user:
        id: 1
        edges: [{
          name: 'b'
          ref:
            id: 2
        }, {
          name: 'c'
          ref:
            id: 3
        }]
    }, client.__parseGQL('query {
      user {
        id
        edges {
          name
          ref {
            id
          }
        }
      }
    }').definitions[0], streams

    s1.take(1).toPromise()
    .then ->
      client.__streamResult {
        user:
          id: 1
          edges: [{
            name: 'c'
            ref:
              id: 3
          }, {
            name: 'b'
            ref:
              id: 2
          }]
      }, client.__parseGQL('query {
        user {
          id
          edges {
            name
            ref {
              id
            }
          }
        }
      }').definitions[0], streams
      .take(1).toPromise()
    .then (val) ->
      b val, {
        user:
          id: 1
          edges: [{
            name: 'c'
            ref:
              id: 3
          }, {
            name: 'b'
            ref:
              id: 2
          }]
      }
      s1.take(1).toPromise()
    .then (val) ->
      b val, {
        user:
          id: 1
          edges: [{
            name: 'c'
            ref:
              id: 3
          }, {
            name: 'b'
            ref:
              id: 2
          }]
      }

  it 'handles deeply nested arrays - non-ref root', ->
    client = createClient()
    streams = {}
    s1 = client.__streamResult {
      ref:
        user:
          id: 2
          arr: ['a']
    }, client.__parseGQL('query {
      ref {
        user {
          id
          arr
          obj { k }
        }
      }
    }').definitions[0], streams

    s1.take(1).toPromise()
    .then ->
      client.__streamResult {
        user:
          id: 2
          arr: []
      }, client.__parseGQL('query {
        user {
          id
          arr
        }
      }').definitions[0], streams
      .take(1).toPromise()
    .then (val) ->
      b val, {
        user:
          id: 2
          arr: []
      }
      s1.take(1).toPromise()
    .then (val) ->
      b val, {
        ref:
          user:
            id: 2
            arr: []
      }

  it 'handles duplicate competing edges', ->
    client = createClient()
    streams = {}
    s1 = client.__streamResult {
      user:
        id: 1
        name: 'a'
        friends:
          edges: [{
            id: 2
            name: 'b'
            node:
              id: 3
              name: 'c'
          }]
    }, client.__parseGQL('query {
      user {
        id
        name
        friends(limit: 1) {
          edges {
            id
            name
            node {
              id
              name
            }
          }
        }
      }
    }').definitions[0], streams

    s1.take(1).toPromise()
    .then (val) ->
      b val, {
        user:
          id: 1
          name: 'a'
          friends:
            edges: [{
              id: 2
              name: 'b'
              node:
                id: 3
                name: 'c'
            }]
      }
      client.__streamResult {
        user:
          id: 1
          name: 'z'
          friends:
            edges: [{
              id: 4
              name: 'x'
              node:
                id: 3
                name: 'y'
            }]
      }, client.__parseGQL('query {
        user {
          id
          name
          friends(limit: 1) {
            edges {
              id
              name
              node {
                id
                name
              }
            }
          }
        }
      }').definitions[0], streams
      .take(1).toPromise()
    .then (val) ->
      b val, {
        user:
          id: 1
          name: 'z'
          friends:
            edges: [{
              id: 4
              name: 'x'
              node:
                id: 3
                name: 'y'
            }]
      }
      s1.take(1).toPromise()
    .then (val) ->
      b val, {
        user:
          id: 1
          name: 'z'
          friends:
            edges: [{
              id: 2
              name: 'b'
              node:
                id: 3
                name: 'y'
            }]
      }

  it 'handles nested non-refs', ->
    client = createClient()
    streams = {}
    s1 = client.__streamResult {
      user:
        id: 1
        sub:
          name: 'a'
    }, client.__parseGQL('query {
      user {
        id
        sub {
          name
        }
      }
    }').definitions[0], streams

    s1.take(1).toPromise()
    .then (val) ->
      b val, {
        user:
          id: 1
          sub:
            name: 'a'
      }
      client.__streamResult {
        user:
          id: 1
          sub:
            name: 'z'
      }, client.__parseGQL('query {
        user {
          id
          sub {
            name
          }
        }
      }').definitions[0], streams
      .take(1).toPromise()
    .then (val) ->
      b val, {
        user:
          id: 1
          sub:
            name: 'z'
      }
      s1.take(1).toPromise()
      .then (val) ->
        b val, {
          user:
            id: 1
            sub:
              name: 'z'
        }

  it 'handles nested non-refs - arrays', ->
    client = createClient()
    streams = {}
    s1 = client.__streamResult {
      user:
        id: 1
        sub:
          names: ['a']
    }, client.__parseGQL('query {
      user {
        id
        sub {
          names
        }
      }
    }').definitions[0], streams

    s1.take(1).toPromise()
    .then (val) ->
      b val, {
        user:
          id: 1
          sub:
            names: ['a']
      }
      client.__streamResult {
        user:
          id: 1
          sub:
            names: ['z']
      }, client.__parseGQL('query {
        user {
          id
          sub {
            names
          }
        }
      }').definitions[0], streams
      .take(1).toPromise()
    .then (val) ->
      b val, {
        user:
          id: 1
          sub:
            names: ['z']
      }
      s1.take(1).toPromise()
      .then (val) ->
        b val, {
          user:
            id: 1
            sub:
              names: ['z']
        }

  it 'handles nested non-refs - empty array', ->
    client = createClient()
    streams = {}
    s1 = client.__streamResult {
      user:
        id: 1
        sub:
          names: ['a']
    }, client.__parseGQL('query {
      user {
        id
        sub {
          names
        }
      }
    }').definitions[0], streams

    s1.take(1).toPromise()
    .then (val) ->
      b val, {
        user:
          id: 1
          sub:
            names: ['a']
      }
      client.__streamResult {
        user:
          id: 1
          sub:
            names: []
      }, client.__parseGQL('query {
        user {
          id
          sub {
            names
          }
        }
      }').definitions[0], streams
      .take(1).toPromise()
    .then (val) ->
      b val, {
        user:
          id: 1
          sub:
            names: []
      }
      s1.take(1).toPromise()
      .then (val) ->
        b val, {
          user:
            id: 1
            sub:
              names: []
        }

  it 'clones object refs so as not to break in crazy ways', ->
    client = createClient()
    streams = {}
    s1 = client.__streamResult {
      user:
        id: 1
        transaction:
          id: 2
          state: 'abc'
          deep:
            id: 3
    }, client.__parseGQL('query {
      user {
        id
        transaction {
          id
          state
          deep {
            id
          }
        }
      }
    }').definitions[0], streams

    vals = []
    s1.subscribe (val) ->
      vals.push val.user.transaction.state

    s1.take(1).toPromise()
    .then (val) ->
      client.__streamResult {
        user:
          id: 2
          state: 'xxx'
      }, client.__parseGQL('query {
        user {
          id
          state
        }
      }').definitions[0], streams
      .take(1).toPromise()
    .then ->
      b vals, ['abc', 'xxx']

  it 'handles root', ->
    client = createClient()
    streams = {}
    s1 = client.__streamResult {
      root:
        user:
          id: 1
          name: 'a'
    }, client.__parseGQL('query {
      root {
        user {
          id
          name
        }
      }
    }').definitions[0], streams

    s1.take(1).toPromise()
    .then (val) ->
      b val, {
        root:
          user:
            id: 1
            name: 'a'
      }
      client.__streamResult {
        root:
          user:
            id: 1
            name: 'z'
      }, client.__parseGQL('query {
        root {
          user {
            id
            name
          }
        }
      }').definitions[0], streams
      .take(1).toPromise()
    .then (val) ->
      b val, {
        root:
          user:
            id: 1
            name: 'z'
      }
      s1.take(1).toPromise()
      .then b val

  it 'production-style refs', ->
    client = createClient()
    streams = {}
    s1 = client.__streamResult {
      root:
        user:
          id: 1
          transactions:
            edges: [
              node:
                id: 2
                name: 'a'
            ]
    }, client.__parseGQL('query {
      root {
        user {
          id
          transactions {
            edges {
              node {
                id
                name
              }
            }
          }
        }
      }
    }').definitions[0], streams

    s1.take(1).toPromise()
    .then (val) ->
      streams[2].next {id: 2, name: 'z'}
      s1.take(1).toPromise()
    .then (val) ->
      b val, {
        root:
          user:
            id: 1
            transactions:
              edges: [
                node:
                  id: 2
                  name: 'z'
              ]
      }

  it 'deep node refs', ->
    client = createClient()
    streams = {}
    s1 = client.__streamResult {
      root:
        user:
          id: 1
          friend:
            id: 2
            name: 'a'
    }, client.__parseGQL('query {
      root {
        user {
          id
          friend {
            id
            name
          }
        }
      }
    }').definitions[0], streams

    s1.take(1).toPromise()
    .then (val) ->
      streams[2].next {id: 2, name: 'z'}
      s1.take(1).toPromise()
    .then (val) ->
      b val, {
        root:
          user:
            id: 1
            friend:
              id: 2
              name: 'z'
      }

  it 'doesnt hang on empty array', ->
    client = createClient()
    client.__streamResult {
      friends:
        edges: []
    }, client.__parseGQL('query {
      friends {
        edges
      }
    }').definitions[0], {}
    .take(1).toPromise()
    .then (val) ->
      b val, {
        friends:
          edges: []
      }

  it 'handles null', ->
    client = createClient()
    streams = {}
    client.__streamResult {user: null}, client.__parseGQL('query {
      user {
        id
      }
    }').definitions[0], streams
    .take(1).toPromise()
    .then (val) ->
      b val, {user: null}

  it 'only streams value/object keys and not function results', ->
    client = createClient()
    streams = {}
    s1 = client.__streamResult {
      user:
        id: 1
        name: 'a'
        arr: [1, 2]
        obj: {k: 'v'}
        arrObj: [{k: 'a'}, {k: 'b'}]
        friendById:
          id: 2
          name: 'x'
    }, client.__parseGQL('query {
      user {
        id
        name
        arr
        obj { k }
        arrObj { k }
        friendById(id: 2) {
          id
          name
        }
      }
    }').definitions[0], streams

    s1.take(1).toPromise()
    .then (val) ->
      b val, {
        user:
          id: 1
          name: 'a'
          arr: [1, 2]
          obj: {k: 'v'}
          arrObj: [{k: 'a'}, {k: 'b'}]
          friendById:
            id: 2
            name: 'x'
      }
      streams[2].next {id: 2, name: 'z'}
      s1.take(1).toPromise()
    .then (val) ->
      b val, {
        user:
          id: 1
          name: 'a'
          arr: [1, 2]
          obj: {k: 'v'}
          arrObj: [{k: 'a'}, {k: 'b'}]
          friendById:
            id: 2
            name: 'z'
      }
      client.__streamResult {
        user:
          id: 1
          friendById:
            id: 3
            name: 'y'
            buddy:
              id: 1
              name: 'b'
              arr: [4, 3, 2, 1]
              obj: {j: 'i'}
              arrObj: [{j: 'a'}]
              friendById:
                id: 4
      }, client.__parseGQL('query {
        user {
          id
          friendById(id: 3) {
            id
            name
            buddy {
              id
              name
              arr
              obj { j }
              arrObj { j }
              friendById(id: 4) {
                id
              }
            }
          }
        }
      }').definitions[0], streams
      .take(1).toPromise()
    .then (val) ->
      b val, {
        user:
          id: 1
          friendById:
            id: 3
            name: 'y'
            buddy:
              id: 1
              name: 'b'
              arr: [4, 3, 2, 1]
              obj: {j: 'i'}
              arrObj: [{j: 'a'}]
              friendById:
                id: 4
      }
      s1.take(1).toPromise()
    .then (val) ->
      b val, {
        user:
          id: 1
          name: 'b'
          arr: [4, 3, 2, 1]
          obj: {k: 'v'}
          arrObj: [{k: 'a'}, {k: 'b'}]
          friendById:
            id: 2
            name: 'z'
      }

  it 'updates from all references', ->
    client = createClient()
    streams = {}
    s1 = client.__streamResult {
      user:
        id: 1
        name: 'a'
        lastName: 'z'
        count: 2
    }, client.__parseGQL('query {
      user {
        id
        name
        lastName
        count
      }
    }').definitions[0], streams

    stack = []
    subscription = s1.subscribe (val) -> stack.push val

    client.__streamResult {
      root:
        a:
          id: 1
          name: 'x'
        b:
          id: 1
          lastName: 'y'
        c: [
          id: 1
          count: 3
        ]
    }, client.__parseGQL('query {
      root {
        a {
          id
          name
        }
        b {
          id
          lastName
        }
        c {
          id
          count
        }
      }
    }').definitions[0], streams
    .take(1).toPromise()
    .then ->
      subscription.unsubscribe()
      b _.last(stack), {
        user:
          id: 1
          name: 'x'
          lastName: 'y'
          count: 3
      }

  it 'merges array values only if AST matches', ->
    client = createClient()
    streams = {}
    s1 = client.__streamResult {
      user:
        id: 1
        arr: [{friendById: {id: 2}}]
    }, client.__parseGQL('query {
      user {
        id
        arr {
          friendById(id: 2) {
            id
          }
        }
      }
    }').definitions[0], streams

    s1.take(1).toPromise()
    .then (val) ->
      client.__streamResult {
        user:
          id: 1
          arr: [{friendById: {id: 3}}]
      }, client.__parseGQL('query {
        user {
          id
          arr {
            friendById(id: 3) {
              id
            }
          }
        }
      }').definitions[0], streams
      .take(1).toPromise()
    .then (val) ->
      b val, {
        user:
          id: 1
          arr: [{friendById: {id: 3}}]
      }
      s1.take(1).toPromise()
    .then (val) ->
      b val, {
        user:
          id: 1
          arr: [{friendById: {id: 2}}]
      }
      s1 = client.__streamResult {
        user:
          id: 1
          arr: [{__typename: 'User', name: 'a'}]
      }, client.__parseGQL('query {
        user {
          id
          arr {
            __typename
            ... on User {
              name
            }
            ... on NonUser {
              name
            }
          }
        }
      }').definitions[0], streams
      s1.take(1).toPromise()
    .then ->
      client.__streamResult {
        user:
          id: 1
          arr: [{__typename: 'NonUser', name: 'b'}]
      }, client.__parseGQL('query {
        user {
          id
          arr {
            __typename
            ... on User {
              name
            }
            ... on NonUser {
              name
            }
          }
        }
      }').definitions[0], streams
      .take(1).toPromise()
    .then ->
      s1.take(1).toPromise()
    .then (val) ->
      b val, {
        user:
          id: 1
          arr: [{__typename: 'NonUser', name: 'b'}]
      }
      client.__streamResult {
        user:
          id: 1
          arr: [{__typename: 'User', name: 'b'}]
      }, client.__parseGQL('query {
        user {
          id
          arr {
            __typename
            name
          }
        }
      }').definitions[0], streams
      .take(1).toPromise()
    .then ->
      s1.take(1).toPromise()
    .then (val) ->
      b val, {
        user:
          id: 1
          arr: [{__typename: 'User', name: 'b'}]
      }
      s1 = client.__streamResult {
        user:
          id: 1
          arr: [{a: null}]
      }, client.__parseGQL('query {
        user {
          id
          arr {
            a {
              b
            }
          }
        }
      }').definitions[0], streams
      s1.take(1).toPromise()
    .then ->
      client.__streamResult {
        user:
          id: 1
          arr: [{a: {b: 'x'}}]
      }, client.__parseGQL('query {
        user {
          id
          arr {
            a {
              b
            }
          }
        }
      }').definitions[0], streams
      .take(1).toPromise()
    .then ->
      s1.take(1).toPromise()
    .then (val) ->
      b val, {
        user:
          id: 1
          arr: [{a: {b: 'x'}}]
      }
      client.__streamResult {
        user:
          id: 1
          arr: [{a: null}]
      }, client.__parseGQL('query {
        user {
          id
          arr {
            a {
              b
            }
          }
        }
      }').definitions[0], streams
      .take(1).toPromise()
    .then ->
      s1.take(1).toPromise()
    .then (val) ->
      b val, {
        user:
          id: 1
          arr: [{a: null}]
      }
      s1 = client.__streamResult {
        user:
          id: 1
          arr: [[1]]
      }, client.__parseGQL('query {
        user {
          id
          arr
        }
      }').definitions[0], streams
      s1.take(1).toPromise()
    .then ->
      client.__streamResult {
        user:
          id: 1
          arr: [[2]]
      }, client.__parseGQL('query {
        user {
          id
          arr
        }
      }').definitions[0], streams
      .take(1).toPromise()
    .then ->
      s1.take(1).toPromise()
    .then (val) ->
      b val, {
        user:
          id: 1
          arr: [[2]]
      }
      s1 = client.__streamResult {
        user:
          id: 1
          arr: [[{name: 'a'}]]
      }, client.__parseGQL('query {
        user {
          id
          arr {
            name
          }
        }
      }').definitions[0], streams
      s1.take(1).toPromise()
    .then ->
      client.__streamResult {
        user:
          id: 1
          arr: [[{x: 'b'}]]
      }, client.__parseGQL('query {
        user {
          id
          arr {
            x
          }
        }
      }').definitions[0], streams
      .take(1).toPromise()
    .then ->
      s1.take(1).toPromise()
    .then (val) ->
      b val, {
        user:
          id: 1
          arr: [[{name: 'a'}]]
      }

  it 'handles empty result', ->
    client = createClient()
    streams = {}
    await client.__streamResult {
      user: [{}]
    }, client.__parseGQL('query {
      user
    }').definitions[0], streams
    .take(1).toPromise()

  it 'throws on mismatched ast', ->
    client = createClient()
    streams = {}
    try
      await client.__streamResult {
        a: 'x'
      }, client.__parseGQL('query {
        user {
          id
        }
      }').definitions[0], streams
      .take(1).toPromise()
      throw new Error 'Expected error'
    catch err
      b err.message, 'No GraphQL AST found for result: {"a":"x"}'

  it 'throws on aliases', ->
    client = createClient()
    streams = {}
    s1 = client.__streamResult {
      user:
        id: 1
    }, client.__parseGQL('query {
      user: viewer {
        id
      }
    }').definitions[0], streams

    s1.take(1).toPromise()
    .then ->
      throw new Error 'expected error'
    , (err) ->
      b err.message, 'No GraphQL AST found for result: {"user":{"id":1}}'

describe 'dealias', ->
  it 'dialiases', ->
    client = createClient()
    result = client.__dealias {
      user:
        id: 1
        fullName: 'a'
    }, client.__parseGQL('query {
      user: viewer {
        id
        fullName: name
      }
    }').definitions[0]
    b result, {
      viewer:
        id: 1
        name: 'a'
    }

  it 'dialiases arrays', ->
    client = createClient()
    result = client.__dealias [{
      user: [
        id: 1
        fullName: 'a'
      ]
    }], client.__parseGQL('query {
      user: viewer {
        id
        fullName: name
      }
    }').definitions[0]
    b result, [{
      viewer: [
        id: 1
        name: 'a'
      ]
    }]

  it 'throws if AST mismatched', ->
    client = createClient()
    try
      client.__dealias {
        user:
          id: 1
          extraField: true
      }, client.__parseGQL('query {
        user: viewer {
          id
        }
      }').definitions[0]
      throw new Error 'Expected error'
    catch err
      b err.message,
        'No GraphQL AST found for result: {"id":1,"extraField":true}'

describe 'realias', ->
  it 'realiases', ->
    client = createClient()
    result = client.__realias {
      viewer:
        id: 1
        name: 'a'
    }, client.__parseGQL('query {
      user: viewer {
        id
        fullName: name
      }
    }').definitions[0]
    b result, {
      user:
        id: 1
        fullName: 'a'
    }

  it 'realiases array', ->
    client = createClient()
    result = client.__realias [{
      viewer: [
        id: 1
        name: 'a'
      ]
    }], client.__parseGQL('query {
      user: viewer {
        id
        fullName: name
      }
    }').definitions[0]
    b result, [{
      user: [
        id: 1
        fullName: 'a'
      ]
    }]

  it 'throws if AST mismatched', ->
    client = createClient()
    try
      client.__realias {
        viewer:
          id: 1
          name: 'a'
      }, client.__parseGQL('query {
        user: viewer {
          id
        }
      }').definitions[0]
      throw new Error 'Expected error'
    catch err
      b err.message,
        'No GraphQL AST found for result: {"id":1,"name":"a"}'

describe 'call', ->
  it 'fetches result, skipping cache', ->
    client = createClient()
    name = nameGen()
    client.call api.CreateUser, {input: {name}}
    .then ({user, callCount}) ->
      b user.name, name
      b callCount, 1
    .then ->
      client.call api.CreateUser, {input: {name}}
    .then ({callCount}) ->
      b callCount, 2
    .then ->
      client.call api.CreateUserFrag, {input: {name}}
    .then ->
      client.cacheStream().take(1).toPromise()
    .then (cache) ->
      b _.isEmpty cache

  it 'handles aliases correctly', ->
    client = createClient()
    name = nameGen()
    {user} = await client.call api.CreateUser, {input: {name}}
    {alias} = await client.call api.UserAlias, {id: user.id}
    b alias?
    b alias.fullName, name
    b alias.friends[0].fullName?

  it 'batches', ->
    client = createClient()
    Promise.all([
      client.call api.CreateUser, {input: {name: nameGen()}}
      client.call api.CreateUser, {input: {name: nameGen()}}
    ]).then ([x, y]) ->
      b x.callCount, 1
      b y.callCount, 1

  it 'has error details', ->
    client = createClient()
    client.call api.Error, {type: 'test'}
    .then (-> throw new Error('Expected Error')), (err) ->
      b err.detail?.type, 'test'

  it 'caches response resources', ->
    client = createClient()
    name = nameGen()
    client.call api.CreateUser, {input: {name}}
    .then ({user}) ->
      b user.name, name
      stream = client.stream api.User, {id: user.id}
      stream.take(1).toPromise()
      .then ({user}) ->
        b user.name, name
        client.call api.UpdateUser, {input: {name: 'jam', id: user.id}}
      .then ({user}) ->
        b user.name, 'jam'
        stream.take(1).toPromise()
      .then ({user}) ->
        b user.name, 'jam'
        client.call api.UpdateUser, {input: {name: 'blam', id: user.id}}
      .then ({user}) ->
        b user.name, 'blam'
        stream.take(1).toPromise()
      .then ({user}) ->
        b user.name, 'blam'

  it 'logs network errors', ->
    callCount = 0
    client = createClient
      onStreamError: -> callCount += 1
    try
      await client.call 'throw'
      throw new Error 'Expected error'
    catch err
      b err.message, 'Test Error'
      b callCount, 1

# TODO: support directives
describe 'query', ->
  it 'streams data, caching queries', ->
    client = createClient()
    name = nameGen()
    client.call api.CreateUser, {input: {name: name}}
    .then ({user}) ->
      client.stream api.User, {id: user.id}
      .take(1).toPromise()
      .then ({user, callCount}) ->
        b user.name, name
        b callCount, 2
      .then ->
        client.stream api.User, {id: user.id}
        .take(1).toPromise()
      .then ({user, callCount}) ->
        b user.name, name
        b callCount, 2
      .then ->
        client.call api.UpdateUser, {input: {id: user.id, name: 'axe'}}
      .then ({callCount}) ->
        b callCount, 3
        client.stream api.User, {id: user.id}
        .take(1).toPromise()
      .then ({user, callCount}) ->
        b user.name, 'axe'
        b callCount <= 3

  # TODO: test function aliases
  # TODO: test id alias
  it 'handles aliases correctly', ->
    client = createClient()
    name = nameGen()
    {user} = await client.call api.CreateUser, {input: {name: name}}
    s1 = client.stream api.User, {id: user.id}

    {user} = await s1.take(1).toPromise()
    b user.name, name
    b user.friends[0].name?

    s2 = client.stream api.UserAlias, {id: user.id}
    {alias} = await s2.take(1).toPromise()
    b not alias.name?
    b alias.fullName, name
    b not alias.friends[0].name?
    b alias.friends[0].fullName?

    await client.call api.UpdateUser, {input: {id: user.id, name: 'xxx'}}

    {user} = await s1.take(1).toPromise()
    b user.name, 'xxx'
    b user.friends[0].name?

    {alias} = await s2.take(1).toPromise()
    b not alias.name?
    b alias.fullName, 'xxx'
    b not alias.friends[0].name?
    b alias.friends[0].fullName?

    await client.call api.UpdateUserAlias, {input: {id: user.id, name: 'yyy'}}

    {user} = await s1.take(1).toPromise()
    b user.name, 'yyy'
    b user.friends[0].name?

    {alias} = await s2.take(1).toPromise()
    b not alias.name?
    b alias.fullName, 'yyy'
    b not alias.friends[0].name?
    b alias.friends[0].fullName?

  it 'handles fragments', ->
    client = createClient()
    name = nameGen()
    {user} = await client.call api.CreateUser, {input: {name: name}}
    s1 = client.stream api.UserFrag, {id: user.id}

    {user} = await s1.take(1).toPromise()
    b user.name, name
    b user.friends[0].name?

    await client.call api.UpdateUser, {input: {id: user.id, name: 'xxx'}}

    {user} = await s1.take(1).toPromise()
    b user.name, 'xxx'
    b user.friends[0].name?

  it 'handles fragment types correctly', ->
    client = createClient()
    s1 = client.stream api.Search

    {search} = await s1.take(1).toPromise()
    b search, [
      {id: -1, name: 'user_name', __typename: 'User'}
      {id: -2, color: 'red', __typename: 'Project'}
    ]

    await client.call api.UpdateUser, {input: {id: -1, name: 'xxx'}}

    {search} = await s1.take(1).toPromise()
    b search, [
      {id: -1, name: 'xxx', __typename: 'User'}
      {id: -2, color: 'red', __typename: 'Project'}
    ]

  it 'batches', ->
    client = createClient()
    Promise.all [
      client.stream(api.User, {id: 1}).take(1).toPromise()
      client.stream(api.User, {id: 2}).take(1).toPromise()
    ]
    .then ([x, y]) ->
      b x.callCount, 1
      b y.callCount, 1

  it 'handles query error passively', ->
    called1 = 0
    called2 = 0

    client = createClient
      onStreamError: (err) ->
        b err.detail.type, 'query1'
        called1 += 1

    client.stream api.Error, {type: 'query1'}
    .take(1).toPromise().then (res) ->
      b called1, 1
      b res, undefined
    .then ->
      client = createClient({
        fetch: -> Promise.reject new Error 'no internet!'
        onStreamError: (err) ->
          b err.message, 'no internet!'
          called2 += 1
      })

      client.stream api.Error, {type: 'query1'}
      .take(1).toPromise().then (res) ->
        b res, undefined
        b called2, 1

  it 'doesn\'t cache errors', ->
    client = createClient({onStreamError: -> null})
    client.stream api.Error, {type: 'xxx'}
    .take(1).toPromise()
    .then (res) ->
      b res, undefined
      client.cacheStream().take(1).toPromise()
      .then (cached) ->
        b _.keys(cached).length, 0

  it 'doesn\'t break streams on error', ->
    retryStream = new Rx.BehaviorSubject 'abc'
    shouldError = true
    client = createClient({
      onStreamError: -> null
      fetch: ->
        new Promise (resolve, reject) ->
          if shouldError
            reject new Error 'no internet!'
          else
            resolve [{data: 'xxx'}]
      })

    queryStream = retryStream.switchMap (accessToken) ->
      client.stream api.User + "\n# #{accessToken}"

    queryStream.take(1).toPromise()
    .then (res) ->
      b res, undefined
      shouldError = false
      retryStream.next null
      queryStream.take(1).toPromise()
    .then (res) ->
      b res, 'xxx'

  it 'throws on missing __typename with fragments', ->
    called = 0
    client = createClient({
      onStreamError: (err) ->
        called += 1
        b err.message, 'Fragment support requires __typename'
    })
    try
      await client.call(api.InvalidUserFrag, {id: 1})
      throw new Error 'Expected error'
    catch err
      b err.message, 'Fragment support requires __typename'

    await client.stream(api.InvalidUserFrag, {id: 1}).take(1).toPromise()
    b called, 1

describe 'invalidateAll', ->
  it 're-requests all active streams', ->
    client = createClient()
    name = nameGen()
    client.call api.CreateUser, {input: {name: name}}
    .then ({user}) ->
      client.stream api.User, {id: user.id}
      .take(1).toPromise()
      .then ({user, callCount}) ->
        b user.name, name
        b callCount, 2
      .then ->
        client.stream api.User, {id: user.id}
        .take(1).toPromise()
      .then ({user, callCount}) ->
        b user.name, name
        b callCount, 2
        client.invalidateAll()
        client.stream api.User, {id: user.id}
        .take(1).toPromise()
      .then ({user, callCount}) ->
        b callCount, 3
