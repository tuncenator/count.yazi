--- @since 26.1.22

---@class State
---@field cache table<string, CacheEntry>
---@field opts Options

---@class CacheEntry
---@field mtime integer
---@field label_all string
---@field label_visible string
---@field failed boolean

---@class Options
---@field limit integer
---@field overflow_label string
---@field unreadable_label string
---@field style table?

local DEFAULTS = {
	limit = 10000,
	overflow_label = "10k+",
	unreadable_label = "?",
	style = nil,
}

local set = ya.sync(function(st, key, mtime, label_all, label_visible, failed)
	st.cache[key] = {
		mtime = mtime,
		label_all = label_all,
		label_visible = label_visible,
		failed = failed,
	}
	ui.render()
end)

local should_fetch = ya.sync(function(st, key, mtime)
	local hit = st.cache[key]
	return not hit or hit.mtime ~= mtime or hit.failed
end)

local read_opts = ya.sync(function(st)
	return st.opts
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
		if not hit then
			return ""
		end
		local label = cx.active.pref.show_hidden and hit.label_all or hit.label_visible
		if st.opts.style and label ~= "" then
			return ui.Line { ui.Span(label):style(st.opts.style) }
		end
		return label
	end
end

---@type UnstableFetcher
local function fetch(_, job)
	local opts = read_opts()
	for _, f in ipairs(job.files) do
		local key = tostring(f.url)
		local mtime = f.cha.mtime or 0
		if should_fetch(key, mtime) then
			local entries = fs.read_dir(f.url, { limit = opts.limit + 1, resolve = false })
			if not entries then
				set(key, mtime, opts.unreadable_label, opts.unreadable_label, true)
			else
				local n_all = #entries
				local n_visible = 0
				for _, e in ipairs(entries) do
					if e.name:sub(1, 1) ~= "." then
						n_visible = n_visible + 1
					end
				end
				local label_all = (n_all > opts.limit) and opts.overflow_label or tostring(n_all)
				local label_visible = (n_visible > opts.limit) and opts.overflow_label or tostring(n_visible)
				set(key, mtime, label_all, label_visible, false)
			end
		end
	end
	return false
end

return { setup = setup, fetch = fetch }
