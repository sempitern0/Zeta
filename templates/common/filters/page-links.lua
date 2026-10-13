-- Rewrite local Markdown links and refuse executable/unsafe URLs.
local function safe(target, is_image)
  if target:match('^//') or target:match('^\\\\') then return false end
  local scheme = target:match('^([%a][%w+.-]*):')
  if not scheme then return true end
  scheme = scheme:lower()
  return scheme == 'https' or scheme == 'http' or (not is_image and (scheme == 'mailto' or scheme == 'tel'))
end
function Pandoc(doc)
  local depth = tonumber(pandoc.utils.stringify(doc.meta.zeta_page_depth or '0')) or 0
  local prefix = depth == 0 and './' or '../'
  return doc:walk({
    Link = function(el)
      if not safe(el.target,false) then return pandoc.Span(el.content) end
      local slug, fragment = el.target:match('^([a-z0-9%-]+)%.md(#[-%w_]+)$')
      if not slug then slug = el.target:match('^([a-z0-9%-]+)%.md$'); fragment = '' end
      if slug and slug:match('^[a-z0-9]+%-?[a-z0-9%-]*$') then
        el.target = slug == 'index' and (prefix .. 'index.html' .. fragment) or (prefix .. slug .. '/' .. fragment)
      end
      return el
    end,
    Image = function(el)
      if not safe(el.src,true) then return pandoc.Span(el.caption) end
      return el
    end
  })
end
