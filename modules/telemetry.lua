local Telemetry = {}

function Telemetry.Init()
    local file = io.open("cbm_telemetry.log", "w")
    if file then
        file:write("=== CyberBuildManager Telemetry Session Started ===\n")
        file:close()
    end
end

function Telemetry.Log(category, message)
    local file = io.open("cbm_telemetry.log", "a")
    if file then
        file:write(string.format("[%s] %s\n", category, message))
        file:close()
    end
end

return Telemetry
