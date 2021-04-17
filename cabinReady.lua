-- CabinReady lua script
-- Simulates an automatic cabin ready signal in Toliss A319 and Toliss A321 for X-Plane (tested with 11.x)
--
-- Feel free to modify the script by yourself.
-- Ping me if you improoved it ;)
--

-- Set to 1 to see two log messages, one prior TO and one while in approach. Just as a reminder and to verify that it works...
cabinReadyDebug = 1

-- Helper to see if it is a Toliss Airbus
isAirbus = false

-- Required datarefs
-- Set door and apPhase if datarefs are found only
if XPLMFindDataRef("AirbusFBW/PaxDoorArray") and  XPLMFindDataRef("AirbusFBW/APPhase") ~= nil then
	isAirbus = true
    dataref("mainDoor", "AirbusFBW/PaxDoorArray", "readonly", 0)
	dataref("apPhase", "AirbusFBW/APPhase") -- ap phases (1 = TO, 2=climb, 3=cruize, 4 descend, 5= approach, 6 = GA)
end


dataref("agl", "sim/flightmodel/position/y_agl") -- in meters
dataref("gen1", "sim/cockpit/electrical/generator_on", "readonly", 0)
dataref("gen2", "sim/cockpit/electrical/generator_on", "readonly", 1)
dataref("isMaster", "scp/api/ismaster", "readonly") -- 0 = not in use, 1 = slave, 2 = master

isReadyForDeparture = false
isReadyForApproach = false
isApproachMemoTriggered = false

cabinReadyPercent = 0
cabinReadyAltitude = 0

startTime = 0
endTime = 0

toMemoAutoAppearTime = 0

function cabinReadyApproach()
    -- Debug log
    if (cabinReadyDebug == 1 and isApproachMemoTriggered == true) then
        draw_string(10, 40, "Approach was triggered (" .. cabinReadyPercent .. "% / " .. cabinReadyAltitude .. ")")
    end

    -- 600m is slightly below 2000ft and autopilit approach phase is active
    if (isApproachMemoTriggered == false and agl < 600 and apPhase == 5) then
        math.randomseed(os.time())
        cabinReadyPercent = math.random(1, 100)
        isApproachMemoTriggered = true
        print("[CabinReady] Detect approach at: " .. os.date('%H:%M:%S', os.time()) .. " - CabinReadyPercentage is : " .. cabinReadyPercent)
    end

    -- Trigger command in 80% of the cases
    if (isApproachMemoTriggered == true and isReadyForApproach == false and cabinReadyPercent < 80) then
        command_once("AirbusFBW/purser/fwd")
        isReadyForApproach = true
        print("[CabinReady] Called Approach ready directly at: " .. os.date('%H:%M:%S', os.time()))
        -- Define random value when cabin will be ready in 15% of the cases, cabin will not be ready in 5% of the cases
    elseif (isApproachMemoTriggered == true and isReadyForApproach == false and cabinReadyPercent >= 80 and cabinReadyPercent < 95) then
        if (cabinReadyAltitude == 0) then
            math.randomseed(os.time())
            -- 70m = 230ft (CAT I approach decision is most of the time in 200ft), 555m is slightly below the 600m AGL for the trigger
            cabinReadyAltitude = math.random(70, 555)
            print("[CabinReady] Cabin will be ready at: " .. cabinReadyAltitude .. "m")
        end

        -- Trigger forward purser button if not happend
        if (cabinReadyAltitude > 0 and agl < cabinReadyAltitude) then
            command_once("AirbusFBW/purser/fwd")
            isReadyForApproach = true
            print("[CabinReady] Called Approach ready at: " .. os.date('%H:%M:%S', os.time()))
        end
    end
    -- no else or elsif as the cabin will not be ready in 5% of the approaches

    -- Reset if ap phase changes after the memo was allready triggered, e.g. on GA or after landing
    if ((apPhase ~= 5) and isApproachMemoTriggered == true) then
        isApproachMemoTriggered = false
        isReadyForApproach = false
        cabinReadyAltitude = 0
        print("[CabinReady] Reset approach trigger at: " .. os.time() .. "while apPhase was: " .. apPhase)
    end
end

function cabinReadyDeparture()
    -- Debug Log
    if (cabinReadyDebug == 1 and endTime > 0 and mainDoor == 0 and isReadyForDeparture == false and agl < 100) then
        draw_string(10, 20, "Cabin will be ready earliest " .. os.date('%H:%M:%S', endTime) .. " / TO will show at: " .. os.date('%H:%M:%S', toMemoAutoAppearTime))
    end

    -- Timer after generator started; workaround to know when both engines are running
    if (toMemoAutoAppearTime == 0 and gen1 == 1 and gen2 == 1) then
        -- TO memo will appear 2 minutes (+ some extra = 130s) after both engines are running
        toMemoAutoAppearTime = os.time() + 130
        print("[CabinReady] Detect GEN1 and GEN2 ON. TO memo appears at: ~" .. os.date('%H:%M:%S', toMemoAutoAppearTime))
    end

    -- Start timer after doors closed to wait until cabin is ready
    if (startTime == 0 and mainDoor == 0) then
        startTime = os.time()
        math.randomseed(os.time())
        -- Cabin could be ready between 5 and 10 minutes after door closed
        endTime = startTime + math.random(300, 600)
        print("[CabinReady] Detect Start at: " .. os.date('%H:%M:%S', startTime) .. " will end at " .. os.date('%H:%M:%S', endTime) .. " -- " .. (endTime - startTime) .. "s")
    end

    -- T/O memo appears at least  two minutes after engine start
    if (endTime > 0 and os.time() > endTime and isReadyForDeparture == false and toMemoAutoAppearTime > 0 and toMemoAutoAppearTime < os.time()) then
        command_once("AirbusFBW/purser/fwd")
        isReadyForDeparture = true
        print("[CabinReady] Triggered Cabin ready at time: " .. os.date('%H:%M:%S', os.time()))
    end

    -- Reset when door is open again
    if (isReadyForDeparture == true and mainDoor == 1) then
        isReadyForDeparture = false
        startTime = 0
		endTime = 0
		toMemoAutoAppearTime = 0
        print("[CabinReady] Departure reset at: " .. os.date('%H:%M:%S', os.time()))
    end
end

function mainCabinReady()
    -- isMaster == 1 means you are slave, ~= 1 menas than smartcopilot is not used or master
    if isMaster ~= 1 then
        cabinReadyDeparture()
        cabinReadyApproach()
    end
end

-- Will be executed if Toliss DataRefs exists only
if isAirbus then
	do_every_draw("mainCabinReady()")
end