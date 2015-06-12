require "glon"

return function(ast)
    return "require('glon') return RunString(glon.decode(\""..glon.encode(ast):gsub('"', '\\"').."\"))"
end