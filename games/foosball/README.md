# Foosball Shootout

An arcade foosball shootout for [Playdate](https://play.date).

Slide left and right with the d-pad to line up with the incoming ball, then
flick the crank to strike it past the goalie. Score, and the next ball
comes; get saved or mistime it, and your streak resets. The goalie gets
tougher the longer your streak runs. Best streak is saved across sessions.

## Build

Requires the [Playdate SDK](https://play.date/dev/) at `~/Developer/PlaydateSDK`.

- `make build` — compile `Foosball.pdx`
- `make run` — build and launch in the Playdate Simulator

To play on a device, build then sideload `Foosball.pdx` via the simulator
(Device menu) or [play.date/account](https://play.date/account/).
