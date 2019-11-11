b = require 'b-assert'

example = require '../src'

it = if window? then global.it else (-> null)

it 'browser compares equals', ->
  unless window?
    throw new Error 'Only works in browsers'
  res = example.compare 'a', 'a'
  b res, true
