-- This file is part of the LiteX manual kit.
--
-- Copyright (c) 2019-2026 Florent Kermarrec <florent@enjoy-digital.fr>
-- SPDX-License-Identifier: BSD-2-Clause
--
-- Pandoc Lua filter for the LaTeX output: write inline code as \texttt in the inline code colour
-- (edinline, metadata.yaml; the listings colours are those of the dark code blocks) and let it break after
-- "_", "/", ".", ":" and "-", before a CamelCase capital and at spaces, so that an identifier,
-- a path or a command at the end of a line does not run into the margin. The break points are
-- \allowbreak{} (no hyphen is printed). Other outputs are left untouched.

local function escape(s)
  -- The escaping pandoc applies inside \texttt{}.
  s = s:gsub("[\\{}_#%$%%&~%^]", function(c)
    if c == "\\" then return "\\textbackslash{}" end
    if c == "~" then return "\\textasciitilde{}" end
    if c == "^" then return "\\textasciicircum{}" end
    return "\\" .. c
  end)
  return s
end

function Code(el)
  if not FORMAT:match("latex") then return nil end
  local out = {}
  local prev = ""
  for ch in el.text:gmatch(".") do
    -- A break is also allowed before a capital that follows a lower-case letter (CamelCase).
    if ch:match("%u") and prev:match("%l") then table.insert(out, "\\allowbreak{}") end
    if ch == " " then
      table.insert(out, " ")          -- a breakable space (pandoc would write an unbreakable one)
    else
      table.insert(out, escape(ch))
    end
    if ch == "_" or ch == "/" or ch == "." or ch == ":" or ch == "-" then
      table.insert(out, "\\allowbreak{}")
    end
    prev = ch
  end
  return pandoc.RawInline("latex", "\\textcolor{edinline}{\\texttt{" .. table.concat(out) .. "}}")
end
