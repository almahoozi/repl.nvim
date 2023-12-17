local M = {}
M.__index = M

-- TODO: Move to utils
local function get_visual_selection()
  if vim.fn.visualmode() == "v" then
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    local lines = vim.api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)
    if #lines == 0 then
      return ""
    end
    if #lines == 1 then
      return string.sub(lines[1], start_pos[3], end_pos[3])
    end
    lines[1] = string.sub(lines[1], start_pos[3])
    lines[#lines] = string.sub(lines[#lines], 1, end_pos[3])
    return table.concat(lines, "\n")
  end
  return ""
end

local function debug(message, ...)
  if not M.Debug then
    return
  end

  local args = { ... }
  for i, v in ipairs(args) do
    args[i] = vim.inspect(v)
  end
  print("Repl: " .. message .. " " .. table.concat(args, " "))
end

-- TODO: Move to separate repo
-- TODO: Setup CI
-- TODO Setup dev env and debugging
-- TODO: Maintain state
-- TODO: Write documentation
-- TODO: Write code docs
-- TODO: Write tests

-- TODO: Move to repls? langs? templates? ... something
-- TODO: Select language based on the current file that we are executing from; otherwise ask
-- On execution create the code files from the template(s), in tmp directory; ensure randomized names
-- then execute the code and display the output in a new buffer (options to make floating, specific buffer, etc. or just get the output as a return)
-- On error, display the error in a similar/same buffer
local repl_config = {
  ["go"] = {
    -- TODO: Somehow the templating should support multiple files, for example, a go.mod file in this case
    template = {
      ["<#FILE#>.go"] = "package main\n\nfunc main() {\n\t<#CODE#>\n}\n",
    },
    -- TODO: Format and organize imports before running
    -- TODO: Ensure dependencies are installed; maybe somehow also depend on the lsp config or something
    run = "gofmt -s -w <#FILE#> && goimports -w <#FILE#> && go run <#FILE#>", -- TODO: This should be able to take a function optionally
  },
}

-- TODO: Move to config.lua
local default_config = {
  Debug = false,
  Display = true,
  Repls = repl_config,
  Mappings = {
    -- Could be a string or a list of strings
    Run = {},
  },
}

--@class Config
--@field Debug boolean
--@field Repls table
--@field Display boolean
--@field Mappings table
local Config = {}
Config.__index = Config

--@param values table
--@return Config
function Config:new(config)
  -- TODO: Load and merge defaults
  -- TODO: Repls and Mappings are all or nothing, should do a deep merge
  if not config then
    config = default_config
  else
    for k, v in pairs(default_config) do
      if config[k] == nil then
        config[k] = v
      end
    end
  end

  return setmetatable(config, self)
end

--@param config Config
--@return Repl
function M.setup(config)
  if not config then
    config = default_config
  end

  config = Config:new(config)

  debug("Setting up REPL", config)

  for k, mapping in pairs(config.Mappings) do
    if type(mapping) == "string" then
      config.Mappings[k] = { mapping }
    elseif type(mapping) ~= "table" then
      error("Repl:setup: Invalid mapping type: " .. type(mapping))
    end
  end

  for _, mapping in pairs(config.Mappings.Run) do
    vim.keymap.set({ "n", "v" }, mapping, function()
      debug("Running REPL", M)
      M.run()
    end)
  end

  for k, c in pairs(config) do
    if c ~= nil then
      M[k] = c
    end
  end

  return M
end

--@param opts table | nil
--@return string
function M.run(opts)
  if not opts or #opts == 0 then
    -- TODO: This doesn't work correctly... on first load it doesn't recognize visual mode, it also doesn't seem to recognize visual block mode... I'm not sure whether it recognizes visual line mode since I only tested with a single line and that's the fallback
    local mode = vim.fn.visualmode()
    local code = get_visual_selection()
    if code == "" then
      code = vim.fn.getline(".")
    end

    opts = {
      code = code,
      lang = vim.bo.filetype,
    }

    debug("Running REPL", mode, code, opts.lang)
  end

  if not opts.lang then
    error("Repl:run: Language not provided", 2)
  end

  if not opts.code then
    error("Repl:run: Code not provided", 2)
  end

  local code = opts.code
  local lang = opts.lang

  debug("Running REPL", code, lang)

  local repl = M.Repls[lang]
  if not repl then
    error("Repl:run: No REPL found for language: " .. lang, 2)
  end

  local template = repl.template
  if not template then
    error("Repl:run: No template found for language: " .. lang, 2)
  end

  local run = repl.run
  if not run then
    error("Repl:run: No run command found for language: " .. lang, 2)
  end

  -- TODO: This loop works for my mvp case but it isn't correct nor generalizable
  for file_name, file_template in pairs(template) do
    local file_path = vim.fn.tempname() .. file_name:gsub("<#FILE#>", "")

    local file_content = file_template:gsub("<#CODE#>", code)
    debug("File content", file_path, file_content)

    local file_handle = io.open(file_path, "w")
    if not file_handle then
      error("Could not open file: " .. file_path, 2)
    end
    file_handle:write(file_content)
    file_handle:close()

    -- TODO: Need to run this only after all the files have been created
    local command = run:gsub("<#FILE#>", file_path)
    debug("Command", command)

    local output = vim.fn.system(command)
    debug("Output", output)

    -- TODO: Distinguish between errors and output

    -- TODO: Allow configuring/customizing the display
    if M.Display then
      -- covert the result to a array of lines
      local lines = vim.split(output, "\n")

      -- TODO: put it in a new floating window near the cursor and set the filetype to something unique (ex: github.com/almahoozi/repl) so we can customize it later with maps or aucmds
      -- TODO: Maybe attempt to run the command in json mode and do more fancy stuff?
      local buf = vim.api.nvim_create_buf(false, true)

      vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
      vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
      vim.api.nvim_buf_set_option(buf, "swapfile", false)
      vim.api.nvim_buf_set_option(buf, "filetype", "github.com-almahoozi-repl") -- TODO: Is this the right place to be a "unique" buffer?

      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      vim.api.nvim_buf_set_option(buf, "modifiable", false)

      -- TODO: Give the user the option to customize the keymaps of the result buffer
      vim.keymap.set("n", "<esc>", function()
        vim.api.nvim_win_close(0, true)
      end, { buffer = buf, noremap = true, silent = true })
      vim.keymap.set("n", "<C-]>", ":e " .. file_path .. "<CR>", { buffer = buf, noremap = true, silent = true })

      -- TODO: Give the user the option to customize the window
      local _ = vim.api.nvim_open_win(buf, true, {
        relative = "cursor",
        width = 80,
        height = 10,
        row = 1,
        col = 1,
        style = "minimal",
        border = "rounded",
      })
    end

    return output
  end
end

return M
