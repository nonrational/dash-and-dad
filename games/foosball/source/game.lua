Game = { streak = 0, bestStreak = 0 }

function Game.init()
    Game.streak = 0
    local saved = playdate.datastore.read()
    Game.bestStreak = (saved and saved.bestStreak) or 0
end

function Game.onResult(result)
    if result == "goal" then
        Game.streak = Game.streak + 1
        if Game.streak > Game.bestStreak then
            Game.bestStreak = Game.streak
            playdate.datastore.write({ bestStreak = Game.bestStreak })
        end
    else
        Game.streak = 0
    end
end
