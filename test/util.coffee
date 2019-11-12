_ = require 'lodash'
b = require 'b-assert'

GraphQLClient = require '../src'

api =
  CreateUser: 'mutation CreateUser($user: UserInput!) {
    callCount
    user: createUser(input: $user) {
      id
      name
    }
  }'
  CreateUserFrag: '
    fragment X on User {
      name
    }
    mutation CreateUserFrag($user: UserInput!) {
      callCount
      user: createUser(input: $user) {
        __typename
        id
        ...X
      }
    }
  '
  UpdateUser: 'mutation UpdateUser($user: UserInput!) {
    callCount
    user: updateUser(input: $user) {
      id
      name
    }
  }'
  UpdateUserAlias: 'mutation UpdateUserAlias($user: UserInput!) {
    callCount
    alias: updateUser(input: $user) {
      id
      fullName: name
    }
  }'
  User: 'query User($id: String!) {
    callCount
    user: user(id: $id) {
      id
      name
      friends {
        id
        name
      }
    }
  }'
  UserAlias: 'query UserAlias($id: String!) {
    callCount
    alias: user(id: $id) {
      id
      fullName: name
      friends {
        id
        fullName: name
      }
    }
  }'
  UserFrag: '
    fragment X on User {
      friends {
        id
        name
      }
    }
    query UserFrag($id: String!) {
      callCount
      user: user(id: $id) {
        __typename
        id
        ... on User {
          name
        }
        ...X
      }
    }
  '
  InvalidUserFrag: '
    query InvalidUserFrag($id: String!) {
      callCount
      user: user(id: $id) {
        id
        ... on User {
          name
        }
        ...X
      }
    }
  '
  subscribe: '
    fragment X on User {
      friends {
        id
        name
      }
    }
    subscription {
      viewer {
        event
        node {
          __typename
          id
          ... on User {
            name
          }
          ...X
        }
      }
    }
  '
  Search: 'query Search {
    callCount
    search {
      __typename
      id
      ... on User {
        name
      }
      ... on Project {
        color
      }
    }
  }'
  Error: 'query Error($input: String!) {error}'

nameGen = do ->
  cnt = 0
  ->
    cnt += 1
    "test_name_#{cnt}"

idGen = do ->
  cnt = 0
  ->
    cnt += 1
    "test_id_#{cnt}"

createClient = ({cache, onStreamError, fetch} = {}) ->
  db = {}
  callCount = 0
  new GraphQLClient ({
    api: 'x'
    cache
    onStreamError
    fetch: fetch or (url, opts) ->
      # XXX: https://github.com/jashkenas/coffeescript/issues/5128
      opts ?= {}
      callCount += 1
      b url, 'x'
      body = JSON.parse opts.body or '{}'
      new Promise (resolve) ->
        resolve _.map body, ({query, variables}) ->
          obj = switch
            when /mutation CreateUser\W/.test query
              id = idGen()
              db[id] = _.defaults {id}, variables.input
              {user: db[id]}
            when /mutation CreateUserFrag\W/.test query
              id = idGen()
              db[id] = _.defaults {id}, variables.input
              {user: _.defaults {__typename: 'User'}, db[id]}
            when /mutation UpdateUser\W/.test query
              id = variables.id
              db[id] = _.assign db[id], variables.input
              {user: db[id]}
            when /mutation UpdateUserAlias\W/.test query
              id = variables.id
              db[id] = _.assign db[id], variables.input
              {alias: _.defaults {
                fullName: db[id].name
              }, db[id]}
            when /query User\W/.test query
              id = variables.id
              {user: _.defaults {friends: [{id: 9999, name: 'friend'}]}, db[id]}
            when /query UserAlias\W/.test query
              id = variables.id
              {alias: _.defaults {
                fullName: db[id].name
                friends: [{id: 9999, fullName: 'friend'}]
              }, db[id]}
            when /query UserFrag\W/.test query
              id = variables.id
              {user: _.defaults {
                __typename: 'User'
                friends: [{id: 9999, name: 'friend'}]
              }, db[id]}
            when /query InvalidUserFrag\W/.test query
              id = variables.id
              {user: db[id]}
            when /query Search\W/.test query
              {search: [
                _.assign {id: -1, name: 'user_name', __typename: 'User'}, db[-1]
                {id: -2, color: 'red', __typename: 'Project'}
              ]}
            when /query Error\W/.test query
              {errors: [{message: 'TEST', detail: {type: variables.type}}]}
            when /^throw$/.test query
              throw new Error 'Test Error'
            else
              console.log query
              throw new Error 'Unknown query'
          if obj.errors?
            return obj
          {data: _.defaults {callCount}, obj}
  })

module.exports = {api, nameGen, idGen, createClient}
