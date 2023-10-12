--- A data link (OSI layer 2) protocol.
---
--- This is an unreliable and unencrypted protocol for unicast modem-to-modem
--- communication.
local unilink = {
    --- The unique unilink protcol ID.
    pid = 1035,
}

--- Sends a unicast frame.
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

    -- 1. If all of the following are true?
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
        -- a. Then payload is a valid unilink frame.

        --- @type any, number, number, table
        local _, source, destination, data = table.unpack(payload)

        -- 2. If...
        -- a. The source is this computer.
        if source == os.getComputerID() then
            -- i. Then this unilink frame should be sent from this computer.
            for _, name in ipairs(peripheral.getNames()) do
                if not (name == side) and peripheral.getType(name) == "modem" then
                    peripheral.wrap(name).transmit(
                        unilink.pid,
                        unilink.pid,
                        { unilink.pid, source, destination, data }
                    )
                end
            end
        -- b. The destination is this computer.
        elseif destination == os.getComputerID() then
            -- i. Then this unilink frame is for this computer.
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

return unilink
