-- Zeta homepage article feed: runs on staged HTML, never on Markdown sources.
local function m(x) return pandoc.utils.stringify(x or '') end
local function read(p) local f=io.open(p,'rb'); if not f then return nil end; local s=f:read('*a');f:close();return s end
local function write(p,s) local f=assert(io.open(p,'wb'));assert(f:write(s));assert(f:close()) end
local function plain(s) return tostring(s or ''):gsub('<[^>]*>','') end
function Pandoc(doc)
 local root=m(doc.meta.zeta_home_output):gsub('\\','/'):gsub('/+$','')
 local mode=m(doc.meta.zeta_home_show)
 local theme=m(doc.meta.zeta_home_theme)
 local blog=m(doc.meta.zeta_home_blog)
 local limit=tonumber(m(doc.meta.zeta_home_limit))
 if root=='' or not limit or limit<1 or limit>30 or limit%1~=0 then error('Invalid homepage feed settings') end
 if mode~='auto' and mode~='true' and mode~='false' then error('homepage.show_posts must be auto, true or false') end
 local home=assert(read(root..'/index.html'),'Missing homepage')
 local marker='<!-- ZETA_HOME_FEED_SLOT -->'
 -- Sites without a Markdown index continue using the normal theme homepage.
 if not home:find(marker,1,true) then return doc end
 local enabled=(mode=='true' or (mode=='auto' and (theme=='paper' or theme=='gazette' or theme=='magazine'))) and blog=='true'
 local section=''
 if enabled then
  local found={}
  local function collect(folder)
   local ok,years=pcall(pandoc.system.list_directory,folder)
   if not ok then return end
   for _,year in ipairs(years) do
    if year:match('^%d%d%d%d$') then
     local ok2,files=pcall(pandoc.system.list_directory,folder..'/'..year)
     if ok2 then for _,name in ipairs(files) do
      if name:match('^[%w%-]+%.html$') then
       local rel='posts/'..year..'/'..name
       local html=read(root..'/'..rel)
       if html then
        local date=html:match('<time[^>]*datetime="(%d%d%d%d%-%d%d%-%d%d)"') or ''
        local title=plain(html:match('<h1[^>]*>(.-)</h1>') or html:match('<title[^>]*>(.-)</title>') or name)
        local desc=html:match('<meta%s+name="description"%s+content="([^"]*)"') or ''
        found[#found+1]={rel=rel,date=date,title=title,desc=desc}
       end
      end
     end end
    end
   end
  end
  collect(root..'/posts')
  table.sort(found,function(a,b) if a.date~=b.date then return a.date>b.date end return a.rel>b.rel end)
  local items={}
  for i=1,math.min(limit,#found) do
   local e=found[i]
   items[#items+1]='<li class="zeta-home-story"><time datetime="'..e.date..'">'..e.date..'</time><h3><a href="'..e.rel..'">'..e.title..'</a></h3><p>'..e.desc..'</p></li>'
  end
  if #items==0 then items[1]='<li class="zeta-home-empty">No articles published yet.</li>' end
  section='<section class="zeta-home-feed" aria-labelledby="zeta-home-latest"><div class="zeta-home-feed-heading"><h2 id="zeta-home-latest">Latest stories</h2><a href="./posts.html">All articles</a></div><ul class="zeta-home-stories">'..table.concat(items,'\n')..'</ul></section>'
 end
 local first,last=home:find(marker,1,true)
 local changed=home:sub(1,first-1)..section..home:sub(last+1)
 write(root..'/index.html',changed)
 io.stderr:write('ZETA_HOME|OK|'..(enabled and 'enabled' or 'disabled')..'\n')
 return doc
end
