--- @since 26.1.22

---@class State
---@field cache table<string, { mtime: integer, label: string }>

---@class Options
---@field limit integer
---@field overflow_label string
---@field unreadable_label string
---@field show_hidden_aware boolean
---@field style table?

local OPTS = {
	limit = 10000,
	overflow_label = "10k+",
	unreadable_label = "?",
	show_hidden_aware = true,
	style = nil,
}

local set = ya.sync(function(st, key, mtime, label)
	st.cache[key] = { mtime = mtime, label = label }
	ui.render()
end)

local lookup = ya.sync(function(st, key, mtime)
	local hit = st.cache[key]
	return (hit and hit.mtime == mtime) and hit.label or nil
end)

local read_show_hidden = ya.sync(function()
	return cx.active.pref.show_hidden
end)

---@param st State
---@param opts Options?
local function setup(st, opts)
	st.cache = {}
	if opts then
		for k, v in pairs(opts) do
			OPTS[k] = v
		end
	end

	function Linemode:count()
		local f = self._file
		if not f.cha.is_dir then
			return self:size()
		end
		local hit = st.cache[tostring(f.url)]
		local label = hit and hit.label or ""
		if OPTS.style and label ~= "" then
			return ui.Line { ui.Span(label):style(OPTS.style) }
		end
		return label
	end
end

---@type UnstableFetcher
local function fetch(_, job)
	local hide = OPTS.show_hidden_aware and not read_show_hidden()
	for _, f in ipairs(job.files) do
		local key = tostring(f.url)
		local mtime = f.cha.mtime or 0
		if lookup(key, mtime) == nil then
			local entries = fs.read_dir(f.url, { limit = OPTS.limit + 1, resolve = false })
			local label
			if not entries then
				label = OPTS.unreadable_label
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
				label = (n > OPTS.limit) and OPTS.overflow_label or tostring(n)
			end
			set(key, mtime, label)
		end
	end
	return false
end

return { setup = setup, fetch = fetch }
