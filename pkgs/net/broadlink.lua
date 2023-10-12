--- A data link (OSI layer 2) protocol.
---
--- This is an unreliable and unencrypted protocol for broadcast modem-to-modem
--- communication.
local broadlink = {
    --- The unique broadlink protcol ID.
    pid = 1036,
}

--- Sends a broadlink frame.
---
--- @generic T : table
--- @param data T
function broadlink.send(data)
    os.queueEvent(
        "modem_message",
        nil,
        broadlink.pid,
        broadlink.pid,
        { broadlink.pid, os.getComputerID(), data }
    )
end

function broadlink.daemon()
    --- @type unknown, computerSide?, unknown, unknown, unknown
    local _, side, _, _, payload = os.pullEvent("modem_message")

    -- 1. If all of the following are true.
    if
        type(payload) == "table"
        -- - PID is the broadlink PID.
        and payload[1] == broadlink.pid
        -- - Source is a number.
        and type(payload[2]) == "number"
        -- - Data is a table.
        and type(payload[3]) == "table"
    then
        -- 2. Then payload is a valid broadlink frame.

        --- @type any, number, table
        local _, source, data = table.unpack(payload)

        -- 3. If The source is this computer.
        if source == os.getComputerID() then
            -- 4. Then this broadlink frame should be sent from this computer
            --    via all connected modems, except the one it was received on.
            for _, name in ipairs(peripheral.getNames()) do
                if name ~= side and peripheral.getType(name) == "modem" then
                    peripheral.wrap(name).transmit(
                        broadlink.pid,
                        broadlink.pid,
                        { broadlink.pid, source, data }
                    )
                end
            end
        else
            -- 5. Otherwise, the broadlink frame should be received by this
            --    computer.
            os.queueEvent(
                "modem_message",
                side,
                broadlink.pid,
                broadlink.pid,
                data
            )
        end
    end
end

if not package.loaded["net.broadlink"] then
    -- This file was run as an executable.
    while true do
        broadlink.daemon()
    end
else
    -- This file was loaded as a library.
    return broadlink
end
