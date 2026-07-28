-- Wrap the first occurrence (per chapter) of each glossary term in a hover
-- tooltip (native HTML `title`). Skips code, headings, links, and the glossary's
-- own definition list. Terms and definitions mirror the Glossary chapter.

-- Each entry: variants (matched, case-insensitive, whole-word) share one key so
-- only the first variant seen in a document is tagged.
local ENTRIES = {
  {key="login-node",  variants={"login nodes","login node"},
   def="A shared front-end machine (mblog1/mblog2) for editing and submitting jobs — not for heavy computing."},
  {key="compute-node", variants={"compute nodes","compute node"},
   def="A machine where jobs actually run, allocated to you by Slurm for a bounded time."},
  {key="batch-job",   variants={"batch jobs","batch job"},
   def="A job submitted as a script with sbatch that runs unattended when scheduled."},
  {key="job-array",   variants={"job arrays","job array","array job"},
   def="One script run many times with a varying index ($SLURM_ARRAY_TASK_ID), for parameter sweeps and ensembles."},
  {key="fairshare",   variants={"fair-share","fairshare"},
   def="A priority factor: heavy recent usage by your account temporarily lowers your priority."},
  {key="backfill",    variants={"backfill"},
   def="Slurm slotting a small, short job into a schedule gap without delaying higher-priority jobs."},
  {key="checkpoint",  variants={"checkpointing","checkpoint"},
   def="A periodic save of a job's state so it can resume instead of restart after a failure or preemption."},
  {key="condo",       variants={"condo model","condo"},
   def="Research groups buy nodes (inv-*); others borrow them when idle, subject to reclaim/preemption."},
  {key="investor",    variants={"investors","investor","inv-*"},
   def="A research group, department, or PI that bought cluster nodes with their own funds. They get top priority on those inv-* partitions; jobs others backfill there can be preempted."},
  {key="core-hour",   variants={"core-hours","core-hour"},
   def="One CPU core used for one hour — the unit your allocation is measured in."},
  {key="partition",   variants={"partitions","partition"},
   def="A named pool of nodes with particular hardware (mb, mb-h100, teton, ...), chosen with --partition."},
  {key="preemption",  variants={"preemption","preempted","preempt"},
   def="When an investor reclaims a node you'd borrowed while idle, Slurm stops your job; on MedicineBow it is then requeued (put back in the queue to start over)."},
  {key="qos",         variants={"QOS"},
   def="Quality of Service: the tier setting your max walltime, resource cap, and priority."},
  {key="requeue",     variants={"requeue","requeued"},
   def="Putting a killed (preempted or failed) job back in the pending queue to start over."},
  {key="scratch",     variants={"scratch"},
   def="Fast, large, temporary storage (/gscratch) purged after 90 days of inactivity. Not backed up."},
  {key="snapshot",    variants={"snapshots","snapshot"},
   def="A point-in-time filesystem copy on the same array as live data — guards against deletion, not hardware loss. Not a backup."},
  {key="walltime",    variants={"walltime"},
   def="The real elapsed clock time a job is allowed (--time); the job is killed at the limit."},
  {key="slurm",       variants={"Slurm"},
   def="The scheduler that manages all jobs on the cluster."},
  {key="mpi",         variants={"MPI"},
   def="Message Passing Interface — a single parallel program spanning many cores/nodes that communicate; launched with srun."},
  {key="gres",        variants={"GRES"},
   def="Generic RESource — how you request GPUs, e.g. --gres=gpu:1."},
  {key="ondemand",    variants={"Open OnDemand","OnDemand"},
   def="The web portal at medicinebow.arcc.uwyo.edu — file browser, terminal, and interactive apps."},
  {key="medicinebow", variants={"MedicineBow"},
   def="UW/ARCC's flagship HPC cluster — the subject of this book."},
  {key="arcc",        variants={"ARCC"},
   def="Advanced Research Computing Center — the UW group that runs MedicineBow."},
  {key="lmod",        variants={"Lmod","modules","module"},
   def="The module system that loads specific software versions into your shell on demand."},
  {key="denyonlimit", variants={"DenyOnLimit"},
   def="A QOS flag: an over-limit request is rejected at submit time, not silently queued."},
  {key="seff",        variants={"seff"},
   def="A command showing a finished job's CPU and memory efficiency — use it to right-size."},
  {key="oom",         variants={"OOM"},
   def="Out Of Memory — when a job exceeds its memory reservation and is killed. Fix by raising --mem."},
  {key="priority",    variants={"priority"},
   def="The score that orders pending jobs; on MedicineBow dominated by QOS (weight 200)."},
}

-- Flatten to a lookup list of {pat=lowercased, key, def}, longest first so
-- multi-word variants win over their single-word substrings.
local TERMS = {}
for _, e in ipairs(ENTRIES) do
  for _, v in ipairs(e.variants) do
    TERMS[#TERMS+1] = {pat = v:lower(), key = e.key, def = e.def}
  end
end
table.sort(TERMS, function(a, b) return #a.pat > #b.pat end)

local seen = {}

-- Word char = alphanumeric OR hyphen, so "investor" won't match inside
-- "non-investor" and "core-hour" is treated as a single token.
local function is_wordch(ch) return ch ~= "" and ch:match("[%w%-]") ~= nil end

-- Find first whole-word match of `pat` in lowercased `lt` at/after `from`.
local function find_word(lt, pat, from)
  local s = from
  while true do
    local i, j = lt:find(pat, s, true)
    if not i then return nil end
    local before = i > 1 and lt:sub(i-1, i-1) or ""
    local after  = lt:sub(j+1, j+1)
    if not is_wordch(before) and not is_wordch(after) then return i, j end
    s = i + 1
  end
end

-- append plain text `s` to inline list `out` as Str/Space nodes
local function append_text(out, s)
  local i, n = 1, #s
  while i <= n do
    if s:sub(i, i):match("%s") then
      out[#out+1] = pandoc.Space(); i = i + 1
    else
      local j = i
      while j <= n and not s:sub(j, j):match("%s") do j = j + 1 end
      out[#out+1] = pandoc.Str(s:sub(i, j-1)); i = j
    end
  end
end

-- Process one contiguous run of plain text: tag first-unseen term occurrences.
local function handle_text(text)
  local out = {}
  local lt = text:lower()
  local pos = 1
  while true do
    local bs, be, bdef, bkey
    for _, t in ipairs(TERMS) do
      if not seen[t.key] then
        local s, e = find_word(lt, t.pat, pos)
        if s and (not bs or s < bs or (s == bs and (e - s) > (be - bs))) then
          bs, be, bdef, bkey = s, e, t.def, t.key
        end
      end
    end
    if not bs then append_text(out, text:sub(pos)); break end
    append_text(out, text:sub(pos, bs - 1))
    seen[bkey] = true
    out[#out+1] = pandoc.Span(pandoc.Str(text:sub(bs, be)),
                              pandoc.Attr("", {"gloss"}, {{"data-def", bdef}, {"aria-label", bdef}}))
    pos = be + 1
  end
  return out
end

-- Walk an inline list: collect runs of plain text, recurse into simple emphasis
-- containers, pass Code/Math/Link through untouched.
local function process_inlines(inlines)
  local out = {}
  local run = {}
  local function flush()
    if #run > 0 then
      for _, x in ipairs(handle_text(table.concat(run))) do out[#out+1] = x end
      run = {}
    end
  end
  for _, el in ipairs(inlines) do
    local t = el.t
    if t == "Str" then run[#run+1] = el.text
    elseif t == "Space" or t == "SoftBreak" then run[#run+1] = " "
    else
      flush()
      if t == "Emph" or t == "Strong" or t == "Underline" then
        el.content = process_inlines(el.content)
      end
      out[#out+1] = el
    end
  end
  flush()
  return out
end

-- Manual block walk: process prose; skip headings, code, and glossary defs.
local function walk_blocks(blocks)
  for _, b in ipairs(blocks) do
    local t = b.t
    if t == "Para" or t == "Plain" then
      b.content = process_inlines(b.content)
    elseif t == "BulletList" or t == "OrderedList" then
      for _, item in ipairs(b.content) do walk_blocks(item) end
    elseif t == "BlockQuote" or t == "Div" then
      walk_blocks(b.content)
    end
    -- skipped: Header, CodeBlock, RawBlock, DefinitionList, Table
  end
end

function Pandoc(doc)
  seen = {}
  walk_blocks(doc.blocks)
  return doc
end
