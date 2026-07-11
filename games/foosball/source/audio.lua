local snd = playdate.sound

Audio = {}

local kick, netSwish, goalChime, saveWhoosh, whiffSting

function Audio.init()
    kick = snd.synth.new(snd.kWaveSquare)
    kick:setADSR(0.001, 0.08, 0, 0.05)

    netSwish = snd.synth.new(snd.kWaveNoise)
    netSwish:setADSR(0.005, 0.2, 0, 0.15)

    goalChime = snd.synth.new(snd.kWaveSquare)
    goalChime:setADSR(0.005, 0.15, 0.4, 0.2)

    saveWhoosh = snd.synth.new(snd.kWaveNoise)
    saveWhoosh:setADSR(0.01, 0.15, 0, 0.1)

    whiffSting = snd.synth.new(snd.kWaveSquare)
    whiffSting:setADSR(0.001, 0.1, 0, 0.05)

    local crowdChannel = snd.channel.new()
    local crowdFilter = snd.twopolefilter.new(snd.kFilterLowPass)
    crowdFilter:setFrequency(450)
    crowdChannel:addEffect(crowdFilter)
    crowdChannel:setVolume(0.2)
    local crowd = snd.synth.new(snd.kWaveNoise)
    crowdChannel:addSource(crowd)
    crowd:playNote(140, 0.05) -- no length: sustains for the whole session
end

function Audio.onContact(power)
    kick:playNote(140 + power * 60, 0.4 + power * 0.3, 0.06)
end

function Audio.onResult(result)
    if result == "goal" then
        netSwish:playNote(600, 0.35, 0.2)
        goalChime:playNote(880, 0.3, 0.25)
    elseif result == "save" then
        saveWhoosh:playNote(300, 0.3, 0.15)
    elseif result == "missedBall" then
        whiffSting:playNote(180, 0.2, 0.08)
    else
        whiffSting:playNote(260, 0.2, 0.08)
    end
end
