-- This file is part of the LiteX manual kit.
--
-- Copyright (c) 2019-2026 Florent Kermarrec <florent@enjoy-digital.fr>
-- SPDX-License-Identifier: BSD-2-Clause
--
-- Pandoc Lua filter for the HTML output: letter the appendices (A, B, ...) as LaTeX \appendix does
-- in the PDF. The headers after the raw LaTeX "\appendix" block are made unnumbered and get an
-- explicit "A", "A.1", ... section number span, styled like the automatic ones.

function Pandoc(doc)
  if not FORMAT:match("html") then return nil end
  local in_appendix = false
  local chapter, counters = 0, {}
  for _, blk in ipairs(doc.blocks) do
    if blk.t == "RawBlock" and blk.format == "latex" and blk.text:match("\\appendix") then
      in_appendix = true
    elseif in_appendix and blk.t == "Header" and not blk.classes:includes("unnumbered") then
      local number
      if blk.level == 1 then
        chapter = chapter + 1
        counters = {}
        number = string.char(64 + chapter)
      else
        counters[blk.level] = (counters[blk.level] or 0) + 1
        for l = blk.level + 1, 6 do counters[l] = nil end
        number = string.char(64 + chapter)
        for l = 2, blk.level do number = number .. "." .. (counters[l] or 0) end
      end
      blk.classes:insert("unnumbered")
      local span = pandoc.Span({pandoc.Str(number)}, {class = "header-section-number"})
      table.insert(blk.content, 1, pandoc.Space())
      table.insert(blk.content, 1, span)
    end
  end
  return doc
end
