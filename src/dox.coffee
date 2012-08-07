# Module dependencies. 
markdown = require("github-flavored-markdown").parse
escape = require("./utils").escape

#Library version.
exports.version = "0.3.1"


# Parse comments in the given string of `coffee`.
#
# @param {String} coffee
# @param {Object} options
# @return {Array}
# @see exports.parseComment
# @api public
exports.parseComments = (coffee, options) ->
  options = options or {}
  coffee = coffee.replace(/\r\n/g, "\n")
  comments = []
  raw = options.raw
  comment = undefined
  buf = ""
  ignore = undefined
  withinMultiline = false
  withinSingle = false
  prevIndent = 0
  indent = 0
  code = undefined
  i = 0
  len = coffee.length

  while i < len
    
    # handle indents
    if coffee[i - 1] is "\n"
      j = i
      indent = 0
      while coffee[j] is " " or coffee[j] is "\t"
        indent++
        j++

    # start comment
    if not withinMultiline and not withinSingle and "#" is coffee[i]
      withinSingle = true
      buf += coffee[i]
      #ignore = "!" is coffee[i]
    
    # end comment
    else if withinMultiline and not withinSingle and "\n" is coffee[i] and "#" isnt coffee[i + 1 + indent]
      buf = buf.replace(/^ *# ?/gm, "")
      comment = exports.parseComment(buf, options)
      comment.ignore = ignore
      comments.push comment
      withinMultiline = ignore = false
      buf = ""
      
    # upgrade single to multiline
    else if withinSingle and not withinMultiline and "\n" is coffee[i] and "#" is coffee[i + 1 + indent]
      i++
      # code following previous comment
      if buf.trim().length
        comment = comments[comments.length - 1]
        if comment
          comment.code = code = buf.trim()
          comment.ctx = exports.parseCodeContext(code)
        buf = ""
      withinSingle = false
      withinMultiline = true
    
    # end single
    else if withinSingle and not withinMultiline and "\n" is coffee[i]
      withinSingle = false
      buf += coffee[i]
    
    # buffer comment or code
    else
      buf += coffee[i]

    ++i
  if comments.length is 0
    comments.push
      tags: []
      description:
        full: ""
        summary: ""
        body: ""

      isPrivate: false

  
  # trailing code
  if buf.trim().length
    comment = comments[comments.length - 1]
    code = buf.trim()
    comment.code = code
    comment.ctx = exports.parseCodeContext(code)
  comments



# Parse the given comment `str`.
#
# The comment object returned contains the following
#
# - `tags`  array of tag objects
# - `description` the first line of the comment
# - `body` lines following the description
# - `content` both the description and the body
# - `isPrivate` true when "@api private" is used
#
# @param {String} str
# @param {Object} options
# @return {Object}
# @see exports.parseTag
# @api public
exports.parseComment = (str, options) ->
  str = str.trim()
  options = options or {}
  comment = tags: []
  raw = options.raw
  description = {}
  
  # parse comment body
  # A more detailed insight into this bit of code
  # @param {DICKS} SICK
  description.full = str.split("\n@")[0].replace(/^([A-Z][\w ]+):$/g, "## $1")
  description.summary = description.full.split("\n\n")[0]
  description.body = description.full.split("\n\n").slice(1).join("\n\n")
  comment.description = description
  
  # parse tags
  if ~str.indexOf("\n@")
    tags = "@" + str.split("\n@").slice(1).join("\n@")
    comment.tags = tags.split("\n").map(exports.parseTag)
    comment.isPrivate = comment.tags.some((tag) ->
      "api" is tag.type and "private" is tag.visibility
    )
  
  # markdown
  unless raw
    description.full = markdown(description.full)
    description.summary = markdown(description.summary)
    description.body = markdown(description.body)
  comment



# Parse tag string "@param {Array} name description" etc.
#
# @param {String}
# @return {Object}
# @api public
exports.parseTag = (str) ->
  tag = {}
  parts = str.split(RegExp(" +"))
  type = tag.type = parts.shift().replace("@", "")
  switch type
    when "param"
      tag.types = exports.parseTagTypes(parts.shift())
      tag.name = parts.shift() or ""
      tag.description = parts.join(" ")
    when "return"
      tag.types = exports.parseTagTypes(parts.shift())
      tag.description = parts.join(" ")
    when "see"
      if ~str.indexOf("http")
        tag.title = (if parts.length > 1 then parts.shift() else "")
        tag.url = parts.join(" ")
      else
        tag.local = parts.join(" ")
    when "api"
      tag.visibility = parts.shift()
    when "type"
      tag.types = exports.parseTagTypes(parts.shift())
    when "memberOf"
      tag.parent = parts.shift()
    when "augments"
      tag.otherClass = parts.shift()
    when "borrows"
      tag.otherMemberName = parts.join(" ").split(" as ")[0]
      tag.thisMemberName = parts.join(" ").split(" as ")[1]
    else
      tag.string = parts.join(" ")
  tag



# Parse tag type string "{Array|Object}" etc.
#
# @param {String} str
# @return {Array}
# @api public
exports.parseTagTypes = (str) ->
  str.replace(/[{}]/g, "").split RegExp(" *[|,\\/] *")



# Parse the context from the given `str` of coffee.
#
# This method attempts to discover the context
# for the comment based on it's code. Currently
# supports:
#
# - function statements
# - function expressions
# - prototype methods
# - prototype properties
# - methods
# - properties
# - declarations
#
# @param {String} str
# @return {Object}
# @api public

exports.parseCodeContext = (str) ->
  str = str.split("\n")[0]

  # function expression
  if /^(\w+) *= *(\(.*\)|) *->/.exec(str)
    type: "function"
    name: RegExp.$1
    string: RegExp.$1 + "()"
  
  # prototype method
  else if /^(\w+)::(\w+) *= *(\(.*\)|) *->/.exec(str)
    type: "method"
    constructor: RegExp.$1
    name: RegExp.$2
    string: RegExp.$1 + ".prototype." + RegExp.$2 + "()"
  
  # prototype property
  else if /(\w+)::(\w+) *= *([^\n;]+)/.exec(str)
    type: "property"
    constructor: RegExp.$1
    name: RegExp.$2
    value: RegExp.$3
    string: RegExp.$1 + ".prototype" + RegExp.$2
  
  # method
  else if /^(@|\w+.\.)*(\w+) *= *(\(.*\)|) *->/.exec(str)
    type: "method"
    receiver: RegExp.$1
    name: RegExp.$2
    string: RegExp.$1 + "." + RegExp.$2 + "()"
  
  # property
  else if /^(@|\w+.\.)*(\w+) *= *([^\n;]+)/.exec(str)
    type: "property"
    receiver: RegExp.$1
    name: RegExp.$2
    value: RegExp.$3
    string: RegExp.$1 + "." + RegExp.$2
  
  # declaration
  else if /^(\w+) *= *([^\n;]+)/.exec(str)
    type: "declaration"
    name: RegExp.$1
    value: RegExp.$2
    string: RegExp.$1
