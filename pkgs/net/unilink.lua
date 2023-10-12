--- A data link (OSI layer 2) protocol.
---
--- This is an unreliable and unencrypted protocol for unicast modem-to-modem
--- communication.
local unilink = {
    --- The unique unilink protcol ID.
    pid = 1035,
}

--- Sends a unilink frame.
---
--- @generic T : table
--- @param destination integer
--- @param data T
function unilink.send(destination, data)
    os.queueEvent(
        "modem_message",
        nil,
        unilink.pid,
        unilink.pid,
        { unilink.pid, os.getComputerID(), destination, data }
    )
end

function unilink.daemon()
    --- @type unknown, computerSide?, unknown, unknown, unknown
    local _, side, _, _, payload = os.pullEvent("modem_message")

    -- 1. If all of the following are true.
    if
        type(payload) == "table"
        -- - PID is the unilink PID.
        and payload[1] == unilink.pid
        -- - Source is a number.
        and type(payload[2]) == "number"
        -- - Destination is a number.
        and type(payload[3]) == "number"
        -- - Data is a table.
        and type(payload[4]) == "table"
    then
        -- 2. Then payload is a valid unilink frame.

        --- @type any, number, number, table
        local _, source, destination, data = table.unpack(payload)

        -- 3. If The source is this computer.
        if source == os.getComputerID() then
            -- 4. Then this unilink frame should be sent from this computer via
            --    all connected modems, except the one it was received on.
            for _, name in ipairs(peripheral.getNames()) do
                if name ~= side and peripheral.getType(name) == "modem" then
                    peripheral.wrap(name).transmit(
                        unilink.pid,
                        unilink.pid,
                        { unilink.pid, source, destination, data }
                    )
                end
            end
        elseif destination == os.getComputerID() then
            -- 5. Otherwise, the unilink frame should be received by this
            --    computer.
            os.queueEvent(
                "modem_message",
                side,
                unilink.pid,
                unilink.pid,
                data
            )
        -- c. Otherwise, the destination is not this computer.
        end
    end
end


if not package.loaded["net.unilink"] then
    -- This file was run as an executable.
    while true do
        unilink.daemon()
    end
else
    -- This file was loaded as a library.
    return unilink
end
