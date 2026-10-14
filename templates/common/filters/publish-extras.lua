-- Zeta: shared staged output processor (no browser JavaScript).
local function m(v) return pandoc.utils.stringify(v or '') end
local function read(p) local f=io.open(p,'rb'); if not f then return nil end; local s=f:read('*a'); f:close(); return s end
local function write(p,s) local f=assert(io.open(p,'wb')); assert(f:write(s)); assert(f:close()) end
local function entities(s) return tostring(s or ''):gsub('&quot;','"'):gsub('&#39;',"'"):gsub('&apos;',"'"):gsub('&lt;','<'):gsub('&gt;','>'):gsub('&amp;','&') end
local function esc(s) return tostring(s or ''):gsub('&','&amp;'):gsub('<','&lt;'):gsub('>','&gt;'):gsub('"','&quot;'):gsub("'",'&apos;') end
local function json(s) return pandoc.json.encode(s):gsub('<','\\u003c'):gsub('>','\\u003e'):gsub('&','\\u0026') end
local function valid(s)
 local y,mo,d=tostring(s or ''):match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
 if not y then return false end
 y,mo,d=tonumber(y),tonumber(mo),tonumber(d)
 if mo<1 or mo>12 or d<1 then return false end
 local last=({31,28,31,30,31,30,31,31,30,31,30,31})[mo]
 if mo==2 and (y%400==0 or (y%4==0 and y%100~=0)) then last=29 end
 return d<=last
end
local function url(base,rel)
 if rel=='index.html' then return base..'/' end
 if rel:match('/index%.html$') then return base..'/'..rel:gsub('index%.html$','') end
 return base..'/'..rel
end
local function meta(html,key,value)
 for tag in html:gmatch('<meta%s+[^>]+>') do
  if tag:find(key..'="'..value..'"',1,true) then return entities(tag:match('content="([^"]*)"') or '') end
 end
 return ''
end
local function details(html,rel,base)
 local title=entities((html:match('<title[^>]*>(.-)</title>') or ''):gsub('<[^>]*>',''))
 local desc=meta(html,'name','description')
 local published=html:match('<time[^>]*datetime="(%d%d%d%d%-%d%d%-%d%d)"') or meta(html,'property','article:published_time')
 if not valid(published) then published=nil end
 return {title=title,description=desc,published=published,url=url(base,rel)}
end
local function rfc822(date)
 if not valid(date) then return nil end
 local y,mo,d=date:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
 local stamp=os.time({year=tonumber(y),month=tonumber(mo),day=tonumber(d),hour=12,min=0,sec=0})
 local weekday=({'Sun','Mon','Tue','Wed','Thu','Fri','Sat'})[tonumber(os.date('%w',stamp))+1]
 local month=({'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'})[tonumber(mo)]
 return weekday..', '..d..' '..month..' '..y..' 00:00:00 GMT'
end
function Pandoc(doc)
 local root=m(doc.meta.zeta_extra_output):gsub('\\','/'):gsub('/+$','')
 local base=m(doc.meta.zeta_extra_url):gsub('/+$','')
 local title=m(doc.meta.zeta_extra_title)
 local description=m(doc.meta.zeta_extra_description)
 local author=m(doc.meta.zeta_extra_author)
 local language=m(doc.meta.zeta_extra_language)
 local blog=m(doc.meta.zeta_extra_blog)=='true'
 if root=='' or title=='' or not base:match('^https?://') then error('Invalid publish metadata') end
 if language=='' then language='en' end
 local updates={}
 local changes=read(root..'/.zeta-updates.tsv')
 if changes then
  for rel,date in changes:gmatch('([^\t\r\n]+)\t([^\r\n]+)') do
   if not valid(date) then error('Invalid explicit updated date for '..rel..': '..date) end
   if not rel:match('^[a-z0-9_/%-]+%.html$') or rel:find('..',1,true) then error('Invalid update route '..rel) end
   updates[url(base,rel)]=date
  end
 end
 local entries={}
 local count=0
 local function scan(dir,depth)
  if depth>18 then error('Site nesting exceeds 18 directories') end
  local names=pandoc.system.list_directory(root..(dir=='' and '' or '/'..dir))
  table.sort(names)
  for _,name in ipairs(names) do
   if name~='.' and name~='..' then
    local rel=dir=='' and name or dir..'/'..name
    if pcall(pandoc.system.list_directory,root..'/'..rel) then scan(rel,depth+1)
    elseif name:match('%.html$') then
     local file=root..'/'..rel
     local html=assert(read(file),'HTML missing '..rel)
     local page=details(html,rel,base)
     local kind=rel:match('^posts/%d%d%d%d/.+%.html$') and 'BlogPosting' or (rel=='index.html' and 'WebSite' or 'WebPage')
     local schema={['@context']='https://schema.org',['@type']=kind,name=page.title~='' and page.title or title,url=page.url,description=page.description~='' and page.description or description,inLanguage=language}
     if kind=='BlogPosting' then
      schema.headline=schema.name
      schema.mainEntityOfPage=page.url
      if page.published then schema.datePublished=page.published end
      if author~='' then schema.author={['@type']='Person',name=author} end
      if updates[page.url] then schema.dateModified=updates[page.url] end
      entries[#entries+1]=page
     end
     html=html:gsub('<script%s+type="application/ld%+json"%s+data%-zeta="true">.-</script>%s*','')
     html=html:gsub('<link%s+rel="alternate"%s+data%-zeta%-feed="[^"]+"[^>]+>%s*','')
     local tags={'<script type="application/ld+json" data-zeta="true">'..json(schema)..'</script>'}
     if blog then
      tags[#tags+1]='<link rel="alternate" data-zeta-feed="rss" type="application/rss+xml" title="'..esc(title)..' RSS" href="'..esc(base..'/rss.xml')..'">'
      tags[#tags+1]='<link rel="alternate" data-zeta-feed="atom" type="application/atom+xml" title="'..esc(title)..' Atom" href="'..esc(base..'/atom.xml')..'">'
     end
     local changed,n=html:gsub('</head>',table.concat(tags,'\n')..'\n</head>',1)
     if n~=1 then error('Missing </head> in '..rel) end
     write(file,changed)
     count=count+1
    end
   end
  end
 end
 scan('',0)
 if count==0 then error('No HTML pages to publish') end
 local sitemap=root..'/sitemap.xml'
 local xml=assert(read(sitemap),'Missing sitemap.xml')
 xml=xml:gsub('<url>(.-)</url>',function(block)
  local loc=entities(block:match('<loc>(.-)</loc>') or '')
  block=block:gsub('%s*<lastmod>.-</lastmod>','')
  if updates[loc] then block=block:gsub('</loc>','</loc><lastmod>'..updates[loc]..'</lastmod>',1) end
  return '<url>'..block..'</url>'
 end)
 write(sitemap,xml)
 if blog then
  table.sort(entries,function(a,b)
   if (a.published or '')~=(b.published or '') then return (a.published or '')>(b.published or '') end
   return a.url<b.url
  end)
  local now=os.date('!%Y-%m-%dT%H:%M:%SZ')
  local rss={'<?xml version="1.0" encoding="UTF-8"?>','<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom"><channel>','<title>'..esc(title)..'</title>','<link>'..esc(base..'/')..'</link>','<description>'..esc(description)..'</description>','<language>'..esc(language)..'</language>','<atom:link href="'..esc(base..'/rss.xml')..'" rel="self" type="application/rss+xml"/>'}
  local atom={'<?xml version="1.0" encoding="UTF-8"?>','<feed xmlns="http://www.w3.org/2005/Atom">','<title>'..esc(title)..'</title>','<id>'..esc(base..'/')..'</id>','<link href="'..esc(base..'/atom.xml')..'" rel="self"/>','<link href="'..esc(base..'/')..'"/>','<updated>'..now..'</updated>'}
  for _,e in ipairs(entries) do
   rss[#rss+1]='<item><title>'..esc(e.title)..'</title><link>'..esc(e.url)..'</link><guid isPermaLink="true">'..esc(e.url)..'</guid><description>'..esc(e.description)..'</description>'
   if e.published then rss[#rss+1]='<pubDate>'..rfc822(e.published)..'</pubDate>' end
   rss[#rss+1]='</item>'
   atom[#atom+1]='<entry><title>'..esc(e.title)..'</title><id>'..esc(e.url)..'</id><link href="'..esc(e.url)..'"/><summary>'..esc(e.description)..'</summary><updated>'..(updates[e.url] or (e.published and e.published..'T00:00:00Z') or now)..'</updated>'
   if author~='' then atom[#atom+1]='<author><name>'..esc(author)..'</name></author>' end
   atom[#atom+1]='</entry>'
  end
  rss[#rss+1]='</channel></rss>'
  atom[#atom+1]='</feed>'
  write(root..'/rss.xml',table.concat(rss,'\n')..'\n')
  write(root..'/atom.xml',table.concat(atom,'\n')..'\n')
 end
 io.stderr:write('ZETA_PUBLISH|OK|'..count..' pages; '..#entries..' feed entries\n')
 return doc
end
