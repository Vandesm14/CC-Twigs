local printer = peripheral.find("printer")

if not printer then
  error("Cannot find an attached printer.")
end

-- Start a new page, or print an error.
if not printer.newPage() then
  error("Cannot start a new page. Do you have ink and paper?")
end

printer.setPageTitle(nil)

local maxX, maxY = printer.getPageSize()
for y = 1, maxY do
  for x = 1, maxX do
    printer.setCursorPos(x, y)
    printer.write(" ")
  end
end

-- And finally print the page!
if not printer.endPage() then
  error("Cannot end the page. Is there enough space?")
end
