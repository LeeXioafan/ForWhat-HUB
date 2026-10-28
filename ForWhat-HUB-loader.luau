-- ForWhat HUB / multi-map loader
-- Add future games to MAPS. Keep only public release URLs here; never put GitHub tokens in a loader.
local MAPS = {
    {
        name = "Anime Piece",
        places = {134039915751463},
        url = "https://raw.githubusercontent.com/LeeXioafan/ForWhat-HUB/refs/heads/main/ForWhat-HUB-anime-piece",
        timeout = 60,
        ready = function()
            local globals = type(getrenv)=="function" and getrenv()._G or _G
            return globals.GameData~=nil and type(globals.GetModule)=="function"
        end,
    },
    -- Add another entry with name, places={PLACE_ID}, url="RAW_RELEASE_URL".
}

local function findMap(placeId)
    for _,entry in ipairs(MAPS)do
        for _,id in ipairs(entry.places)do if id==placeId then return entry end end
    end
end

local function showNotification(kind,message)
    local ok = pcall(function()
        local player=game:GetService("Players").LocalPlayer
        if not player then error("Player unavailable")end
        local parent=player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui",3)
        if not parent then error("PlayerGui unavailable")end
        local old=parent:FindFirstChild("ForWhatLoaderNotice")
        if old then old:Destroy()end
        local gui=Instance.new("ScreenGui")
        gui.Name="ForWhatLoaderNotice";gui.ResetOnSpawn=false;gui.DisplayOrder=10000
        local width=math.min(350,math.max(220,workspace.CurrentCamera.ViewportSize.X-32))
        local card=Instance.new("Frame")
        card.AnchorPoint=Vector2.new(.5,0);card.Position=UDim2.new(.5,0,0,22);card.Size=UDim2.fromOffset(width,100)
        card.BackgroundColor3=Color3.fromRGB(11,22,39);card.BackgroundTransparency=.06;card.BorderSizePixel=0;card.Parent=gui
        local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,12);corner.Parent=card
        local color=kind=="error" and Color3.fromRGB(255,151,151) or kind=="success" and Color3.fromRGB(145,226,190) or Color3.fromRGB(140,205,255)
        local stroke=Instance.new("UIStroke");stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;stroke.Color=color;stroke.Transparency=.3;stroke.Parent=card
        local accent=Instance.new("Frame");accent.Position=UDim2.fromOffset(0,15);accent.Size=UDim2.new(0,3,1,-30);accent.BackgroundColor3=color;accent.BorderSizePixel=0;accent.Parent=card
        local title=Instance.new("TextLabel");title.BackgroundTransparency=1;title.Position=UDim2.fromOffset(17,12);title.Size=UDim2.new(1,-34,0,23)
        title.Text="ForWhat HUB";title.Font=Enum.Font.GothamBold;title.TextSize=16;title.TextColor3=Color3.new(1,1,1);title.TextXAlignment=Enum.TextXAlignment.Left;title.Parent=card
        local detail=Instance.new("TextLabel");detail.BackgroundTransparency=1;detail.Position=UDim2.fromOffset(17,40);detail.Size=UDim2.new(1,-34,0,48)
        detail.Text=message;detail.TextWrapped=true;detail.Font=Enum.Font.Gotham;detail.TextSize=14;detail.TextColor3=Color3.fromRGB(221,233,247)
        detail.TextXAlignment=Enum.TextXAlignment.Left;detail.TextYAlignment=Enum.TextYAlignment.Top;detail.Parent=card
        gui.Parent=parent
        task.delay(7,function()if gui.Parent then gui:Destroy()end end)
    end)
    if not ok then
        pcall(function()game:GetService("StarterGui"):SetCore("SendNotification",{Title="ForWhat HUB",Text=message,Duration=7})end)
        warn("[ForWhat HUB] "..message)
    end
end

local function runRouter(context)
    context=context or {}
    local env=context.env or (type(getgenv)=="function" and getgenv() or _G)
    local previous=env.ForWhatLoaderState
    local english=env.LevelFarm and env.LevelFarm.language=="EN"
    local notify=context.notify or showNotification
    local function report(kind,th,en)notify(kind,english and en or th)end
    if previous and previous.loading then
        report("info","กำลังโหลดอยู่ กรุณารอสักครู่","Already loading. Please wait.")
        return {ok=false,status="BUSY"}
    end
    local state={loading=true,status="CHECKING",placeId=context.placeId or game.PlaceId}
    env.ForWhatLoaderState=state
    local function fail(status,th,en,detail)
        state.loading=false;state.status=status;state.error=detail
        report("error",th,en)
        return {ok=false,status=status}
    end
    local entry=findMap(state.placeId)
    if not entry then
        return fail("UNSUPPORTED","ยังไม่รองรับแมพนี้\nPlace ID: "..string.format("%.0f",state.placeId),
            "This map is not supported yet.\nPlace ID: "..string.format("%.0f",state.placeId))
    end
    state.map=entry.name
    local clock=context.clock or os.clock
    local wait=context.wait or task.wait
    local isLoaded=context.isLoaded or function()return game:IsLoaded()end
    local ready=context.ready or entry.ready or function()return true end
    local deadline=clock()+(entry.timeout or 60)
    state.status="WAITING"
    report("info","พบ "..entry.name.." / กำลังเตรียมสคริปต์",entry.name.." detected / preparing script")
    while true do
        local ok,loaded=pcall(isLoaded)
        local readyOk,prepared=pcall(ready)
        if ok and loaded and readyOk and prepared then break end
        if clock()>=deadline then return fail("TIMEOUT","เกมยังโหลดไม่พร้อม ลองรันใหม่หลังเข้าเกมแล้ว","Game is not ready. Try again after loading.")end
        wait(.25)
    end
    state.status="DOWNLOADING"
    local fetch=context.fetch or function(url)return game:HttpGet(url)end
    local fetched,source=pcall(fetch,entry.url)
    if not fetched or type(source)~="string" or #source==0 then
        return fail("DOWNLOAD_FAILED","โหลดสคริปต์ไม่สำเร็จ ตรวจอินเทอร์เน็ตหรือลองใหม่","Download failed. Check your connection and try again.",tostring(source))
    end
    state.status="COMPILING"
    local compiler=context.compile or loadstring
    local compileOk,run,compileError=pcall(compiler,source,"@ForWhatHubRouter")
    if not compileOk or type(run)~="function" then
        return fail("COMPILE_FAILED","ไฟล์สคริปต์ไม่พร้อมใช้งาน กรุณาติดต่อผู้พัฒนา","The script could not compile. Please contact the developer.",tostring(compileError or run))
    end
    state.status="STARTING"
    local ok,result=pcall(run)
    if not ok then
        return fail("START_FAILED","เริ่มสคริปต์ไม่สำเร็จ กรุณาลองใหม่หรือติดต่อผู้พัฒนา","The script could not start. Try again or contact the developer.",tostring(result))
    end
    state.loading=false;state.status="READY"
    report("success","เปิด ForWhat HUB สำหรับ "..entry.name.." แล้ว","ForWhat HUB is ready for "..entry.name)
    return {ok=true,status="READY",map=entry.name}
end

return runRouter()
