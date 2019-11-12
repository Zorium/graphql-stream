_ = require 'lodash'
Rx = require 'rxjs/Rx'
URL = require 'url-parse'
gqlParser = require 'graphql/language/parser'

if window?
  # XXX
  SocketIO =
    # istanbul ignore else
    if process.env.MOCK is '1'
      require '../test/mock/socket.io-client'
    else
      require 'socket.io-client'

inlineFragments = (ast, fragments) ->
  _.mapValues ast, (node) ->
    unless node? and _.isObject node
      return node

    if _.isArray node
      return _.map node, (val) -> inlineFragments val, fragments

    if node.kind is 'SelectionSet'
      hasTypename =
        _.find(node.selections, ({name}) -> name?.value is '__typename')?

      _.defaults {
        selections: _.map _.flatten(_.map node.selections, (selection) ->
          fragment = switch selection.kind
            when 'FragmentSpread'
              fragments[selection.name.value]
            when 'InlineFragment'
              selection

          if fragment?
            unless hasTypename
              throw new Error 'Fragment support requires __typename'
            _.map fragment.selectionSet.selections, (selection) ->
              _.defaults {
                __typename: fragment.typeCondition.name.value
              }, selection
          else
            selection
        ), (selection) -> inlineFragments selection, fragments
      }, node
    else
      inlineFragments node, fragments

parseGQL = (gql) ->
  ast = gqlParser.parse(gql, {noLocation: true})
  fragments =
    _.keyBy _.filter(ast.definitions, {kind: 'FragmentDefinition'}), ({name}) ->
      name.value
  inlineFragments ast, fragments

readWriteStreamOf = (observable) ->
  write = new Rx.BehaviorSubject observable
  read = write.switch()
  {write, read}

# https://github.com/darkskyapp/string-hash
hash = (str) ->
  if _.isPlainObject str
    return String hash JSON.stringify str

  h = 5381
  i = str.length
  while i
    i -= 1
    h = (h * 33) ^ str.charCodeAt i
  String h >>> 0

isNode = (x) -> x?.id?

isASTMatch = (obj, ast) ->
  unless _.isObject obj
    return true

  if _.isArray obj
    return _.every obj, (val) -> isASTMatch val, ast

  _.every ast.selectionSet?.selections, (selection) ->
    if selection.arguments.length > 0
      return false

    if selection.__typename? and selection.__typename isnt obj.__typename
      return true

    matchingValue = obj[selection.name.value]

    if matchingValue is null
      return true

    matchingValue? and isASTMatch matchingValue, selection

mergeNode = (obj, src, ast) ->
  for key, srcVal of src
    objVal = obj[key]

    childAst = _.find ast.selectionSet.selections, ({name, __typename}) ->
      if __typename? and __typename isnt obj.__typename
        return false

      name.value is key

    unless childAst?
      continue

    if childAst.arguments.length > 0
      continue

    obj[key] = if _.isArray(objVal) or _.isArray(srcVal)
      if isASTMatch srcVal, childAst
        srcVal
      else
        objVal
    else if _.isObject objVal
      mergeNode objVal, srcVal, childAst
    else
      srcVal

  return obj

dealias = (obj, ast) ->
  unless obj? and _.isObject obj
    return obj

  if _.isArray obj
    return _.map obj, (val) -> dealias val, ast

  _.fromPairs _.map obj, (val, key) ->
    childAst =
      _.find ast.selectionSet.selections, ({name, alias, __typename}) ->
        if __typename? and __typename isnt obj.__typename
          return false
        alias?.value is key or name.value is key

    unless childAst?
      throw new Error "No GraphQL AST found for result: #{JSON.stringify obj}"

    [childAst.name.value, dealias val, childAst]


realias = (obj, ast) ->
  unless obj? and _.isObject obj
    return obj

  if _.isArray obj
    return _.map obj, (val) -> realias val, ast

  _.fromPairs _.map obj, (val, key) ->
    childAst =
      _.find ast.selectionSet.selections, ({name, alias, __typename}) ->
        if __typename? and __typename isnt obj.__typename
          return false

        alias?.value is key or name.value is key

    unless childAst?
      throw new Error "No GraphQL AST found for result: #{JSON.stringify obj}"

    [childAst.alias?.value or childAst.name.value, realias val, childAst]

# XXX
updateNodeStreams = (obj, nodeStreams) ->
  if isNode obj
    node = obj
    if nodeStreams[node.id]?
      # NOTE: conflicting values in the same object
      #  (e.g. due to duplicate reference) is undefined behavior
      nodeStreams[node.id].next node
    else
      nodeStreams[node.id] = new Rx.BehaviorSubject node

  for __, val of obj
    if _.isObject(val)
      updateNodeStreams val, nodeStreams

# TODO: efficiency tests / performance benchmarks
streamResult = (result, ast, nodeStreams, initialize = true) ->
  unless result? and _.isObject result
    return Rx.Observable.of result

  if initialize
    updateNodeStreams result, nodeStreams

  if _.isArray result
    if _.isEmpty result
      return Rx.Observable.of result
    else
      return Rx.Observable.combineLatest _.map result, (val) ->
        streamResult val, ast, nodeStreams, initialize

  (if isNode result
    node = _.cloneDeep result
    # istanbul ignore if
    unless nodeStreams[node.id]?
      throw new Error "Uninitialized node: #{JSON.stringify node.id}"
    nodeStreams[node.id].map (updatedNode) ->
      # XXX: side effect
      mergeNode node, updatedNode, ast
  else
    Rx.Observable.of result)
  .switchMap (result) ->
    childStreams = _.flatten _.map result, (val, key) ->
      keyAst = _.find ast.selectionSet.selections, ({name, __typename}) ->
        if __typename? and __typename isnt result.__typename
          return false
        name.value is key

      unless keyAst?
        return Rx.Observable.throw \
          new Error "No GraphQL AST found for result: #{JSON.stringify result}"

      streamResult val, keyAst, nodeStreams, false
      .map (childResult) -> [key, childResult]
    (if _.isEmpty childStreams
      Rx.Observable.of []
    else
      Rx.Observable.combineLatest childStreams
    ).map (connections) ->
      _.defaults _.fromPairs(connections), result


# TODO: cache memory limit
# TODO: introspect queries to combine them at the field-level
# NOTE: streams cache growth is not bounded - technically memory leak
module.exports = class GraphQLClient
  constructor: ({@api, @fetch, cache, @socketUrl, @onStreamError}) ->
    @initialCache = cache or {}
    @cache = new Rx.BehaviorSubject cache or {}

    # istanbul ignore next
    logger = (err) -> console.error err
    @onStreamError ?= logger

    @queue = []
    @streams = {}
    @nodeStreams = {}
    @socketStreams = {}

    if window?
      @sockets = {}

  cacheStream: => @cache

  # XXX
  __streamResult: streamResult
  __updateNodeStreams: updateNodeStreams
  __dealias: dealias
  __realias: realias
  __parseGQL: parseGQL

  stream: (query, variables) =>
    request = {query, variables}
    key = hash request
    unless @streams[key]?
      deferred = null
      @streams[key] = readWriteStreamOf Rx.Observable.defer =>
        deferred or deferred = if @initialCache[key]?
          ast = _.find parseGQL(request.query).definitions,
            kind: 'OperationDefinition'
          streamResult dealias(@initialCache[key], ast), ast, @nodeStreams
          .map (result) -> realias result, ast
        else
          @_query(request).switch()

      @streams[key].request = request

    return @streams[key].read

  invalidateAll: =>
    _.map @streams, ({request, write}, key) =>
      deferred = null
      write.next Rx.Observable.defer =>
        deferred or deferred = @_query(request).switch()

    null

  _query: (request, shouldError = false) =>
    subject = new Rx.ReplaySubject(1)
    @queue.push {subject, request, shouldError}
    setTimeout =>
      @_consumeQueue()
    return subject

  # NOTE: cache doesn't handle mutations - i.e. it expects static results
  _cache: (requests, results) =>
    if window?
      return

    cache = _.cloneDeep @cache.getValue()

    _.map requests, (request, i) ->
      result = results[i]
      # XXX: use a real parser
      if /(^|\s)mutation /.test(request.query) or result.errors?
        return null
      key = hash request
      cache[key] ?= {}

      _.assign cache[key], result.data

    @cache.next cache

  _consumeQueue: =>
    if _.isEmpty @queue
      return

    queue = @queue
    @queue = []

    @fetch @api,
      method: 'post'
      body: JSON.stringify _.map queue, 'request'
    .then (results) =>
      @_cache _.map(queue, 'request'), results

      _.map results, (result, i) =>
        {subject, request, shouldError} = queue[i]

        if result.errors?
          errorJson = _.first result.errors
          error = new Error errorJson.message
          # NOTE: maintain console.log formatting
          Object.defineProperties error, _.mapValues errorJson, (value) ->
            {value, enumerable: false}
          if shouldError
            subject.error error
          else
            @onStreamError error
            # null breaks function default parameters, e.g. ({x} = {}) -> x
            subject.next Rx.Observable.of undefined
        else
          try
            ast = _.find parseGQL(request.query).definitions,
              kind: 'OperationDefinition'
            subject.next streamResult(
              dealias(result.data, ast), ast, @nodeStreams
            ).map (result) -> realias result, ast
          catch err
            if shouldError
              subject.error err
            else
              @onStreamError err
              # null breaks function default parameters, e.g. ({x} = {}) -> x
              subject.next Rx.Observable.of undefined
    , (err) =>
      @onStreamError err
      _.map queue, ({subject, shouldError}) ->
        if shouldError
          subject.error err
        else
          subject.next Rx.Observable.of undefined
    .catch @onStreamError

  call: (query, variables) =>
    @_query({query, variables}, true).switch().take(1).toPromise()

  # XXX: unsubscribe (maybe - causes staleness unless also invalidating)
  subscribe: (qs, query, variables) =>
    unless @sockets?
      # null breaks function default parameters, e.g. ({x} = {}) -> x
      return Rx.Observable.of undefined

    socketKey = hash qs
    unless @sockets[socketKey]?
      parsedUrl = new URL @socketUrl, null, true
      @sockets[socketKey] = SocketIO parsedUrl.host,
        transports: ['websocket']
        query: qs
        path: parsedUrl.pathname + '/socket.io'
      @sockets[socketKey].on 'graphql', ({sid, data, errors}) =>
        if errors?
          for {message} in errors
            @onStreamError message
          return

        if @socketStreams[sid]?
          updateNodeStreams dealias(data, @socketStreams[sid].ast), @nodeStreams
          @socketStreams[sid].write.next Rx.Observable.of data
        else
          @onStreamError new Error "Missing handler for sid: #{sid}"

    sid = hash {qs, query, variables}
    unless @socketStreams[sid]?
      deferred = null
      @socketStreams[sid] = readWriteStreamOf Rx.Observable.defer =>
        if deferred?
          return deferred
        @sockets[socketKey].emit 'graphql', {sid, qs, query, variables}
        # null breaks function default parameters, e.g. ({x} = {}) -> x
        deferred = new Rx.BehaviorSubject(undefined)
      @socketStreams[sid].ast = _.find parseGQL(query).definitions,
        kind: 'OperationDefinition'

    return @socketStreams[sid].read
