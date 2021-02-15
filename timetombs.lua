-- timetombs
local MusicUtil = require("musicutil")

local perlin = include('perlin')
local lfo = include("otis/lib/hnds")

local CLOCK_DIVS = {1/32,1/16,1/8,1/4,1/2,1,2,4,8,16,32}
local alt = false
local step = 0
local seq = {}

engine.name = "PolyPerc"

function scale()
  return MusicUtil.generate_scale(24 + params:get("root") % 12, params:string("scale"), 8)
end

function transpose_from_root(amt)
  root_idx = tab.key(scale(), params:get("root"))
  idx = util.clamp(root_idx + amt, 1, #scale())
  return scale()[idx]
end

local function loop()
  while true do
    clock.sync(CLOCK_DIVS[params:get("div")])
    
    step = util.wrap(step + 1, 1, #seq)
    dn = math.floor(params:get("spread") * seq[step])
    n = transpose_from_root(dn)
    engine.hz(MusicUtil.note_num_to_freq(n))

    redraw()
  end
end

function key(n,z)
  if n==1 then alt = z==1 end
end

function enc(n,d)
  if n==2 and alt==false then params:delta("x", d/params:get("x_denom")) end
  if n==2 and alt==true then params:delta("x_denom", d) end
  if n==3 and alt==false then params:delta("y", d/params:get("y_denom")) end
  if n==3 and alt==true then params:delta("y_denom", d) end

  seq = gen_seq()
  redraw()
end

function gen_seq()
  local x_offset = 0
  local y_offset = 0
  
  for i=1,4 do
    if params:get(i.."lfo") == 2 then
      if params:get(i.."lfo_target")==1 then x_offset = x_offset + lfo[i].slope end
      if params:get(i.."lfo_target")==2 then y_offset = y_offset + lfo[i].slope end
    end
  end
  
  local seq = {}
  for x=1, params:get("steps") do
    world_x = params:get("x") + (128*x/params:get("steps")) + 100*x_offset
    world_y = params:get("y") + 100*y_offset
    seq[#seq+1] = perlin:noise(world_x/params:get("x_denom"), world_y/params:get("y_denom"))
  end
  return seq
end

function init()
  params:add{type="number", id="x", default=0}
  params:add{type="number", id="x_denom", min=1, default=100}
  params:add{type="number", id="y", default=0}
  params:add{type="number", id="y_denom", min=1, default=100}
  params:add{type="number", id="steps", min=1, max=32, default=8}

  params:add{
    type="number", id="root",
    min=24, max=128, default=60,
    formatter=function (p)return MusicUtil.note_num_to_name(p:get(), true)end
  }
  params:add{
    type="number", id="scale",
    min=1, max=#MusicUtil.SCALES, default=2,
    formatter=function (p) return MusicUtil.SCALES[p:get()].name end
  }
  params:add{
    type="number", id="spread",
    min=1, max=48, default=24
  }

  params:add{
    type="option", id="div", options=CLOCK_DIVS,
    default=tab.key(CLOCK_DIVS, 1/4)
  }
  
   for i=1,4 do lfo[i].lfo_targets={"x", "y"} end
  lfo.init()

  seq = gen_seq()
  redraw()

  clock.run(loop)
end

function lfo.process()
  -- print(params:get("1lfo"), lfo[1].slope)
  -- for i=1,4 do
  --   if params:get(i.."lfo") == 2 then
  --     if params:get(i.."lfo_target")==1 then params:set("x", 10/params:get("x_denom") * lfo.scale(lfo[i].slope, 0, 0, -1.0, 1.0)) end
  --     if params:get(i.."lfo_target")==2 then params:set("y", 10/params:get("y_denom") * lfo.scale(lfo[i].slope, 0, 0, -1.0, 1.0)) end
  --   end
  -- end
  seq = gen_seq()
  redraw()
end

function redraw ()
  screen.clear()
  offset = -math.floor(128/#seq / 2)
  for x=1, #seq do
    screen.level(x == step and 15 or 1)
    world_x = 128*x/#seq
    v = util.linlin(-1, 1, -32, 32, seq[x])
    screen.move(offset + world_x, 32)
    screen.line_rel(0, -v)
    screen.stroke()
  end
  screen.update()
end
