-- This file is part of the LiteX manual kit.
--
-- Copyright (c) 2019-2026 Florent Kermarrec <florent@enjoy-digital.fr>
-- SPDX-License-Identifier: BSD-2-Clause
--
-- Pandoc Lua filter for the LaTeX output: replace each SVG figure by the PDF that build.py
-- converted from it (directory in the MANUAL_FIGURES environment variable). The figures stay
-- vectors and pandoc does not need rsvg-convert. Other outputs are left untouched.

local dir = os.getenv("MANUAL_FIGURES")

function Image(el)
  if not FORMAT:match("latex") or dir == nil then return nil end
  local name = el.src:match("([^/]+)%.svg$")
  if name then
    el.src = dir .. "/" .. name .. ".pdf"
    return el
  end
  return nil
end
