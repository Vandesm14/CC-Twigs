--- A data link (OSI layer 2) protocol.
---
--- This is an unreliable and unencrypted protocol for broadcast modem-to-modem
--- communication.
local broadlink = {
    --- The unique unilink protcol ID.
    pid = 1036,
}

--- Sends a unicast frame.
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

    -- 1. If all of the following are true?
    if
        type(payload) == "table"
        -- - PID is the unilink PID.
        and payload[1] == broadlink.pid
        -- - Source is a number.
        and type(payload[2]) == "number"
        -- - Data is a table.
        and type(payload[3]) == "table"
    then
        -- a. Then payload is a valid unilink frame.

        --- @type any, number, table
        local _, source, data = table.unpack(payload)

        -- 2. If...
        -- a. The source is this computer.
        if source == os.getComputerID() then
            -- i. Then this unilink frame should be sent from this computer.
            for _, name in ipairs(peripheral.getNames()) do
                if not (name == side) and peripheral.getType(name) == "modem" then
                    peripheral.wrap(name).transmit(
                        broadlink.pid,
                        broadlink.pid,
                        { broadlink.pid, source, data }
                    )
                end
            end
        -- b. Otherwise, the destination is this computer.
        else
            -- i. Then this unilink frame is for this computer.
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

return broadlink
