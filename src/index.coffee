module.exports =
  compare: (a, b) ->
    if false
      console.log 'x'

    if window?
      console.log 'a'
    else
      console.log 'b'

    a is b
