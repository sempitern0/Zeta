-- Shared, read-only Markdown link and image diagnostics for Zeta Doctor.
-- Reports machine-readable stderr; exits successfully if Markdown parses.
local source = ''
local site = ''
local function normal(value)
  return pandoc.utils.stringify(value or '')
end
local function message(level, kind, value)
  value = tostring(value or ''):gsub('[\r\n|]', ' ')
  io.stderr:write('ZETA_DOCTOR|' .. level .. '|' .. kind .. '|' .. value .. '\n')
end
local function dirname(path)
  return (path:gsub('\\','/'):match('^(.*)/[^/]*$') or '.')
end
local function exists(path)
  local f = io.open(path, 'rb')
  if f then f:close(); return true end
  return false
end
local function check_target(target, label, image)
  local cleaned = target:match('^([^?#]*)') or ''
  if cleaned == '' then return end
  if target:match('^//') or target:match('^[%a][%w+%.%-]*:') then
    local protocol = target:match('^([%a][%w+%.%-]*):')
    if target:match('^//') or not (protocol and (protocol:lower() == 'https' or
       protocol:lower() == 'http' or (not image and
       (protocol:lower() == 'mailto' or protocol:lower() == 'tel')))) then
      message('FAIL', 'UNSAFE_URL', label .. ': ' .. target)
    end
    return
  end
  if cleaned:sub(1,1) == '/' then return end
  -- Check source Markdown and referenced local assets. Clean published
  -- URLs like /about/ are checked separately against public/ by Doctor.
  if cleaned:match('%.md$') or image or cleaned:match('%.[A-Za-z0-9]+$') then
    local candidate = dirname(source)..'/'..cleaned
    if not exists(candidate) and not (cleaned:match('^assets/') and exists(site..'/'..cleaned)) then
      message('FAIL', image and 'MISSING_IMAGE' or 'BROKEN_LINK', label .. ': ' .. target)
    end
  end
end
function Pandoc(doc)
  source = normal(doc.meta.zeta_doctor_source)
  site = normal(doc.meta.zeta_doctor_site)
  doc:walk({
    Link = function(el)
      check_target(el.target, 'Link', false)
      return el
    end,
    Image = function(el)
      if normal(el.caption):match('^%s*$') then
        message('WARN', 'IMAGE_ALT', 'Image missing alt text: ' .. el.src)
      end
      check_target(el.src, 'Image', true)
      return el
    end,
  })
  return doc
end
