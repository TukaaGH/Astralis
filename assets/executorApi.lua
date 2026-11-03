return function(environment)
    local debugLibrary = environment.debug or {}
    local function choose(...)
        for index = 1, select("#", ...) do
            local value = select(index, ...)
            if type(value) == "function" then return value end
        end
    end
    local api = {
        dumpbytecode = choose(environment.dumpbytecode, environment.getfunctionbytecode),
        getupvalues = choose(environment.getupvalues, debugLibrary.getupvalues),
        getconstants = choose(environment.getconstants, debugLibrary.getconstants),
        getconstant = choose(environment.getconstant, debugLibrary.getconstant),
        setupvalue = choose(environment.setupvalue, debugLibrary.setupvalue),
        setconstant = choose(environment.setconstant, debugLibrary.setconstant),
        getreg = choose(environment.getreg, debugLibrary.getregistry),
        getthreadidentity = choose(environment.getthreadidentity, environment.getidentity, environment.getthreadcontext),
        setthreadidentity = choose(environment.setthreadidentity, environment.setidentity, environment.setthreadcontext),
        getcustomasset = choose(environment.getcustomasset, environment.getsynasset),
    }
    local required = {
        {"debug.info", debugLibrary.info}, {"getupvalues", api.getupvalues},
        {"dumpbytecode/getfunctionbytecode", api.dumpbytecode}, {"getscriptbytecode", environment.getscriptbytecode},
        {"hookfunction", environment.hookfunction}, {"newcclosure", environment.newcclosure},
        {"restorefunction", environment.restorefunction}, {"isfunctionhooked", environment.isfunctionhooked},
        {"getrawmetatable", environment.getrawmetatable}, {"getgc", environment.getgc},
        {"getallthreads", environment.getallthreads}, {"getscriptfromthread", environment.getscriptfromthread},
        {"getconnections", environment.getconnections}, {"getreg", api.getreg},
        {"getthreadidentity", api.getthreadidentity}, {"setthreadidentity", api.setthreadidentity},
        {"getfenv", environment.getfenv}, {"setfenv", environment.setfenv},
        {"getconstants", api.getconstants}, {"getconstant", api.getconstant},
        {"setupvalue", api.setupvalue}, {"setconstant", api.setconstant},
        {"Drawing.new", environment.Drawing and environment.Drawing.new},
        {"isfile", environment.isfile}, {"readfile", environment.readfile}, {"writefile", environment.writefile},
        {"isfolder", environment.isfolder}, {"makefolder", environment.makefolder},
        {"listfiles", environment.listfiles}, {"delfile", environment.delfile}, {"getcustomasset", api.getcustomasset},
    }
    for _, entry in ipairs(required) do
        if type(entry[2]) ~= "function" then return nil, entry[1] end
    end
    return setmetatable(api, {__index = environment})
end
