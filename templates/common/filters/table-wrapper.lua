-- Preserve semantic <table> output while giving CSS a responsive scroll box.
-- This uses Pandoc's built-in Lua runtime and adds no external dependency.

function Table(el)
  return pandoc.Div({el}, pandoc.Attr("", {"table-scroll"}))
end
