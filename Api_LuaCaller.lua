--[[v2.0.0]]
local log = require("log")
local Api = require("coreApi")
local json = require("json")
local http = require("http")
-- CurrentQQ 当前操作的QQ号 /funcName 欲调用LuaApi函数名 ／data  组装Json数据
function Api_LuaCaller(CurrentQQ, funcName, data)
    str = string.format("Api_LuaCaller FuncName %s\n", funcName)
    log.info("%s", str)

    local luaResp = nil

    local switch = {
        --发送消息接口
        ["SendMsg"] = function()
            t = {
                --组建参数 table
                toUser = data.toUser, --欲发给的对象 群或QQ好友或私聊对象 整数型
                sendToType = data.sendToType, --发送消息对象的类型 1好友 2群3私聊 整数型
                sendMsgType = data.sendMsgType,
                -- 欲发送消息的类型 "TextMsg","JsonMsg","XmlMsg","ReplayMsg" ,"TeXiaoTextMsg","PicMsg","VoiceMsg","PhoneMsg" 文本型
                groupid = data.groupid, -- 发送私聊消息是 在此传入群ID 其他情况为0 整数型
                content = data.content, -- 发送的文本内容
                atUser = data.atUser, --   At用户 传入用户的QQ号 其他情况为0 整数类型 (不支持多人@)
                voiceUrl = data.voiceUrl, --发送语音的网络地址 文本型
                voiceBase64Buf = data.voiceBase64Buf, --发本地送语音的buf 转 bas64 编码 文本型
                picUrl = data.picUrl,
                --发送图片的网络地址 文本型
                picBase64Buf = data.picBase64Buf,
                --发本地送图片的buf 转 bas64 编码 文本型
                fileMd5 = data.fileMd5, --通过md5 值发送 图片 文本型
                replayInfo = nil
            }

            if data.replayInfo ~= nil then
                t.replayInfo = {
                    MsgSeq = data.replayInfo.MsgSeq,
                    --回复消息的Seq
                    MsgTime = data.replayInfo.MsgTime,
                    --回复消息的事件
                    UserID = data.replayInfo.UserID,
                    --回复消息对象
                    RawContent = data.replayInfo.RawContent --回复消息的原内容
                }
            end

            return Api.Api_SendMsg(
                CurrentQQ,
                --欲操作的QQ号 文本型
                t
            )
        end,
        --QQ群功能包加群 拉人 踢群 退群
        ["GroupMgr"] = function()
            --[[
                ActionType =8 拉人入群  -->{"ActionType":8,"GroupID":123456,"ActionUserID":987654,"Content":""}
                ActionType=1 加入群聊 -->{"ActionType":1,"GroupID":123456,"ActionUserID":0,"Content":"你好通过一下"}
                ActionType=2 退出群聊 -->{"ActionType":2,"GroupID":123456,"ActionUserID":0,"Content":""}
                ActionType=3 移出群聊 -->{"ActionType":3,"GroupID":123456,"ActionUserID":987654,"Content":""}
]]
            return Api.Api_GroupMgr(
                CurrentQQ,
                {
                    ActionType = data.ActionType, --群操作类型
                    GroupID = data.GroupID, --目标群ID
                    ActionUserID = data.ActionUserID, --移除群的UserID
                    Content = data.Content --加群理由
                }
            )
        end,
        --添加QQ好友
        ["AddQQUser"] = function()
            luaRes = Api.Api_GetUserAddFriendSetting(CurrentQQ, data.AddUserUid, data.Content)
            luaRes.Content = data.Content --添加好友理由 我是.xxxx想请求添加你为好友
            --来源2011 空间2020 QQ搜索 2004群组 2005讨论组
            luaRes.AddFromSource = data.AddFromSource
            luaRes.FromGroupID = data.FromGroupID --来源 为 2004 时 请填群ID 其他情况为0
            Api.Api_AddQQUser(CurrentQQ, luaRes)
            return luaRes
        end,
        --获取QQ好友列表
        ["GetQQUserList"] = function()
            --StartIndex 起始索引
            return Api.Api_GetQQUserList(CurrentQQ, data.StartIndex)
        end,
        --获取QQ群列表
        ["GetGroupList"] = function()
            --NextToken 初始为 ""
            return Api.Api_GetGroupList(CurrentQQ, data.NextToken)
        end,
        --获取QQ群成员列表
        ["GetGroupUserList"] = function()
            --GroupUin 群ID 首次LastUin=0
            return Api.Api_GetGroupUserList(CurrentQQ, data.GroupUin, data.LastUin)
        end,
        --禁言
        ["ShutUp"] = function()
            --{"ShutUpType":1,"GroupID":960839480,"ShutUid":0,"ShutTime":0}
            return Api.Api_ShutUp(CurrentQQ, data.ShutUpType, data.GroupID, data.ShutUid, data.ShutTime)
        end,
        --撤回消息
        ["RevokeMsg"] = function()
            --{"GroupID":0,"MsgSeq":0,"MsgRandom":0}参数来自于 lua  ReceiveGroupMsg  事件  data 数据 data.MsgSeq, data.MsgRandom 可撤回自己发的消息 或管理员权限撤回群成员消息
            return Api.Api_RevokeMsg(CurrentQQ, data.GroupID, data.MsgSeq, data.MsgRandom)
        end,
        --搜索QQ群组
        ["SearchGroup"] = function()
            --{"Content":"深圳","Page":0} 关键词 /页数
            return Api.Api_SearchGroup(CurrentQQ, data.Content, data.Page)
        end,
        --QQ赞
        ["QQZan"] = function()
            return Api.Api_QQZan(CurrentQQ, data.UserID)
        end,
        --退出指定QQ
        ["LogOut"] = function()
            --第一个参数为欲退出的QQ号 字符串类型  第二个参数为布尔类型 是否删除UsersConf目录下的设备信息文件 true 删除 false不删除 不建议删除 重新登录会复用之前的登录设备信息
            return Api.Api_LogOut(CurrentQQ, data.Flag)
        end,
        --获取登录QQ相关ck
        ["GetUserCook"] = function()
            return Api.Api_GetUserCook(CurrentQQ)
        end,
        --处理好友请求
        ["DealFriend"] = function()
            --Action 1忽略2同意3拒绝
            log.notice("From DealFriend Action \n%d", data.Action)
            return Api.Api_DealFriend(CurrentQQ, data)
        end,
        --处理群邀请
        ["AnswerInviteGroup"] = function()
            --Action --11 agree 14 忽略 21 disagree
            return Api.Api_AnswerInviteGroup(CurrentQQ, data)
        end,
        --打开红包 传入红包数据结构
        ["OpenRedBag"] = function()
            return Api.Api_OpenRedBag(CurrentQQ, data)
        end,
        --修改群名片
        ["ModifyGroupCard"] = function()
            return Api.Api_ModifyGroupCard(CurrentQQ, data.GroupID, data.UserID, data.NewNick)
        end,
        --获取QQ钱包余额
        ["GetBalance"] = function()
            return Api.Api_Tenpay_GetBalance(CurrentQQ)
        end,
        --发送QQ空间红包
        ["SendQzoneRed"] = function()
            return Api.Api_Tenpay_SendQzoneRed(CurrentQQ, data)
        end,
        --发送群/好友红包
        ["SendSingleRed"] = function()
            return Api.Api_Tenpay_SendSingleRed(CurrentQQ, data)
        end,
        --支付转账
        ["Transfer"] = function()
            return Api.Api_Tenpay_Transfer(CurrentQQ, data)
        end,
        --设置头衔
        ["SetUniqueTitle"] = function()
            return Api.Api_SetUniqueTitle(CurrentQQ, data.GroupID, data.UserID, data.NewTitle)
        end,
        --获取任意用户信息昵称头像等1
        ["GetUserInfo"] = function()
            return Api.Api_GetUserInfo(CurrentQQ, data.UserID)
        end
    }

    local fSwitch = switch[funcName] --switch func

    if fSwitch then --key exists
        luaResp = fSwitch() --do func
    else --key not found
        luaResp = {Ret = 1, Msg = string.format("Caller %s no exists", funcName)}
    end
    return luaResp
end
