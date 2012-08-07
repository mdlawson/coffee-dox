
###
Escape the given `html`.

@param {String} html
@return {String}
@api private
###
exports.escape = (html) ->
  String(html).replace(/&(?!\w+;)/g, "&amp;").replace(/</g, "&lt;").replace />/g, "&gt;"