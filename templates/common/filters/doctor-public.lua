-- Zeta Doctor: inspect published HTML and sitemap without modifying files.
-- Input metadata: zeta_doctor_output (directory), zeta_doctor_url (absolute URL).
local output, base, inspected = '', '', {}
local function meta(x) return pandoc.utils.stringify(x or '') end
local function report(level, code, detail)
  detail = tostring(detail or ''):gsub('[\r\n|]', ' ')
  io.stderr:write('ZETA_DOCTOR|'..level..'|'..code..'|'..detail..'\n')
end
local function read(path)
  local f = io.open(path, 'rb')
  if not f then return nil end
  local data = f:read('*a'); f:close(); return data
end
local function xml_unescape(s)
  return s:gsub('&amp;', '&'):gsub('&quot;', '"'):gsub('&apos;', "'"):gsub('&lt;', '<'):gsub('&gt;', '>')
end
local function normpath(path)
  local parts = {}
  for part in path:gsub('\\', '/'):gmatch('[^/]+') do
    if part == '..' then
      if #parts == 0 then return nil end
      parts[#parts] = nil
    elseif part ~= '.' and part ~= '' then parts[#parts+1] = part end
  end
  return table.concat(parts, '/')
end
local function exists_route(rel)
  local path = normpath(rel)
  if not path then return false, 'path escapes public/' end
  if path == '' then path = 'index.html' end
  if read(output..'/'..path) or read(output..'/'..path..'/index.html') then return true end
  return false, path
end
local function url_path(target, source)
  local stripped = target:match('^([^?#]*)') or ''
  if stripped == '' then return nil end
  stripped = stripped:gsub('%%(%x%x)', function(hex)
    local c = string.char(tonumber(hex,16))
    if c:match('[%w%-%._~ ]') then return c end
    return '%'..hex
  end)
  if stripped:match('^//') then return nil, 'protocol-relative URL' end
  local scheme = stripped:match('^([%a][%w+%.%-]*):')
  if scheme then
    scheme = scheme:lower()
    if scheme ~= 'http' and scheme ~= 'https' and scheme ~= 'mailto' and scheme ~= 'tel' and scheme ~= 'data' then
      return nil, 'unsafe URL scheme'
    end
    return nil
  end
  if stripped:sub(1,1) == '/' then return stripped:sub(2) end
  local parent = source:match('^(.*)/[^/]+$') or ''
  return (parent == '' and '' or parent..'/')..stripped
end
local function attributes(html, tag, attribute)
  local values = {}
  for raw in html:gmatch('<'..tag..'%f[%s/>][^>]*>') do
    local value = raw:match(attribute..'%s*=%s*"([^"]*)"') or raw:match(attribute.."%s*=%s*'([^']*)'")
    if value then values[#values+1] = xml_unescape(value) end
  end
  return values
end
local function expected_url(rel)
  if rel == 'index.html' then return base..'/' end
  if rel:match('/index%.html$') then return base..'/'..rel:gsub('index%.html$', '') end
  return base..'/'..rel
end
local function validate_seo(html, rel)
  local head = html:match('^.-</[Hh][Ee][Aa][Dd]>') or html
  local titles = {}
  for title in head:gmatch('<[Tt][Ii][Tt][Ll][Ee][^>]*>(.-)</[Tt][Ii][Tt][Ll][Ee]>') do
    titles[#titles+1] = title
  end
  if #titles ~= 1 or titles[1]:match('^%s*$') then
    report('FAIL', 'HTML_TITLE', rel..': expected exactly one nonempty title')
  end
  local descriptions, canonicals = {}, {}
  for raw in head:gmatch('<[Mm][Ee][Tt][Aa]%f[%s/>][^>]*>') do
    if raw:match('[Nn][Aa][Mm][Ee]%s*=%s*["\']description["\']') then
      descriptions[#descriptions+1] = raw:match('[Cc][Oo][Nn][Tt][Ee][Nn][Tt]%s*=%s*"([^"]*)"') or
        raw:match("[Cc][Oo][Nn][Tt][Ee][Nn][Tt]%s*=%s*'([^']*)'") or ''
    end
  end
  for raw in head:gmatch('<[Ll][Ii][Nn][Kk]%f[%s/>][^>]*>') do
    if raw:match('[Rr][Ee][Ll]%s*=%s*["\']canonical["\']') then
      canonicals[#canonicals+1] = raw:match('[Hh][Rr][Ee][Ff]%s*=%s*"([^"]*)"') or
        raw:match("[Hh][Rr][Ee][Ff]%s*=%s*'([^']*)'") or ''
    end
  end
  if #descriptions == 0 or descriptions[1]:match('^%s*$') then
    report('WARN', 'META_DESCRIPTION', rel..': no description')
  elseif #descriptions > 1 then
    report('FAIL', 'META_DESCRIPTION', rel..': duplicate descriptions')
  end
  if #canonicals == 0 then
    report('WARN', 'CANONICAL', rel..': missing canonical URL')
  elseif #canonicals > 1 then
    report('FAIL', 'CANONICAL', rel..': duplicate canonical URLs')
  elseif xml_unescape(canonicals[1]) ~= expected_url(rel) then
    report('FAIL', 'CANONICAL', rel..': expected '..expected_url(rel)..', found '..canonicals[1])
  end
  if not head:match('<[Hh][Tt][Mm][Ll][^>]*[Ll][Aa][Nn][Gg]%s*=') then
    report('WARN', 'HTML_LANG', rel..': missing HTML language')
  end
end
-- A route can have valid HTML and no CSS at all. Require the common page
-- shell and the active theme contract for every Zeta static page, including
-- nested tag/category archives. No hardcoded theme names or new dependencies.
local function validate_styles(html, rel)
  local taxonomy = rel:match('^tags/.*/index%.html$') or
                   rel:match('^categories/.*/index%.html$')
  local themed = html:match('<[Bb][Oo][Dd][Yy][^>]*[Cc][Ll][Aa][Ss][Ss]%s*=%s*"[^"]*zeta%-static%-page') or
                 html:match("<[Bb][Oo][Dd][Yy][^>]*[Cc][Ll][Aa][Ss][Ss]%s*=%s*'[^']*zeta%-static%-page")
  if not taxonomy and not themed then return end

  local found = {}
  -- Check actual <link rel="stylesheet"> elements, not incidental text.
  for raw in html:gmatch('<[Ll][Ii][Nn][Kk]%f[%s/>][^>]*>') do
    local relationship = raw:match('[Rr][Ee][Ll]%s*=%s*"([^"]*)"') or
                         raw:match("[Rr][Ee][Ll]%s*=%s*'([^']*)'") or ''
    if relationship:lower():match('%f[%a]stylesheet%f[%A]') then
      local href = raw:match('[Hh][Rr][Ee][Ff]%s*=%s*"([^"]+)"') or
                   raw:match("[Hh][Rr][Ee][Ff]%s*=%s*'([^']+)'")
      if href then
        local path = url_path(xml_unescape(href), rel)
        local normalized = path and normpath(path)
        if normalized then found[normalized] = true end
      end
    end
  end
  for _,required in ipairs({'styles/zeta-pages.css', 'styles/00-theme-contract.css'}) do
    if not found[required] then
      report('FAIL', 'THEME_STYLES', rel..': missing stylesheet '..required)
    end
  end
end

local function inspect_html(rel)
  local html = read(output..'/'..rel)
  if not html then return end
  inspected[rel] = true
  validate_seo(html, rel)
  validate_styles(html, rel)
  for _,tag in ipairs({'a','img','link','script','source'}) do
    local attr = (tag == 'a' or tag == 'link') and 'href' or 'src'
    for _,target in ipairs(attributes(html, tag, attr)) do
      local path, problem = url_path(target, rel)
      if problem then
        report('FAIL', 'UNSAFE_URL', rel..': '..target..' ('..problem..')')
      elseif path then
        local ok, missing = exists_route(path)
        if not ok then report('FAIL', 'BROKEN_OUTPUT_LINK', rel..': '..target..' ('..missing..')') end
      end
    end
  end
end
local function scan(rel, depth)
  if depth > 20 then report('FAIL', 'OUTPUT_DEPTH', rel..': excessive nesting'); return end
  local ok, names = pcall(pandoc.system.list_directory, output..(rel == '' and '' or '/'..rel))
  if not ok then report('FAIL', 'OUTPUT_SCAN', 'Cannot list '..rel); return end
  table.sort(names)
  for _,name in ipairs(names) do
    if name ~= '.' and name ~= '..' then
      local path = (rel == '' and '' or rel..'/')..name
      local is_dir = pcall(pandoc.system.list_directory, output..'/'..path)
      if is_dir then scan(path, depth + 1)
      elseif name:lower():match('%.html$') then inspect_html(path) end
    end
  end
end
local function inspect_sitemap()
  local xml = read(output..'/sitemap.xml')
  if not xml then report('FAIL', 'SITEMAP', 'Missing sitemap.xml'); return end
  if not xml:match('</urlset>') then report('FAIL', 'SITEMAP', 'Missing closing urlset tag'); return end
  local urls, count = {}, 0
  for loc in xml:gmatch('<loc>(.-)</loc>') do
    loc = xml_unescape(loc)
    count = count + 1
    if urls[loc] then report('FAIL', 'SITEMAP_DUPLICATE', loc) end
    urls[loc] = true
    if loc:sub(1,#base+1) ~= base..'/' then
      report('FAIL', 'SITEMAP_ORIGIN', loc)
    else
      local ok, missing = exists_route(loc:sub(#base+2))
      if not ok then report('FAIL', 'SITEMAP_MISSING', loc..' ('..missing..')') end
    end
  end
  if count == 0 then report('FAIL', 'SITEMAP', 'No URLs listed') end
  for rel in pairs(inspected) do
    if not urls[expected_url(rel)] then report('WARN', 'SITEMAP_OMISSION', rel..': missing in sitemap') end
  end
end
function Pandoc(doc)
  output = meta(doc.meta.zeta_doctor_output):gsub('\\','/'):gsub('/+$','')
  base = meta(doc.meta.zeta_doctor_url):gsub('/+$','')
  if output == '' or base == '' then
    report('FAIL', 'DOCTOR_SETUP', 'Missing public directory or site URL'); return doc
  end
  if not read(output..'/index.html') then report('FAIL', 'OUTPUT_INDEX', 'Missing index.html'); return doc end
  scan('', 0)
  inspect_sitemap()
  local count = 0
  for _ in pairs(inspected) do count = count + 1 end
  report('OK', 'OUTPUT_CHECKED', tostring(count)..' HTML file(s) inspected')
  return doc
end
