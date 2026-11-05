-- Shared TOC policy; the 'toc' metadata field is reserved by Pandoc.
local always={zen=true,console=true,organization=true,indie=true,services=true,academy=true}
local contextual={aurora=true,paper=true,gazette=true,magazine=true,folio=true,music=true,cuisine=true,spirituality=true,photography=true,store=true}
local function flag(v)
 if v==nil then return nil end
 if type(v)=='boolean' then return v and 'true' or 'false' end
 local s=pandoc.utils.stringify(v):lower():gsub('^%s+',''):gsub('%s+$','')
 if s=='true' or s=='yes' then return 'true' end
 if s=='false' or s=='no' then return 'false' end
 return 'auto'
end
function Pandoc(doc)
 local theme=pandoc.utils.stringify(doc.meta.zeta_toc_theme or ''):lower()
 local kind=pandoc.utils.stringify(doc.meta.zeta_toc_kind or 'post'):lower()
 local requested=flag(doc.meta.toc)
 doc.meta.toc=nil
 local headings,words=0,0
 doc:walk({Header=function(h) if h.level>=2 and h.level<=3 then headings=headings+1 end end,
 Str=function(s) for _ in s.text:gmatch('%S+') do words=words+1 end end})
 local enabled=false
 if kind~='home' and headings>0 then
  if requested=='true' then enabled=true
  elseif requested=='false' then enabled=false
  elseif always[theme] then enabled=true
  elseif contextual[theme] then enabled=headings>=3 and words>=800 end
 end
 doc.meta.zeta_toc_enabled=pandoc.MetaBool(enabled)
 return doc
end
