import "geom"

local snd = playdate.sound

Ambience = {}

local aboveChannel, belowChannel
local hum1, hum2, lap, ping, gull, splash, chime
local pingClock = 4
local gullClock = 6
local lapPhase = 0

function Ambience.init()
    -- Below the surface: two detuned sines beating slowly, low-passed to a hum.
    -- Pitched at 110 Hz (not lower) so the device's small speaker can voice it.
    belowChannel = snd.channel.new()
    local belowFilter = snd.twopolefilter.new(snd.kFilterLowPass)
    belowFilter:setFrequency(320)
    belowChannel:addEffect(belowFilter)
    hum1 = snd.synth.new(snd.kWaveSine)
    hum2 = snd.synth.new(snd.kWaveSine)
    belowChannel:addSource(hum1)
    belowChannel:addSource(hum2)
    hum1:playNote(110, 0.25)      -- no length: sustains until noteOff
    hum2:playNote(112, 0.18)

    -- Above: filtered noise as wave wash, swelled from update().
    aboveChannel = snd.channel.new()
    local aboveFilter = snd.twopolefilter.new(snd.kFilterLowPass)
    aboveFilter:setFrequency(900)
    aboveChannel:addEffect(aboveFilter)
    lap = snd.synth.new(snd.kWaveNoise)
    aboveChannel:addSource(lap)
    lap:playNote(220, 0.2)
    gull = snd.synth.new(snd.kWaveSquare)
    gull:setADSR(0.02, 0.1, 0.3, 0.15)
    aboveChannel:addSource(gull)

    -- One-shots on the default channel so the bed filters don't muffle them.
    ping = snd.synth.new(snd.kWaveSine)
    ping:setADSR(0.001, 0.4, 0, 0.3)
    splash = snd.synth.new(snd.kWaveNoise)
    splash:setADSR(0.005, 0.25, 0, 0.1)

    chime = snd.synth.new(snd.kWaveSquare)
    chime:setADSR(0.005, 0.15, 0.4, 0.2)
end

function Ambience.update(dt)
    local mix = Geom.crossfadeMix(Scope.height)
    aboveChannel:setVolume(mix * 0.8)
    belowChannel:setVolume((1 - mix) * 0.75)

    -- Slow, layered swell so the noise bed laps rather than hisses.
    -- (Base exceeds the sine amplitudes so the volume never goes negative.)
    lapPhase = lapPhase + dt
    lap:setVolume(0.16 + 0.1 * math.sin(lapPhase * 0.9)
        + 0.05 * math.sin(lapPhase * 2.3))

    pingClock = pingClock - dt
    if pingClock <= 0 and mix < 0.4 then
        ping:playNote(1100, 0.25, 0.5)
        pingClock = 6 + math.random() * 4
    end

    gullClock = gullClock - dt
    if gullClock <= 0 and mix > 0.6 then
        local now = snd.getCurrentTime()
        gull:playNote(1350, 0.18, 0.12, now)
        gull:playNote(1080, 0.15, 0.2, now + 0.15)
        gullClock = 8 + math.random() * 6
    end

    if Scope.surfacedNow then
        splash:playNote(400, 0.4, 0.25)
    end

    if Spy.foundNow then
        local now = snd.getCurrentTime()
        chime:playNote(1500, 0.15, 0.12, now)
        chime:playNote(2000, 0.15, 0.18, now + 0.1)
    end
end
