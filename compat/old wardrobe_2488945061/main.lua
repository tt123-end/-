-- OLD WARDROBE - by Sinsthar
-- French comments are for myself, sorry ;)

OWR = RegisterMod("Old Wardrobe",1)
local	meuble = Isaac.GetEntityTypeByName("Old Wardrobe")
local	meubleVar = Isaac.GetEntityVariantByName("Old Wardrobe")

local	dressingEnt = nil
local	player = nil
local	exittimer = 0
local	shortrange = false
local	pausetimer = 0
local	destroyed = false
local	unlockall = false
local	gubed = false

------------------ new vars
local	maxitems = 0
local	maxfav = 64
local	itemtable = {}
local	iteminfos = {}
local	nocostume = {}
local	favcostume = {}
local	favnum = 0
local	flyingcostumes = 0
local	totalcostumes = 0
local	phase = -1 -- -1 = pas d'ui / 0 = Ui init
local	selPos = Vector(0,0) -- selection dans la grille
local	selection = 1
local	pageUI = 1
local	maxpagesUI = 1
local	actionbutton = 0
local	buttonpressed = false
local	buttonTimer = 0
local	invPosition = Vector(110,82)
local	invUI = nil
local	selUI = nil
local	savedata = ""
------------------- vars menu2
local	verso = false
local	pagelist = 1
local	maxpageslist = 1
local	selectionline = 3
local	validation = false
local	beginlines = 0
local	maxlines = 0
local	maxpaint = 0

local	c_white = Color(1,1,1,1,0,0,0)
local	c_green = Color(0,1,0,1,0,0,0)
local	c_blue = Color(0,0.5,1,1,0,0,0)
local	c_red = Color(1,0,0,1,0,0,0)
local	c_gray = Color(0.5,0.5,0.5,1,0,0,0)

-- Player forms
local	totalforms = 0
local	transfo = {}
local	transfocostume = {}
local	form = {}
form[PlayerForm.PLAYERFORM_MUSHROOM] =		NullItemID.ID_MUSHROOM
form[PlayerForm.PLAYERFORM_BOB] =		NullItemID.ID_BOB
form[PlayerForm.PLAYERFORM_DRUGS] =		NullItemID.ID_DRUGS
form[PlayerForm.PLAYERFORM_MOM] =		NullItemID.ID_MOM
form[PlayerForm.PLAYERFORM_BABY] =		NullItemID.ID_BABY
form[PlayerForm.PLAYERFORM_POOP] =		NullItemID.ID_POOP
form[PlayerForm.PLAYERFORM_BOOK_WORM] =		NullItemID.ID_BOOKWORM
form[PlayerForm.PLAYERFORM_ADULTHOOD] =		NullItemID.ID_ADULTHOOD
form[PlayerForm.PLAYERFORM_SPIDERBABY] =	NullItemID.ID_SPIDERBABY
form[PlayerForm.PLAYERFORM_GUPPY] =		NullItemID.ID_GUPPY
form[PlayerForm.PLAYERFORM_LORD_OF_THE_FLIES] =	NullItemID.ID_LORD_OF_THE_FLIES
form[PlayerForm.PLAYERFORM_ANGEL] =		NullItemID.ID_ANGEL
form[PlayerForm.PLAYERFORM_EVIL_ANGEL] =	NullItemID.ID_EVIL_ANGEL
local formnames = {}
formnames[NullItemID.ID_MUSHROOM]		= "MUSH"
formnames[NullItemID.ID_BOB]			= "BOB"
formnames[NullItemID.ID_DRUGS]			= "SPUN"
formnames[NullItemID.ID_MOM]			= "MOM"
formnames[NullItemID.ID_BABY]			= "BABY"
formnames[NullItemID.ID_POOP]			= "POOP"
formnames[NullItemID.ID_BOOKWORM]		= "BOOK"
formnames[NullItemID.ID_ADULTHOOD]		= "ADUL"
formnames[NullItemID.ID_SPIDERBABY]		= "SPID"
formnames[NullItemID.ID_GUPPY]			= "GUPPY"
formnames[NullItemID.ID_LORD_OF_THE_FLIES]	= "FLY"
formnames[NullItemID.ID_ANGEL]			= "ANGE"
formnames[NullItemID.ID_EVIL_ANGEL]		= "EVIL"
-- Paint costumes
require("main_default")
local paintname = {}
local paintloc = {}
local paintfly = {}
local pid = {}
CustomWardrobe = true

-- Hunter v1.78 compatibility: explicit UI actions, never gameplay mutations.
-- All calls are optional and scoped to the currently dressed Hunter player.
local function HunterBridge(action, value)
    local api = HunterWardrobe178
    if api and player and api.isHunter(player) and api[action] then
        return api[action](player, value)
    end
    return false
end
local function HunterListAction(action, key)
    if not HunterBridge(action, key) then return false end
    if action == "select" and key == "H178:AUTO" then
        for k in pairs(nocostume) do nocostume[k] = nil end
        for k in pairs(transfo) do transfo[k] = nil end
    elseif action == "select" then
        local item = tonumber(string.match(key, "^H178:I(%d+)$"))
        local formId = tonumber(string.match(key, "^H178:F(%d+)$"))
        if item then nocostume[item] = nil end
        if formId and HunterWardrobe178.formNative then
            local null = HunterWardrobe178.formNative(formId)
            if null then transfo[null] = nil end
        end
    end
    return true
end
--------------------------------------------------------------------------- Texte routine
local function WriteText(text, px, py, center, colr, colv, colb, cola, outline)
	local f = Font()

	if outline == nil then
		f:Load("font/luaminioutlined.fnt")
	else
		f:Load("font/luamini.fnt")
	end
	if center == false then
		f:DrawString(text,px,py,KColor(colr,colv,colb,cola),0,false)
	else
		f:DrawString(text,px-(f:GetStringWidth(tostring(text))/2),py,KColor(colr,colv,colb,cola),0,false)
	end
end
---------------------------------------------------------------------------------------------
local function LoadCostumeData(continuegame)
	local	checkplayer = Isaac.GetPlayer(0)
	local	num = 0

	if Isaac.HasModData(OWR) then
		local save = Isaac.LoadModData(OWR)
		while string.len(save) >= 4 do
			num = tonumber(string.sub(save, 1, 4))
			save = string.sub(save, 5)

			-- retire le costume
			if num > 9000 then
				num = num - 9000
				checkplayer:TryRemoveNullCostume(num)
				transfo[num] = 2
			elseif num > 8000 then
				num = num - 8000
				checkplayer:TryRemoveNullCostume(num)
				transfo[num] = 0
			elseif num > 7000 then
				num = num - 7000
				favcostume[num] = true
				if continuegame == false then -- desactive les items favoris
					nocostume[num] = true -- si nouvelle partie
				end
			else
				nocostume[num] = true
			end
		end
	end
end
---------------------------------------------------------------------------------------------
local function SaveCostumeData()
	for k, v in pairs(favcostume) do
		if favcostume[k] == true then
			savedata = savedata..string.format("%04d",k + 7000)
		end
	end
	for k, v in pairs(nocostume) do
		if nocostume[k] == true then
			savedata = savedata..string.format("%04d",k)
		end
	end
	Isaac.SaveModData(OWR,savedata)
end
---------------------------------------------------------------------------------------------
function OWR.GetCostumeName(id)
	return paintname[id]
end
---------------------------------------------------------------------------------------------
function OWR.AddCostumeToList(id, name, location, fly)
	--if maxpaint > 5 then return end
	if paintname[id] ~= nil then
		--Isaac.DebugString("[Old Wardrobe] --- : Warning, Costume "..name.." already in the wardrobe !")
		return
	end
	paintname[id] = name
	paintloc[id] = location
	if fly ~= nil and fly ~= false then
		paintfly[id] = true
	end
	maxpaint = maxpaint + 1
end
---------------------------------------------------------------------------------------------
local function sorted(t)
	local keys = {}
	for k in pairs(t) do keys[#keys+1] = k end
	table.sort(keys)
	local i = 0
	return function()
		i = i + 1
		if keys[i] then
			return keys[i], t[keys[i]]
		end
	end
end
-----------------------
local function CreateCostumesList()
	beginlines = 1
	maxlines = 1
	-- lignes avant 1
	if DefaultCostumes[player:GetPlayerType()] ~= nil then
		if paintname["!3"] == nil then
			OWR.AddCostumeToList("!3", "Default Costume", tostring(DefaultCostumes[player:GetPlayerType()]))
		end
	elseif TheStrangerRole ~= nil and (player:GetName() == "Stranger" or player:GetName() == "Tainted Stranger") then
		OWR.AddCostumeToList("!3", "Default Role Costume", "")
	end
	if paintname["!1"] == nil then
		OWR.AddCostumeToList("!1", "WIPE ALL COSTUMES", "")
	end
	if paintname["!2"] == nil then
		OWR.AddCostumeToList("!2", "Wipe all listed costumes", "")
	end
	-- lignes après 0
	for k,v in sorted(paintname) do
		if (string.sub(k,1,5) ~= "H178:" or HunterBridge("isHunter")) and ((WardrobePlus == nil) or (WardrobePlus ~= nil and OWRP.IsCostumeAvailable(k))) then
			pid[maxlines] = k
			maxlines = maxlines + 1
		end
	end
	maxlines = maxlines-1
end
---------------------------------------------------------------------------------------------
local function DrawPlayer(player)
    if HunterWardrobe178 and HunterWardrobe178.isHunter(player) then
        HunterWardrobe178.renderWings(player, Vector(invPosition.X+148,invPosition.Y+29), true)
    end
	player:RenderGlow(Vector(invPosition.X+148,invPosition.Y+29))
	player:RenderBody(Vector(invPosition.X+148,invPosition.Y+29))
	player:RenderHead(Vector(invPosition.X+148,invPosition.Y+29))
	player:RenderTop(Vector(invPosition.X+148,invPosition.Y+29))
end
---------------------------------------------------------------------------------------------
local function DrawList()
	local px = invPosition.X - 5
	local py = invPosition.Y - 13

	invUI:Play("Idle2")
	invUI:Render(invPosition, Vector(0,0), Vector(0,0)) -- le papier

	selUI:SetFrame("NextPage",0)
	selUI.Color = c_white
	selUI:Render(Vector(invPosition.X+119, invPosition.Y+55), Vector(0,0), Vector(0,0)) --115
	
	local n = 0
	local pagelist = math.floor((selectionline-1)/14)
	local firstline = beginlines + (pagelist*14)
	local lastline = math.min(14,maxlines) + (pagelist*14)

	if WardrobePlus == nil then
		if selectionline ~= 1 then
			WriteText("You can install",px+55,py+66, true, 1,1,1,0.2)
			WriteText("Old Wardrobe +",px+55,py+74, true, 1,1,1,0.2)
			WriteText("to add costumes",px+55,py+82, true, 1,1,1,0.2)
			WriteText("to this list",px+55,py+90, true, 1,1,1,0.2)
		end
	else
		WriteText("("..OWRP.GetNumLockedCostumes().." locked costumes)",px,py+112, false, 1,1,1,0.3)
		WriteText((pagelist+1).."/"..(math.floor((maxlines-1)/14)+1),px+108,py+112, true, 1,1,1,0.7)
	end

	for i=firstline, lastline do
		if pid[i] == nil then break end
		if selectionline == i then
			if pid[i] == "!1" then
				if WardrobePlus == nil then
					WriteText("Warning:",px-5,py+58, false, 1,0.7,0.7,1)
					WriteText("This can't be undone. All",px-5,py+66, false, 1,0.5,0.5,1)
					WriteText("special costumes applied",px-5,py+74, false, 1,0.5,0.5,1)
					WriteText("to the character will be",px-5,py+82, false, 1,0.5,0.5,1)
					WriteText("lost until you restart",px-5,py+90, false, 1,0.5,0.5,1)
					WriteText("a game. Don't do this on",px-5,py+98, false, 1,0.5,0.5,1)
					WriteText("a modded character.",px-5,py+106, false, 1,0.5,0.5,1)
				else
					WriteText("Warning: this can't be undone.",px+55,py+131, true, 1,0.6,0.6,1)
				end
			end
			if pid[i] == "!1" and validation == true then
				WriteText("- ARE YOU SURE !? -",px,py+((n)*8), false, 1,1,1,1)
			else
				WriteText(paintname[pid[i]],px,py+((n)*8), false, 1,1,1,1)
			end
		else
			WriteText(paintname[pid[i]],px,py+((n)*8), false, 1,1,1,0.5)
		end
		if pid[i] == "!1" or pid[i] == "!2" then
			selUI:SetFrame("Icon",2)
			selUI.Color = c_red
		elseif paintfly[pid[i]] ~= nil then
			selUI:SetFrame("Icon",1) -- fly icon
			selUI.Color = c_blue
		else
			selUI:SetFrame("Icon",4)
			selUI.Color = c_green
		end
		selUI:Render(Vector(px-7, py+11+((n)*8)), Vector(0,0), Vector(0,0))
		n = n+1
	end

	local msg = ""
	if player.FrameCount % 400 < 100 then
		msg = "<USE button> add costume" 
	elseif player.FrameCount % 400 < 200 then
		msg = "<PILL button> wipe costume"
	elseif player.FrameCount % 400 < 300 then
		msg = "<BOMB button> wipe listed"
	else
		msg = "<DROP button> to close"
	end
	WriteText(msg, invPosition.X+48, invPosition.Y+108, true, 0, 0, 0, 0.7, false)

	DrawPlayer(player)
end
---------------------------------------------------------------------------------------------
local function RenderList()
    local hunterInput = actionbutton
	DrawList()
    local key = pid[selectionline]
    local handled = false
    if actionbutton == ButtonAction.ACTION_MENUCONFIRM then
        handled = HunterListAction("select", key)
    elseif actionbutton == ButtonAction.ACTION_PILLCARD then
        handled = HunterListAction("undress", key)
    end
    if handled then
        actionbutton = -1
        dressingEnt:ToNPC():PlaySound(283,1,0,false,1)
        return
    end

	if (actionbutton == ButtonAction.ACTION_MENUCONFIRM) then
		if paintfly[pid[selectionline]] ~= nil and player.CanFly == false then
			-- rien
		elseif pid[selectionline] == "!1" then -- wipe all
			if validation == false then
				validation = true
			else
				validation = false
				player:ClearCostumes()
                HunterBridge("clear")
				for k, v in pairs(iteminfos) do
					if (iteminfos[k].Costume.IsFlying == false) then
						nocostume[HunterBridge("isHunter") and iteminfos[k].ID or iteminfos[k].Costume.ID] = true
					end
				end
				dressingEnt:ToNPC():PlaySound(283,1,0,false,1)
			end
		elseif pid[selectionline] == "!2" then -- wipe listed
            HunterBridge("clear")
			for k,v in pairs(paintname) do
				if tonumber(paintloc[k]) ~= nil then
					player:TryRemoveNullCostume(tonumber(paintloc[k]))
				else
					player:TryRemoveNullCostume(Isaac.GetCostumeIdByPath(paintloc[k]))
				end
			end	
		elseif pid[selectionline] == "!3" then
			if TheStrangerRole ~= nil and (player:GetName() == "Stranger" or player:GetName() == "Tainted Stranger") then
				THSTR.ApplyAllCostumes()
			else
				player:AddNullCostume(tonumber(paintloc[pid[selectionline]]))
			end
		elseif tonumber(paintloc[pid[selectionline]]) ~= nil then -- costume par numero
			player:AddNullCostume(tonumber(paintloc[pid[selectionline]]))
		else -- costume par location
			local dress = Isaac.GetCostumeIdByPath( paintloc[pid[selectionline]] )
			player:AddNullCostume(dress)
		end
		actionbutton = -1
		dressingEnt:ToNPC():PlaySound(283,1,0,false,1)
	elseif (actionbutton == ButtonAction.ACTION_PILLCARD) then
		if pid[selectionline] == "!1" or pid[selectionline] == "!2" then

		elseif tonumber(paintloc[pid[selectionline]]) ~= nil then -- costume par numero
			player:TryRemoveNullCostume(tonumber(paintloc[pid[selectionline]]))
		else
			local dress = Isaac.GetCostumeIdByPath( paintloc[pid[selectionline]] )
			player:TryRemoveNullCostume(dress)
		end
		dressingEnt:ToNPC():PlaySound(283,1,0,false,1)
	elseif (actionbutton == ButtonAction.ACTION_BOMB) then
        HunterBridge("clear")
		for k,v in pairs(paintname) do
			if tonumber(paintloc[k]) ~= nil then
				player:TryRemoveNullCostume(tonumber(paintloc[k]))
			else
				player:TryRemoveNullCostume(Isaac.GetCostumeIdByPath(paintloc[k]))
			end
		end
		dressingEnt:ToNPC():PlaySound(283,1,0,false,1)
	end
    if hunterInput > 0 then HunterBridge("refresh") end
end
---------------------------------------------------------------------------------------------
local function DrawUI()
	invUI:Play("Idle")
	invUI:Render(invPosition, Vector(0,0), Vector(0,0)) -- le papier

	selUI:SetFrame("Idle", player.FrameCount % 15)
	selUI.Color = c_white
	selUI:Render(invPosition + (selPos*32), Vector(0,0), Vector(0,0)) -- la selection

	-- item equippé ou pas
	for i=0, 3 do
		for j=0, 3 do
			selection = j*4 + i + 1 + ((pageUI-1) * 16) - totalforms

			if (selection <= #iteminfos) then
				if selection <= 0 then
					local form = transfocostume[selection+totalforms]
					WriteText(formnames[form], invPosition.X+(i*32)+1, invPosition.Y+(j*32)-5, true, 0, 0, 0, 0.8, false)
					if transfo[form] == 3 then
						selUI:SetFrame("Icon",1) -- fly icon
						selUI.Color = c_blue
					elseif transfo[form] == 2 then
						selUI:SetFrame("Icon",1) -- fly icon
						selUI.Color = c_gray
					elseif transfo[form] == 1 then
						selUI:SetFrame("Icon",0)
						selUI.Color = c_green
					else
						selUI:SetFrame("Icon",2)
						selUI.Color = c_red
					end
					selUI:Render(Vector(invPosition.X+(i*32)+8, invPosition.Y+(j*32)+13), Vector(0,0), Vector(0,0))

				elseif (iteminfos[selection].ID >= 729) then -- item moddé
					selUI:SetFrame("Icon",2)
					selUI.Color = c_gray
					selUI:Render(Vector(invPosition.X+(i*32)+8, invPosition.Y+(j*32)+13), Vector(0,0), Vector(0,0))

				elseif (iteminfos[selection].Costume.ID >= 0) then -- on a un costume
					if (iteminfos[selection].Costume.IsFlying) then
						selUI:SetFrame("Icon",1) -- fly icon
						selUI.Color = c_blue
						if nocostume[iteminfos[selection].ID] == true then
							selUI.Color = c_gray
						end
					elseif nocostume[iteminfos[selection].ID] == true then
						selUI:SetFrame("Icon",2)
						selUI.Color = c_red
					else
						selUI:SetFrame("Icon",0)
						selUI.Color = c_green
					end
					selUI:Render(Vector(invPosition.X+(i*32)+8, invPosition.Y+(j*32)+13), Vector(0,0), Vector(0,0))
					-- favoris
					if favcostume[iteminfos[selection].ID] == true then
						selUI:SetFrame("Icon",3)
						selUI.Color = Color(1,1,0,1,0,0,0)
						selUI:Render(Vector(invPosition.X+(i*32)-9, invPosition.Y+(j*32)+13), Vector(0,0), Vector(0,0))
					end
				end
				-- test
				if gubed == true or unlockall == true then
					local numID = selPos.Y*4 + selPos.X + 1 + ((pageUI-1) * 16) - totalforms
					if numID <= totalcostumes then
						WriteText("ID "..iteminfos[numID].ID, invPosition.X+48, invPosition.Y+116, true, 1, 1, 1, 1)
					end
				end
			end
		end
	end

	selection = (selPos.Y*4 + selPos.X + 1 + ((pageUI-1) * 16)) - totalforms

	if pageUI < maxpagesUI then
		selUI:SetFrame("NextPage",0)
		selUI.Color = c_white
		selUI:Render(Vector(invPosition.X+119, invPosition.Y+55), Vector(0,0), Vector(0,0)) --115
	end
	if verso == false then --pageUI > 1 then
		selUI:SetFrame("NextPage",1)
		selUI.Color = c_white
		selUI:Render(Vector(invPosition.X-23, invPosition.Y+55), Vector(0,0), Vector(0,0))
	end

	local msg = ""
	if player.FrameCount % 600 < 150 then
		msg = "<DROP button> to close"
	elseif player.FrameCount % 600 < 300 then
		msg = "<USE button> to dress"
	elseif player.FrameCount % 600 < 450 then
		msg = "<BOMB button> undress all"
	else
		msg = "<PILL button> add to fav."
	end
	WriteText(msg, invPosition.X+48, invPosition.Y+108, true, 0, 0, 0, 0.7, false)

	DrawPlayer(player)
end
---------------------------------------------------------------------------------------------
local function UpdateUI()
	local playsound = false
	local oldbutton = buttonpressed

	if (Input.IsActionPressed(ButtonAction.ACTION_MENUBACK,player.ControllerIndex) or Input.IsActionPressed(ButtonAction.ACTION_DROP,player.ControllerIndex)) then
		if (actionbutton == 0) then
			phase = -1
			exittimer = 6
			actionbutton = ButtonAction.ACTION_MENUBACK
			if destroyed == false then
				dressingEnt:GetSprite():Play("Close",true)
				dressingEnt:ToNPC():PlaySound(35,0.7,0,false,1.4) -- close
			end
			
			SaveCostumeData()

		end
	elseif (Input.IsActionPressed(ButtonAction.ACTION_MENUCONFIRM,player.ControllerIndex) or Input.IsActionPressed(ButtonAction.ACTION_ITEM,player.ControllerIndex)) then
		if (actionbutton == 0) then
			actionbutton = ButtonAction.ACTION_MENUCONFIRM
		end
	elseif (Input.IsActionPressed(ButtonAction.ACTION_PILLCARD,player.ControllerIndex)) then
		if (actionbutton == 0) then
			actionbutton = ButtonAction.ACTION_PILLCARD
		end
	elseif (Input.IsActionPressed(ButtonAction.ACTION_BOMB,player.ControllerIndex)) then
		if (actionbutton == 0) then
			actionbutton = ButtonAction.ACTION_BOMB
		end
	else
		actionbutton = 0
	end
	-- directions
	if Input.IsActionPressed(ButtonAction.ACTION_DOWN,player.ControllerIndex) then
		if (buttonpressed == false) then
			if verso == true then
				selectionline = math.min(maxlines,selectionline+1)
			else
				selPos = Vector(selPos.X, math.min(3,selPos.Y+1))
			end
			buttonpressed = true
			playsound = true
		end
	elseif Input.IsActionPressed(ButtonAction.ACTION_UP,player.ControllerIndex)  then
		if (buttonpressed == false) then
			if verso == true then
				selectionline = math.max(beginlines,selectionline-1)
			else
				selPos = Vector(selPos.X, math.max(0,selPos.Y-1))
			end
			buttonpressed = true
			playsound = true
		end
	elseif Input.IsActionPressed(ButtonAction.ACTION_RIGHT,player.ControllerIndex) then
		if (buttonpressed == false) then
			if verso == true then
				verso = false
				phase = 1
			elseif (selPos.X == 3 and pageUI < maxpagesUI) then
				SFXManager():Play(8,0.5,0,false,1)
				pageUI = pageUI + 1
				selPos.X = 0
				phase = 2
			else                 -- inventaire
				selPos = Vector(math.min(3,selPos.X+1), selPos.Y)
			end
			buttonpressed = true
			playsound = true
		end
	elseif Input.IsActionPressed(ButtonAction.ACTION_LEFT,player.ControllerIndex) then
		if (buttonpressed == false) then
			if verso == true then
				selectionline = 3
			elseif (selPos.X == 0 and pageUI > 1) then
				SFXManager():Play(8,0.5,0,false,1)
				pageUI = pageUI - 1
				selPos.X = 3
				phase = 2
			elseif (selPos.X == 0) then
				verso = true
			else
				selPos = Vector(math.max(0,selPos.X-1), selPos.Y)
			end
			buttonpressed = true
			playsound = true
		end
	elseif Input.IsActionPressed(ButtonAction.ACTION_SHOOTDOWN,player.ControllerIndex) and actionbutton == 0 then
		if (buttonpressed == false) then
			if verso == true then
				selectionline = math.min(maxlines,selectionline+14)
			end
			buttonpressed = true
			playsound = true
		end
	elseif Input.IsActionPressed(ButtonAction.ACTION_SHOOTUP,player.ControllerIndex) and actionbutton == 0 then
		if (buttonpressed == false) then
			if verso == true then
				selectionline = math.max(3,selectionline-14)
			end
			buttonpressed = true
			playsound = true
		end
	elseif Input.IsActionPressed(ButtonAction.ACTION_SHOOTLEFT,player.ControllerIndex) and actionbutton == 0 then
		if (buttonpressed == false) then
			if verso == false and pageUI > 1 then
				pageUI = pageUI - 1
				phase = 2
			end
			buttonpressed = true
			playsound = true
		end
	elseif Input.IsActionPressed(ButtonAction.ACTION_SHOOTRIGHT,player.ControllerIndex) and actionbutton == 0 then
		if (buttonpressed == false) then
			if verso == false and pageUI < maxpagesUI then
				pageUI = pageUI + 1
				phase = 2
			end
			buttonpressed = true
			playsound = true
		end
	else
		buttonpressed = false
	end
	if playsound == true then
		dressingEnt:ToNPC():PlaySound(282,1,0,false,1)
		playsound = false
		validation = false
	end
	-- repetition boutons
	if oldbutton == false and buttonpressed == true then
		buttonTimer = Isaac.GetPlayer(0).FrameCount + 3
	end
	if buttonTimer > 0 and buttonTimer < Isaac.GetPlayer(0).FrameCount then
		buttonpressed = false
		buttonTimer = 0
	end
end
---------------------------------------------------------------------------------------------
function OWR.RenderUI()
    local hunterInput = actionbutton
    local hunterRebuild = (phase == 1)
    if player and HunterWardrobe178 and HunterWardrobe178.isHunter(player) then
        HunterWardrobe178.visibility(player, nocostume, transfo)
    end
	local	firstitem = 1
	local	configItem

	if (dressingEnt == nil) or (dressingEnt:Exists() == false) then
		return
	end
	-- mode list ?
	if (verso == true) and (phase > -1) then
		RenderList()
		return
	end

	-- compte les items du joueur
	if (phase == 0) then 
		for k,v in pairs(itemtable) do itemtable[k]=nil end -- efface la table
		-- ajoute les costumes favoris
		if gubed == false and unlockall == false then
			favnum = 0
			for k, v in pairs(favcostume) do
				table.insert(itemtable, k)
				favnum = favnum + 1
			end
			-- ajoute les items equipes
			for i = 1, maxitems do
				--fix for some chars
				itemconf = Isaac.GetItemConfig()
				configItem = itemconf:GetCollectible(i)
				--fix for some chars
				if (configItem ~= nil) and (player:HasCollectible(i)) and (favcostume[i] == nil) then
					table.insert(itemtable, i)
				end
			end
		else
			for i = 1, maxitems do
				itemconf = Isaac.GetItemConfig()
				configItem = itemconf:GetCollectible(i)
				if (configItem ~= nil) then
					table.insert(itemtable, i)
				end
			end
		end
		phase = 1
	-- prépare les items
	elseif (phase == 1) then
		flyingcostumes = 0
		totalcostumes = 0
		savedata = ""

		-- met à jour la table des transfos
		totalforms = 0
		for k, v in pairs(form) do
			if player:HasPlayerForm(k) then
				if (v == NullItemID.ID_GUPPY or v == NullItemID.ID_LORD_OF_THE_FLIES or v == NullItemID.ID_ANGEL or v == NullItemID.ID_EVIL_ANGEL) then
					if (transfo[v] == nil) then  -- init
						transfo[v] = 3       -- équipe costume vol
					elseif (transfo[v] == 2) then
						savedata = savedata..string.format("%04d",v + 9000) -- costume off : on le marque
					end
					if (transfo[v] ~= 2) then 
						flyingcostumes = flyingcostumes + 1 -- ajoute un costume vol si équipé
					end 
				elseif (transfo[v] == nil) then  -- init
					transfo[v] = 1           -- pas transfo vol, on equipe
				elseif (transfo[v] == 0) then
					savedata = savedata..string.format("%04d",v + 8000) -- costume off : on le marque
				end
				totalforms = totalforms + 1
				transfocostume[totalforms] = v -- stock le costume
			else
				transfo[v] = nil -- enleve la transfo
			end
		end

		-- liste des items passifs
		local	itemconf
		for k,v in pairs(iteminfos) do iteminfos[k]=nil end -- efface la table
		-- rempli
		for k, v in pairs(itemtable) do
			
			itemconf = Isaac.GetItemConfig()
			configItem = itemconf:GetCollectible(v)		

			if (configItem.Costume.ID > 0) --[[and (configItem.Type ~= ItemType.ITEM_ACTIVE) ]] then -- costume présent et item passif
				table.insert(iteminfos, configItem)
				totalcostumes = totalcostumes + 1
				
				if nocostume[v] == true then                -- pas de costume ici
					player:RemoveCostume(configItem)
				elseif (configItem.Costume.IsFlying) then
					flyingcostumes = flyingcostumes + 1 -- compte le nombre de costumes de vol équipés
				--	player:AddCostume(configItem,false)
				else
				--	player:AddCostume(configItem,false)
				end
				
			end
		end
		phase = 2
		-- calcul du nombre de page
		maxpagesUI = math.max(1, math.ceil((totalcostumes+totalforms) / 16))
	-- prépare les visuels des items
	elseif (phase == 2) then
		-- remplace les icones par ceux des items
		firstitem = 1 + ((pageUI-1) * 16)

		for i=0, 15 do
			if i+firstitem <= totalforms then
				invUI:ReplaceSpritesheet(i, "/gfx/ui/BoxIcon.png")
			elseif iteminfos[i-totalforms+firstitem] ~= nil then
				invUI:ReplaceSpritesheet(i, iteminfos[i-totalforms+firstitem].GfxFileName)
			else
				invUI:ReplaceSpritesheet(i, "/gfx/ui/DefautIcon.png")
			end
		end
		invUI:LoadGraphics()
		phase = 3
	-- phase de séléection
	elseif (phase == 3) then
		selection = selPos.Y*4 + selPos.X + 1 + ((pageUI-1) * 16) - totalforms

		if (actionbutton == ButtonAction.ACTION_MENUCONFIRM) then
			if selection <= 0 then -- une transfo
				local form = transfocostume[selection+totalforms]
				if transfo[form] == 3 then 
					if (flyingcostumes > 1) then -- dernier costume de vol
						transfo[form] = 2 -- desactive fly form
						player:TryRemoveNullCostume(form)
						flyingcostumes = flyingcostumes - 1
					end
				elseif transfo[form] == 2 then
					transfo[form] = 3 -- active fly form
					player:AddNullCostume(form)
					flyingcostumes = flyingcostumes + 1
				elseif transfo[form] == 1 then
					transfo[form] = 0
					player:TryRemoveNullCostume(form)
				elseif transfo[form] == 0 then
					transfo[form] = 1
					player:AddNullCostume(form)
				end
                HunterBridge("form", {id=form, visible=(transfo[form]==1 or transfo[form]==3)})
				phase = 1
				actionbutton = -1
				dressingEnt:ToNPC():PlaySound(283,1,0,false,1)
			elseif selection > totalcostumes then
				--rien
			elseif (iteminfos[selection].Costume.ID) then
				if nocostume[iteminfos[selection].ID] == true then -- réactive le costume
					nocostume[iteminfos[selection].ID] = nil
					player:AddCostume(iteminfos[selection],false)
				else -- désactive le costume
					if (iteminfos[selection].Costume.IsFlying == true) then
						if (flyingcostumes <= 1) then -- dernier costume de vol
						else
							flyingcostumes = flyingcostumes - 1
							nocostume[iteminfos[selection].ID] = true
							player:RemoveCostume(iteminfos[selection])
						end
					else
						nocostume[iteminfos[selection].ID] = true
						player:RemoveCostume(iteminfos[selection])
					end
				end
                HunterBridge("item", {id=iteminfos[selection].ID, visible=not nocostume[iteminfos[selection].ID]})
				phase = 1
				actionbutton = -1
				dressingEnt:ToNPC():PlaySound(283,1,0,false,1)
			end
		elseif (actionbutton == ButtonAction.ACTION_PILLCARD) then
			if (selection > 0) and (selection <= totalcostumes) then -- uniquement un item passif
				if (iteminfos[selection].ID) and (iteminfos[selection].Costume.IsFlying == false) then
					if (favcostume[iteminfos[selection].ID] == nil) then
						if (favnum < maxfav) then
							favcostume[iteminfos[selection].ID] = true
							favnum = favnum + 1
						end
					else
						favcostume[iteminfos[selection].ID] = nil
						favnum = favnum - 1
					end
				end
			end
			actionbutton = -1
		elseif (actionbutton == ButtonAction.ACTION_BOMB) then
            HunterBridge("clear")
			for k, v in pairs(iteminfos) do
				if (iteminfos[k].Costume.IsFlying == false) then
					nocostume[HunterBridge("isHunter") and iteminfos[k].ID or iteminfos[k].Costume.ID] = true
				end
			end
			phase = 1
			actionbutton = -1
		end
	end

    if player and HunterWardrobe178 and HunterWardrobe178.isHunter(player) then
        HunterWardrobe178.visibility(player, nocostume, transfo)
        if hunterInput > 0 or hunterRebuild then HunterBridge("refresh") end
    end
	if (phase > -1) then
		DrawUI() -- dessine l'UI
	end
end
---------------------------------------------------------------------------------------------
function OWR.UpdateWardrobe(entity)
	--player = Isaac.GetPlayer(0)
	local	entities = Isaac.GetRoomEntities()
	local	dist = 0

	if dressingEnt == nil then
		return
	end

	if (phase > -1) then -- déjà dans un menu
		Game().TimeCounter = pausetimer
		Game().BlueWombParTime = Game().BlueWombParTime + 1
		Game().BossRushParTime = Game().BossRushParTime + 1
		UpdateUI()
		return
	elseif exittimer > 0 then
		exittimer = exittimer - 1
		if exittimer <= 0 then
			for i = 1, Game():GetNumPlayers() do
				Isaac.GetPlayer(i-1).ControlsEnabled = true
			end
		end
	end

	if (maxitems == 0) then -- init
		maxitems = Isaac.GetItemConfig():GetCollectibles().Size-1
	end

	-- check distance avec joueur
	for i = 1, Game():GetNumPlayers() do
		player = Isaac.GetPlayer(i-1)
		dist = dressingEnt.Position:Distance(player.Position)

		if (dist < 25) and (shortrange == false) then
			-- load sprites
			if invUI == nil then
				invUI = Sprite()
				invUI:Load("/gfx/ui/WardrobeUI.anm2",true)
			end
			if selUI == nil then
				selUI = Sprite()
				selUI:Load("/gfx/ui/inventorySelect.anm2",true)
			end
			--------
			player.Position = dressingEnt.Position + Vector(0,30)
			player.Velocity = Vector(0,0)
			-- déplace les familiers aussi
			for i = 1, #entities do
				if (entities[i].Type == 3) then
					entities[i].Position = dressingEnt.Position + Vector(0,-20)
					entities[i].Velocity = Vector(0,0)
				end
			end
			
			for j = 1, Game():GetNumPlayers() do
				Isaac.GetPlayer(j-1).ControlsEnabled = false
			end
			
			s = dressingEnt:GetSprite()
			if destroyed == false then
				s:Play("Use",true)
			end
			Isaac.Spawn(1000,15,0,player.Position, Vector(0,0), player)
			dressingEnt:ToNPC():PlaySound(36,0.7,0,false,1.4) -- open
			shortrange = true
			phase = 0
			verso = false
			actionbutton = 0
			selPos = Vector(0,0)
			selection = 1
			pageUI = 1
			buttonpressed = true
			selectionline = 3
			CreateCostumesList()
			pausetimer = Game().TimeCounter
			pausetimer2 = Game().BlueWombParTime
			pausetimer3 = Game().BossRushParTime
			return
		elseif (dist > 40) then
			shortrange = false
		end
	end
end
---------------------------------------------------------------------------------------------
local function SpawnOldCarpet(pos)
	if WardrobePlus ~= nil then
		local carpet = Isaac.GetEntityTypeByName("Old Carpet")
		local carpetVar = Isaac.GetEntityVariantByName("Old Carpet")
		local oldcarpet = Isaac.Spawn(carpet,carpetVar,0,pos, Vector(0,0), Isaac.GetPlayer(0))
		oldcarpet:AddEntityFlags(EntityFlag.FLAG_RENDER_FLOOR)
	end
end
---------------------------------------------------------------------------------------------
function OWR.InitWardrobe()
	local	room = Game():GetRoom()

	if (Game():IsGreedMode() == false and Game():GetLevel():GetCurrentRoomIndex() == Game():GetLevel():GetStartingRoomIndex())
	or (Game():IsGreedMode() == true  and Game():GetLevel():GetCurrentRoomIndex() == 98)                                  -- Greed mode, piece 98 (Tresor ouvert)
	or (Game():IsGreedMode() == false and Game():GetLevel():GetCurrentRoomIndex() == 97 and Game():GetLevel():GetStage() == 9) then -- level 9, piece 97
		phase = -1
		local ent = Isaac.FindByType(meuble, meubleVar)
		if #ent > 0 then
			dressingEnt = ent[1]
			SpawnOldCarpet(dressingEnt.Position)
			if destroyed == true then
				local s = dressingEnt:GetSprite()
				s:Play("Destroyed",true)
			end
			return
		end

		if (dressingEnt == nil) or (dressingEnt:Exists() == false) then
			if Game():IsGreedMode() == true then
				dressingEnt = Isaac.Spawn(meuble,meubleVar,0,room:GetGridPosition(25), Vector(0,0), Isaac.GetPlayer(0));
			else
				dressingEnt = Isaac.Spawn(meuble,meubleVar,0,room:GetGridPosition(26), Vector(0,0), Isaac.GetPlayer(0));
			end
			SpawnOldCarpet(dressingEnt.Position)
			dressingEnt.DepthOffset = 2
			dressingEnt:AddEntityFlags(EntityFlag.FLAG_NO_STATUS_EFFECTS)
			dressingEnt:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
			local s = dressingEnt:GetSprite()
			s:Play("Idle",true)
			destroyed = false
		end
	else
		dressingEnt = nil
	end
end
---------------------------------------------------------------------------------------------
local function DamageWardrobe(p1, p2, p3, flags, p4)
	if dressingEnt ~= nil then
		if (flags & DamageFlag.DAMAGE_EXPLOSION) ~=0 then
			local s = dressingEnt:GetSprite()
			s:Play("Hit",true)
			destroyed = true
		end
		return false
	end
end
OWR:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, DamageWardrobe, meuble)
------------------------------------------------------------------------
local function onStart(_,bool)
	if bool == false then
		destroyed = false
		Game().BlueWombParTime = 54000
		Game().BossRushParTime = 36000
	end
	LoadCostumeData(bool)
	-- costumes de base
	if (WardrobePlus == nil) then
		OWR.AddCostumeToList("y016", "Christmas Hat", "16", false)
		OWR.AddCostumeToList("WoHat", "Working Hat", "gfx/characters/costume_WIP.anm2",false)
	else
		OWRP.AddNewCostume("y016", "Christmas Hat", "16", false, false)
		OWRP.AddNewCostume("WoHat", "Working Hat", "gfx/characters/costume_WIP.anm2",false,false)
	end
end
OWR:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, onStart)
-------------------------------------------------------------------------
function OWR:OnCommand(cmd, params)
	if string.lower(cmd) == "freecostumes" then
		if unlockall == false then
			unlockall = true
			print("Show all item costumes on wardrobe.")
		else
			unlockall = false
			print("Hide all item costumes on wardrobe.")
		end
	end
end
OWR:AddCallback(ModCallbacks.MC_EXECUTE_CMD, OWR.OnCommand)
-------------------------------------------------------------------------
local function onExit(_,bool)
    for k,v in pairs(nocostume) do nocostume[k]=nil end -- efface la table
    for k,v in pairs(favcostume) do favcostume[k]=nil end -- efface la table
    for k,v in pairs(paintname) do paintname[k]=nil end -- efface la table
    maxpaint = 0
end
OWR:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, onExit)
OWR:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, OWR.InitWardrobe)
OWR:AddCallback(ModCallbacks.MC_NPC_UPDATE, OWR.UpdateWardrobe, meuble)
OWR:AddCallback(ModCallbacks.MC_POST_RENDER, OWR.RenderUI)


