-- Zeta shared SEO normalizer; applied only to staged HTML before deployment.
local function m(x) return pandoc.utils.stringify(x or '') end
local function read(p) local f=io.open(p,'rb'); if not f then return nil end; local s=f:read('*a'); f:close(); return s end
local function escape(s) return tostring(s or ''):gsub('&','&amp;'):gsub('"','&quot;'):gsub('<','&lt;'):gsub('>','&gt;') end
local function attr(tag,key) return tag:match(key..'%s*=%s*"([^"]*)"') or tag:match(key.."%s*=%s*'([^']*)'") end
local function valid_image(root,base,value)
 if value:match('^https://[^%s<>"\']+$') then return value end
 if value:match('^assets/[A-Za-z0-9_./%-]+$') and not value:find('..',1,true) and read(root..'/'..value) then
  return base..'/'..value
 end
 return ''
end
local function process(root,base,title,description,global_image,rel)
 local path=root..'/'..rel; local html=read(path)
 if not html then error('Missing staged page '..rel) end
 local head,tail=html:match('^(.-)(</[Hh][Ee][Aa][Dd]>.*)$')
 if not head then error('Missing HTML head in '..rel) end
 local original=head:match('<[Tt][Ii][Tt][Ll][Ee][^>]*>(.-)</[Tt][Ii][Tt][Ll][Ee]>') or title
 local name=original:gsub('<[^>]+>',''):gsub('&amp;','&')
 local desc=''
 local original_image=''
 head=head:gsub('<[Mm][Ee][Tt][Aa]%f[%s/>][^>]*>',function(tag)
  local n=(attr(tag,'[Nn][Aa][Mm][Ee]') or ''):lower()
  local p=(attr(tag,'[Pp][Rr][Oo][Pp][Ee][Rr][Tt][Yy]') or ''):lower()
  if n=='description' then if desc=='' then desc=attr(tag,'[Cc][Oo][Nn][Tt][Ee][Nn][Tt]') or '' end; return '' end
  if p=='og:image' then original_image=attr(tag,'[Cc][Oo][Nn][Tt][Ee][Nn][Tt]') or '' end
  if n:match('^twitter:') or p:match('^og:') or p=='article:published_time' then return '' end
  return tag
 end)
 head=head:gsub('<[Ll][Ii][Nn][Kk]%f[%s/>][^>]*>',function(tag)
  if (attr(tag,'[Rr][Ee][Ll]') or ''):lower()=='canonical' then return '' end
  return tag
 end)
 if desc=='' then desc=escape(description) end
 local url=base..'/'..(rel=='index.html' and '' or rel:gsub('index%.html$',''))
 local kind=rel:match('^posts/%d%d%d%d/.*%.html$') and 'article' or 'website'
 local image=valid_image(root,base,original_image)
 if image=='' then image=valid_image(root,base,global_image) end
 local add={'<link rel="canonical" href="'..escape(url)..'">','<meta name="description" content="'..desc..'">','<meta property="og:type" content="'..kind..'">','<meta property="og:title" content="'..escape(name)..'">','<meta property="og:description" content="'..desc..'">','<meta property="og:url" content="'..escape(url)..'">','<meta property="og:site_name" content="'..escape(title)..'">',('<meta name="twitter:card" content="'..(image~='' and 'summary_large_image' or 'summary')..'">')}
 if image~='' then
  add[#add+1]='<meta property="og:image" content="'..escape(image)..'">'
  add[#add+1]='<meta name="twitter:image" content="'..escape(image)..'">'
 end
 if kind=='article' then
  local published=tail:match('<[Tt][Ii][Mm][Ee][^>]*[Dd][Aa][Tt][Ee][Tt][Ii][Mm][Ee]%s*=%s*"(%d%d%d%d%-%d%d%-%d%d)"')
  if published then add[#add+1]='<meta property="article:published_time" content="'..published..'">' end
 end
 local new=head..'\n'..table.concat(add,'\n')..'\n'..tail
 local f=assert(io.open(path,'wb')); assert(f:write(new)); assert(f:close())
end
function Pandoc(doc)
 local root=m(doc.meta.zeta_seo_output):gsub('\\','/'):gsub('/+$','')
 local base=m(doc.meta.zeta_seo_url):gsub('/+$','')
 local title=m(doc.meta.zeta_seo_title)
 local description=m(doc.meta.zeta_seo_description)
 local global_image=m(doc.meta.zeta_seo_image)
 if root=='' or title=='' or not base:match('^https?://') then error('Missing SEO parameters') end
 local count=0
 local function scan(rel)
  local dir=root..(rel=='' and '' or '/'..rel)
  for _,name in ipairs(pandoc.system.list_directory(dir)) do
   if name~='.' and name~='..' then
    local path=rel=='' and name or rel..'/'..name
    if pcall(pandoc.system.list_directory,root..'/'..path) then scan(path)
    elseif name:lower():match('%.html$') then process(root,base,title,description,global_image,path);count=count+1 end
   end
  end
 end
 scan('')
 if count==0 then error('No staged HTML found') end
 io.stderr:write('ZETA_SEO|OK|'..count..' HTML pages normalized\n')
 return doc
end
