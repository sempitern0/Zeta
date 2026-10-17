-- Zeta shared taxonomy publisher. Run inside the staging directory before SEO.
local function md(x) return pandoc.utils.stringify(x or '') end
local function read(p) local f=io.open(p,'rb');if not f then return nil end;local s=f:read('*a');f:close();return s end
local function write(p,s) local f=assert(io.open(p,'wb'));assert(f:write(s));assert(f:close()) end
local function escape(s) return tostring(s or ''):gsub('&','&amp;'):gsub('<','&lt;'):gsub('>','&gt;'):gsub('"','&quot;'):gsub("'",'&#39;') end
local function decode(s) return tostring(s or ''):gsub('&quot;','"'):gsub('&#39;',"'"):gsub('&lt;','<'):gsub('&gt;','>'):gsub('&amp;','&') end
local function make_dir(path) pandoc.system.make_directory(path,true) end
-- Taxonomy archives reuse the *built homepage* style pipeline. This keeps all
-- current/future themes and site-local CSS in exactly the original order.
local function taxonomy_head_assets(home,output_root,relative_root)
 local links={}
 local head=home:match('<head[^>]*>(.-)</head>')
 if not head then error('Built homepage has no <head> for taxonomy styles') end
 for tag in head:gmatch('<link%s+[^>]->') do
  if tag:match('rel%s*=%s*"stylesheet"') or tag:match("rel%s*=%s*'stylesheet'") then
   local href=tag:match('href%s*=%s*"([^"]+)"') or tag:match("href%s*=%s*'([^']+)'")
   if href and href:match('^styles/[%w%._%-]+%.css$') then
    if not read(output_root..'/'..href) then error('Missing stylesheet for taxonomy: '..href) end
    links[#links+1]='<link rel="stylesheet" href="'..relative_root..href..'">'
   end
  end
 end
 if #links==0 then error('Built homepage has no local stylesheet links for taxonomy') end
 return table.concat(links,'\n')
end
local function taxonomy_navigation(home,relative_root)
 local menu=home:match('<nav[^>]*aria%-label="Primary navigation"[^>]*>(.-)</nav>')
 if not menu then
  menu='<a href="index.html">Home</a> <a href="posts.html">Blog</a>'
 end
 menu=menu:gsub('%s*aria%-current%s*=%s*"page"','')
 menu=menu:gsub('href="([^"]+)"',function(href)
  if href:match('^%a[%w+.-]*:') or href:sub(1,1)=='/' or href:sub(1,1)=='#' then return 'href="'..href..'"' end
  return 'href="'..relative_root..href:gsub('^%./','')..'"'
 end)
 return menu..' <a href="'..relative_root..'categories/">Categories</a> <a href="'..relative_root..'tags/">Tags</a>'
end
local function html_head(title,description,lang,relative_root,home,output_root,site)
 local styles=taxonomy_head_assets(home,output_root,relative_root)
 local navigation=taxonomy_navigation(home,relative_root)
 return '<!doctype html><html lang="'..escape(lang)..'"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>'..escape(title)..'</title><meta name="description" content="'..escape(description)..'">'..styles..'</head><body class="zeta-static-page zeta-tax-page"><a class="zeta-skip" href="#main">Skip to content</a><header class="zeta-page-header zeta-tax-header"><div class="zeta-page-inner"><a class="zeta-brand" href="'..relative_root..'index.html">'..escape(site)..'</a><nav aria-label="Primary navigation">'..navigation..'</nav></div></header><main id="main" class="zeta-page-inner zeta-tax-wrap">'
end
local function html_foot() return '</main><footer class="zeta-page-footer zeta-tax-footer"><div class="zeta-page-inner">Published with Zeta · Static HTML, no JavaScript</div></footer></body></html>\n' end
local function sort_posts(a,b) if a.title~=b.title then return a.title:lower()<b.title:lower() end;return a.route<b.route end
function Pandoc(doc)
 local root=md(doc.meta.zeta_taxonomy_output):gsub('\\','/'):gsub('/+$','')
 local base=md(doc.meta.zeta_taxonomy_url):gsub('/+$','')
 local site=md(doc.meta.zeta_taxonomy_title)
 local lang=md(doc.meta.zeta_taxonomy_language);if lang=='' then lang='en' end
 if root=='' or site=='' or not base:match('^https?://[^%s]+$') then error('Missing taxonomy parameters') end
 local home_html=read(root..'/index.html')
 if not home_html then error('Built homepage missing before taxonomy generation') end
 local data=read(root..'/.zeta-taxonomy.tsv')
 if not data or data=='' then return doc end
 local terms={category={},tag={}};local posts={};local assignments=0
 for line in data:gmatch('[^\r\n]+') do
  local route,kind,slug,label=line:match('^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)$')
  if not route or not route:match('^posts/%d%d%d%d/[a-z0-9%-]+%.html$') or (kind~='category' and kind~='tag') or not slug:match('^[a-z0-9][a-z0-9%-]*$') or slug:sub(-1)=='-' or label:match('^%s*$') then error('Invalid taxonomy manifest row: '..line) end
  local html=read(root..'/'..route)
  if not html then error('Article missing for taxonomy: '..route) end
  local post=posts[route]
  if not post then
   local name=html:match('<h1[^>]*>(.-)</h1>') or html:match('<title[^>]*>(.-)</title>') or route
   post={route=route,title=decode(name:gsub('<[^>]+>','')),keys={category={},tag={}}}
   posts[route]=post
  end
  local term=terms[kind][slug]
  if term and term.label~=label then error('Different '..kind..' labels use the same URL: '..slug) end
  if not term then term={slug=slug,label=label,posts={}};terms[kind][slug]=term end
  if not post.keys[kind][slug] then
   term.posts[#term.posts+1]=post
   post.keys[kind][slug]=true
   assignments=assignments+1
  end
 end
 local categories,tags={},{}
 for _,t in pairs(terms.category) do categories[#categories+1]=t end
 for _,t in pairs(terms.tag) do tags[#tags+1]=t end
 local function term_sort(a,b) return a.slug<b.slug end
 table.sort(categories,term_sort);table.sort(tags,term_sort)
 local urls={}
 local function archive(items,folder,title)
  if #items==0 then return end
  local directory=root..'/'..folder
  if read(directory..'/index.html') then error('Taxonomy route conflicts with page: '..folder) end
  make_dir(directory)
  local home={html_head(title..' · '..site,'Browse '..title:lower()..' on '..site,lang,'../',home_html,root,site),'<h1>'..escape(title)..'</h1><ul class="zeta-tax-list">'}
  urls[#urls+1]=base..'/'..folder..'/'
  for _,term in ipairs(items) do
   home[#home+1]='<li><a href="'..term.slug..'/">'..escape(term.label)..'</a> <span>('..#term.posts..')</span></li>'
   local path=directory..'/'..term.slug
   if read(path..'/index.html') then error('Taxonomy route conflict: '..folder..'/'..term.slug) end
   make_dir(path)
   table.sort(term.posts,sort_posts)
   local page={html_head(term.label..' · '..title..' · '..site,'Articles on '..term.label,lang,'../../',home_html,root,site),'<nav aria-label="Breadcrumbs"><a href="../">'..escape(title)..'</a> / '..escape(term.label)..'</nav><h1>'..escape(term.label)..'</h1><ul class="zeta-tax-list">'}
   for _,post in ipairs(term.posts) do page[#page+1]='<li><a href="../../'..post.route..'">'..escape(post.title)..'</a></li>' end
   page[#page+1]='</ul>'..html_foot()
   write(path..'/index.html',table.concat(page,'\n'))
   urls[#urls+1]=base..'/'..folder..'/'..term.slug..'/'
  end
  home[#home+1]='</ul>'..html_foot()
  write(directory..'/index.html',table.concat(home,'\n'))
 end
 archive(categories,'categories','Categories')
 archive(tags,'tags','Tags')
 for route,post in pairs(posts) do
  local html=read(root..'/'..route)
  local links={}
  for _,item in ipairs({{kind='category',directory='categories',items=categories},{kind='tag',directory='tags',items=tags}}) do
   for _,term in ipairs(item.items) do
    if post.keys[item.kind][term.slug] then
     links[#links+1]='<a href="../../'..item.directory..'/'..term.slug..'/">'..escape(term.label)..'</a>'
    end
   end
  end
  local related={}
  for otherroute,other in pairs(posts) do
   if otherroute~=route then
    local score=0
    for kind,keys in pairs(post.keys) do for slug in pairs(keys) do if other.keys[kind][slug] then score=score+1 end end end
    if score>0 then related[#related+1]={post=other,score=score} end
   end
  end
  table.sort(related,function(a,b) if a.score~=b.score then return a.score>b.score end;return sort_posts(a.post,b.post) end)
  local section={'<section class="zeta-taxonomy" aria-label="Content discovery">','<h2>Explore this topic</h2><nav class="zeta-tax-chips" aria-label="Categories and tags">',table.concat(links,' '),'</nav>'}
  if #related>0 then
   section[#section+1]='<h3>Related articles</h3><ul>'
   for i=1,math.min(#related,3) do
    local p=related[i].post
    section[#section+1]='<li><a href="../../'..p.route..'">'..escape(p.title)..'</a></li>'
   end
   section[#section+1]='</ul>'
  end
  section[#section+1]='</section>'
  local changed,n=html:gsub('</main>',table.concat(section,'\n')..'\n</main>',1)
  if n~=1 then error('Missing </main> in article '..route) end
  write(root..'/'..route,changed)
 end
 local sitemap=root..'/sitemap.xml'
 local xml=read(sitemap)
 if not xml or not xml:find('</urlset>',1,true) then error('Missing sitemap.xml') end
 table.sort(urls)
 local nodes={}
 for _,target in ipairs(urls) do
  if not xml:find('<loc>'..escape(target)..'</loc>',1,true) then
   nodes[#nodes+1]='  <url><loc>'..escape(target)..'</loc></url>'
  end
 end
 xml=xml:gsub('</urlset>',table.concat(nodes,'\n')..'\n</urlset>',1)
 write(sitemap,xml)
 io.stderr:write('ZETA_TAXONOMY|OK|'..assignments..' assignments; '..(#categories+#tags)..' terms\n')
 return doc
end
