--- @since 26.1.22

---@class State
---@field cache table<string, CacheEntry>
---@field opts Options

---@class CacheEntry
---@field mtime integer
---@field label string
---@field failed boolean

---@class Options
---@field limit integer
---@field overflow_label string
---@field unreadable_label string
---@field show_hidden_aware boolean
---@field style table?

local DEFAULTS = {
	limit = 10000,
	overflow_label = "10k+",
	unreadable_label = "?",
	show_hidden_aware = true,
	style = nil,
}

local set = ya.sync(function(st, key, mtime, label, failed)
	st.cache[key] = { mtime = mtime, label = label, failed = failed }
	ui.render()
end)

local should_fetch = ya.sync(function(st, key, mtime)
	local hit = st.cache[key]
	return not hit or hit.mtime ~= mtime or hit.failed
end)

local read_state = ya.sync(function(st)
	return st.opts, cx.active.pref.show_hidden
end)

---@param st State
---@param opts Options?
local function setup(st, opts)
	st.cache = {}
	st.opts = {}
	for k, v in pairs(DEFAULTS) do
		st.opts[k] = v
	end
	if opts then
		for k, v in pairs(opts) do
			st.opts[k] = v
		end
	end

	function Linemode:count()
		local f = self._file
		if not f.cha.is_dir then
			local bytes = f:size()
			return bytes and ya.readable_size(bytes) or ""
		end
		local hit = st.cache[tostring(f.url)]
		local label = hit and hit.label or ""
		if st.opts.style and label ~= "" then
			return ui.Line { ui.Span(label):style(st.opts.style) }
		end
		return label
	end
end

---@type UnstableFetcher
local function fetch(_, job)
	local opts, show_hidden = read_state()
	local hide = opts.show_hidden_aware and not show_hidden
	for _, f in ipairs(job.files) do
		local key = tostring(f.url)
		local mtime = f.cha.mtime or 0
		if should_fetch(key, mtime) then
			local entries = fs.read_dir(f.url, { limit = opts.limit + 1, resolve = false })
			if not entries then
				set(key, mtime, opts.unreadable_label, true)
			else
				local n
				if hide then
					n = 0
					for _, e in ipairs(entries) do
						if e.name:sub(1, 1) ~= "." then
							n = n + 1
						end
					end
				else
					n = #entries
				end
				local label = (n > opts.limit) and opts.overflow_label or tostring(n)
				set(key, mtime, label, false)
			end
		end
	end
	return false
end

return { setup = setup, fetch = fetch }
