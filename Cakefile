{print} = require 'util'
{exec} = require 'child_process'

task 'build', 'Build lib/ from src/', ->
  coffee = exec "coffee -b -o lib -c src"
  coffee.stderr.on 'data', (data) ->
    process.stderr.write data.toString()
  coffee.stdout.on 'data', (data) ->
    print data.toString()
  coffee.on 'exit', (code) ->
    callback?() if code is 0

task 'watch', 'Watch src/ for changes', ->
  coffee = exec "coffee -b -o lib -cw src"
  coffee.stderr.on 'data', (data) ->
    process.stderr.write data.toString()
  coffee.stdout.on 'data', (data) ->
    print data.toString()

