-- Page-relative Markdown links to clean static URLs.
function Pandoc(doc)
  local depth = tonumber(pandoc.utils.stringify(doc.meta.zeta_page_depth or '0')) or 0
  local prefix = depth == 0 and './' or '../'
  return doc:walk({Link = function(el)
    local slug, fragment = el.target:match('^([a-z0-9%-]+)%.md(#[-%w_]+)$')
    if not slug then slug = el.target:match('^([a-z0-9%-]+)%.md$'); fragment = '' end
    if slug and slug:match('^[a-z0-9]+%-?[a-z0-9%-]*$') then
      el.target = slug == 'index' and (prefix .. 'index.html' .. fragment) or (prefix .. slug .. '/' .. fragment)
    end
    return el
  end})
end
