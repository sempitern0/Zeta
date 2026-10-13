-- Flat Markdown page links resolve to pretty generated URLs; opt-in on pages only.
function Link(el)
  local slug, fragment = el.target:match("^([a-z0-9][a-z0-9%-]*)%.md(#[A-Za-z0-9_%-]+)?$")
  if slug then
    if slug == "index" then el.target = "../index.html" .. (fragment or "")
    else el.target = "../" .. slug .. "/" .. (fragment or "") end
  end
  return el
end
