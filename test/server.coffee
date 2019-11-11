b = require 'b-assert'

example = require '../src'

it = if window? then (-> null) else global.it

it 'server compares equals', ->
  if window?
    throw new Error 'This test only runs on the server'
  res = example.compare 'a', 'a'
  b res, true
