--[[
--
--REQ
    {
        "acton" : "RankList.add", 
        "key": "hqy"
        "value": "92"
        ]
    }
--
--]]

local ERR_RANKLIST_INVALID_PARAM = 1000
local ERR_RANKLIST_OPERATION_FAILED = 1100

local function Err(errCode, errMsg, ...) 
   local msg = string.format(errMsg, ...)

   return {err_code=errCode, err_msg=msg} 
end

local function CheckParams(data, ...)
    local arg = {...} 

    if table.length(arg) == 0 then 
        return true
    end 
    
    for _, name in pairs(arg) do 
        if data[name] == nil or data[name] == "" then 
           return false 
        end 
    end 

    return true 
end 

local RankListAction = class("RankListAction", cc.server.ActionBase) 

function RankListAction:ctor(app)
    self.super:ctor(app)

    if app then 
        --self.rankList = app.getRankList(app)
        self.rankList = app.getRedis(app)
    end 

    self.reply = {}
end 

-- zcard 
-- param: ranklist 
function RankListAction:CountAction(data)
    assert(type(data) ==  "table", "data is NOT a table")

    local rl = self.rankList
    if rl == nil then
        throw(ERR_SERVER_RANKLIST_ERROR, "ranklist object does NOT EXIST")
    end 

    if not CheckParams(data, "ranklist") then 
        self.reply = Err(ERR_RANKLIST_INVALID_PARAM, "param(ranklist) is missed")
        return self.reply
    end 

    local listName = data.ranklist
    local count, err = rl:command("zcard", listName)
    if not count then 
        echoError("redis command zcard failed: %s", err)
        self.reply = Err(ERR_RANKLIST_OPERATION_FAILED, "operation RankList.Count failed")
        return self.reply
    end 

    self.reply.count = count
    return self.reply
end

-- zadd
-- param: ranklist, key, value 
function RankListAction:AddAction(data)  
    assert(type(data) ==  "table", "data is NOT a table")

    local rl = self.rankList
    if rl == nil then
        throw(ERR_SERVER_RANKLIST_ERROR, "ranklist object does NOT EXIST")
    end
 
    if not CheckParams(data, "ranklist", "key", "value") then 
        self.reply = Err(ERR_RANKLIST_INVALID_PARAM, "params(ranklist, key or value) are missed")
        return self.reply
    end 

    local listName = data.ranklist
    local key = data.key
    local value = data.value
    if type(value) ~= "number" then 
        self.reply = Err(ERR_RANKLIST_INVALID_PARAM, "param(value) is NOT number")
        return self.reply
    end 
    local ok, err = rl:command("zadd", listName, value, key)
    if not ok then 
        echoError("redis command zadd failed: %s", err)
        self.reply = Err(ERR_RANKLIST_OPERATION_FAILED, "operation RankList.Add failed")
        return self.reply
    end 
    
    self.reply.ok = 1
    return self.reply
end

-- zrem
-- param: ranklist, key
function RankListAction:RemoveAction(data)
    assert(type(data) ==  "table", "data is NOT a table")

    local rl = self.rankList
    if rl == nil then
        throw(ERR_SERVER_RANKLIST_ERROR, "ranklist object does NOT EXIST")
    end
 
    if not CheckParams(data, "ranklist", "key") then 
        self.reply = Err(ERR_RANKLIST_INVALID_PARAM, "params(ranklist or key) are missed")
        return self.reply
    end

    local listName = data.ranklist
    local key = data.key 
    local err = nil 
    ok, err = rl:command("zrem", listName, key) 
    if not ok then 
        echoError("redis command zrem faild: %s", err)
        self.reply = Err(ERR_RANKLIST_OPERATION_FAILED, "operation RankList.Remove failed")
        return self.reply
    end 

    self.reply.ok = 1
    return self.reply
end

-- zset:dump()
-- param: none
--[[
function RankListAction:DumpAction(data) 
    assert(type(data) ==  "table", "data is NOT a table")

    local rl = self.rankList
    if rl == nil then
        throw(ERR_SERVER_RANKLIST_ERROR, "ranklist object does NOT EXIST")
    end

    rl:dump()
    return self.reply 
end
--]]

-- zscore
-- param: ranklist, key
function RankListAction:ScoreAction(data) 
    assert(type(data) ==  "table", "data is NOT a table")

    local rl = self.rankList
    if rl == nil then
        throw(ERR_SERVER_RANKLIST_ERROR, "ranklist object does NOT EXIST")
    end
 
    if not CheckParams(data, "ranklist", "key") then 
        self.reply = Err(ERR_RANKLIST_INVALID_PARAM, "params(ranklist or key) are missed")
        return self.reply
    end
    
    local listName = data.ranklist
    local key = data.key
    local score, err = rl:command("zscore", listName, key)
    if not score then 
        echoError("redis command zscore faild: %s", err)
        self.reply = Err(ERR_RANKLIST_OPERATION_FAILED, "opration RankList.Score failed")
        return self.reply
    end 

    if tostring(score) == "userdata: NULL" then 
        echoError("score is userdate:null")    
        return self.reply
    end 

    self.reply.score = score
    return self.reply
end

-- zrangebysocre
-- param: ranklist, min, max 
function RankListAction:GetScoreRangeAction(data)
    assert(type(data) ==  "table", "data is NOT a table")

    local rl = self.rankList
    if rl == nil then
        throw(ERR_SERVER_RANKLIST_ERROR, "ranklist object does NOT EXIST")
    end
 
    if not CheckParams(data, "ranklist", "min", "max") then 
        self.reply = Err(ERR_RANKLIST_INVALID_PARAM, "params(ranklist, min or max) are missed")
        return self.reply
    end

    local listName = data.ranklist
    local upper = tonumber(data.max)
    local lower = tonumber(data.min)
    if not upper or not lower then
        self.reply = Err(ERR_RANKLIST_INVALID_PARAM, "params(max or min) are NOT number")
        return self.reply
    end

    local r, err = rl:command("zrangebyscore", listName, lower, upper)
    if not r then 
        echoError("redis command zrangebyscore failed: %s", err)
        self.reply = Err(ERR_RANKLIST_OPERATION_FAILED, "operation RankList.GetScoreRange failed")
        return self.reply
    end
    local res = {} 
    for _, v in pairs(r) do 
        local s = nil 
        s, err = rl:command("zscore", listName, v) 
        if not s then 
            echoError("redis command zscore faild: %s", err)
            self.reply = Err(ERR_RANKLIST_OPERATION_FAILED, "operation RankList.GetScoreRange failed")
            return self.reply
        end
        table.insert(res, {uid = v, score = s})
    end 
    if next(res) ~= nil then 
        self.reply.scores = res 
    end
   
    return self.reply
end

-- zrank 
-- param: ranklist, key
function RankListAction:GetRankAction(data) 
    assert(type(data) ==  "table", "data is NOT a table")

    local rl = self.rankList
    if rl == nil then
        throw(ERR_SERVER_RANKLIST_ERROR, "ranklist object does NOT EXIST")
    end
 
    if not CheckParams(data, "ranklist", "key") then 
        self.reply = Err(ERR_RANKLIST_INVALID_PARAM, "params(ranklist or key) are missed")
        return self.reply
    end

    local listName = data.ranklist
    local key = data.key
    local rank, err = rl:command("zrank", listName, key)
    if not rank then 
        echoError("redis command zrank failed: %s", err)
        self.reply = Err(ERR_RANKLIST_OPERATION_FAILED, "operation RankList.GetRank failed")
        return self.reply
    end
    if tostring(rank) == "userdata: NULL" then 
        return self.reply
    end
    self.reply.rank = rank + 1

    return self.reply
end 

-- zrevrank 
-- param: ranklist, key
function RankListAction:GetRevRankAction(data) 
    assert(type(data) ==  "table", "data is NOT a table")

    local rl = self.rankList
    if rl == nil then
        throw(ERR_SERVER_RANKLIST_ERROR, "ranklist object does NOT EXIST")
    end
 
    if not CheckParams(data, "ranklist", "key") then 
        self.reply = Err(ERR_RANKLIST_INVALID_PARAM, "params(ranklist or key) are missed")
        return self.reply
    end

    local listName = data.ranklist
    local key = data.key
    local rev_rank, err = rl:command("zrevrank", listName, key)
    if not rev_rank then 
        echoError("redis command zrevrank failed: %s", err)
        self.reply = Err(ERR_RANKLIST_OPERATION_FAILED, "operation RankList.GetRevRank failed")
        return self.reply
    end
    if tostring(rev_rank) == "userdata: NULL" then 
        return self.reply
    end
    self.reply.rev_rank = rev_rank + 1 

    return self.reply
end 

-- zrange 
-- param: ranklist, offset, count 
function RankListAction:GetRankRangeAction(data)
    assert(type(data) ==  "table", "data is NOT a table")

    local rl = self.rankList
    if rl == nil then
        throw(ERR_SERVER_RANKLIST_ERROR, "ranklist object does NOT EXIST")
    end
 
    if not CheckParams(data, "ranklist", "offset", "count") then 
        self.reply = Err(ERR_RANKLIST_INVALID_PARAM, "params(ranklist, offset or count) are missed")
        return self.reply
    end

    local listName = data.ranklist
    local offset = tonumber(data.offset)
    local count = tonumber(data.count)
    if not offset or not count then
        self.reply = Err(ERR_RANKLIST_INVALID_PARAM, "params(offset or count) are NOT number")
        return self.reply
    end
    offset = offset - 1

    if offset < 0 or count <= 0 then 
        self.reply = Err(ERR_RANKLIST_INVALID_PARAM, "params(offset or count) can't be negtive or zero")
        return self.reply
    end 
    
    local r, err = rl:command("zrange", listName, offset, offset+count-1)
    if not r then  
        echoInfo("redis command zrange failed: %s", err)
        self.reply = Err(ERR_RANKLIST_OPERATION_FAILED, "operation RankList.GetRankRange failed")
        return self.reply
    end 
    local res = {} 
    for _, v in pairs(r) do 
        local s = nil
        s, err = rl:command("zscore", listName, v) 
        if err then 
            echoError("redis command zscore failed: %s", err)
            self.reply = Err(ERR_RANKLIST_OPERATION_FAILED, "operation RankList.GetRankRange failed")
            return self.reply
        end
        table.insert(res, {uid = v, score = s})
    end 
    if next(res) ~= nil then 
        self.reply.scores = res
    end 
    
    return self.reply 
end

-- zrevrange
-- param: ranklist, offset, count 
function RankListAction:GetRevRankRangeAction(data)
    assert(type(data) ==  "table", "data is NOT a table")

    local rl = self.rankList
    if rl == nil then
        throw(ERR_SERVER_RANKLIST_ERROR, "ranklist object does NOT EXIST")
    end
 
    if not CheckParams(data, "ranklist", "offset", "count") then 
        self.reply = Err(ERR_RANKLIST_INVALID_PARAM, "params(ranklist, offset or count) are missed")
        return self.reply
    end

    local listName = data.ranklist
    local offset = tonumber(data.offset)
    local count = tonumber(data.count) 
    if not offset or not count then
        self.reply = Err(ERR_RANKLIST_INVALID_PARAM, "params(offset or count) are NOT number")
        return self.reply
    end 
    offset = offset - 1

    if offset < 0 or count <= 0 then 
        self.reply = Err(ERR_RANKLIST_INVALID_PARAM, "params(offset or count) can't be negtive or zero")
        return self.reply
    end
    
    local r, err = rl:command("zrevrange", listName, offset, offset+count-1)
    if not r then  
        echoError("redis command zrevrange failed: %s", err)
        self.reply = Err(ERR_RANKLIST_OPERATION_FAILED, "operation RankList.GetRevRankRange failed")
        return self.reply
    end 
    local res = {} 
    for _, v in pairs(r) do 
        local s = nil
        s, err = rl:command("zscore", listName, v) 
        if not s then 
            echoError("redis command zscore failed: %s", err)
            self.reply = Err(ERR_RANKLIST_OPERATION_FAILED, "operation RankList.GetRevRankRange failed")
            return self.reply
        end
        table.insert(res, {uid = v, score = s})
    end 
    if next(res) ~= nil then 
        self.reply.scores = res 
    end 

    return self.reply
end

-- zremrangebyrank, used for reduce some element from tail
-- param: ranklist, count
function RankListAction:LimitAction(data)
    assert(type(data) ==  "table", "data is NOT a table")

    local rl = self.rankList
    if rl == nil then
        throw(ERR_SERVER_RANKLIST_ERROR, "ranklist object does NOT EXIST")
    end
 
    if not CheckParams(data, "ranklist", "count") then 
        self.reply = Err(ERR_RANKLIST_INVALID_PARAM, "params(ranklist or count) are missed")
        return self.reply
    end

    local listName = data.ranklist
    local count = tonumber(data.count)
    if not count then 
        self.reply = Err(ERR_RANKLIST_INVALID_PARAM, "param(count) is NOT number")
        return self.reply
    end 

    if count < 0 then 
        self.reply = Err(ERR_RANKLIST_INVALID_PARAM, "param(count) can't be negtive")
        return self.reply
    end

    local ok, err = rl:command("zremrangebyrank", listName, count, -1) 
    if not ok then 
        echoError("redis command zremrangebyrank faild: %s", err)
        self.reply = Err(ERR_RANKLIST_OPERATION_FAILED, "operation RankList.Limit failed")
        return self.reply
    end 

    self.reply.ok = 1
    return self.reply 
end

-- zremrangebyrank, used for reduce some element from head, contrary to zset:Limit()
-- param: ranklist, count
function RankListAction:RevLimitAction(data) 
    assert(type(data) ==  "table", "data is NOT a table")

    local rl = self.rankList
    if rl == nil then
        throw(ERR_SERVER_RANKLIST_ERROR, "ranklist object does NOT EXIST")
    end
 
    if not CheckParams(data, "ranklist", "count") then 
        self.reply = Err(ERR_RANKLIST_INVALID_PARAM, "params(ranklist or count) are missed")
        return self.reply
    end

    local listName = data.ranklist
    local count = tonumber(data.count)
    if not count then 
        self.reply = Err(ERR_RANKLIST_INVALID_PARAM, "param(count) is NOT number")
        return self.reply
    end

    if count < 0 then
        self.reply = Err(ERR_RANKLIST_INVALID_PARAM, "param(count) can't be negtive")
        return self.reply
    end

    local len, err = rl:command("zcard", listName) 
    if not len then 
        echoError("redis command zcard failed: %s", err)
        self.reply = Err(ERR_RANKLIST_OPERATION_FAILED, "operation RankList.RevLimit failed")
        return self.reply
    end 

    if len > count then 
        local ok = nil
        ok, err = rl:command("zremrangebyrank", listName, 0, len-count-1) 
        if not ok then 
            echoError("redis command zremrangebyrank failed: %s", err)
            self.reply = Err(ERR_RANKLIST_OPERATION_FAILED, "operation RankList.RevLimit failed")
            return self.reply
        end 
    end

    self.reply.ok = 1
    return self.reply
end

return RankListAction