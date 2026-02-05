-- Time-based taglines for ascii-animation
-- Motivational, philosophical, cryptic, poetic, zen, and witty messages

local M = {}

-- Available themes
M.themes = {
  "motivational",
  "personalized",
  "philosophical",
  "cryptic",
  "poetic",
  "zen",
  "witty",
}

-- Theme display names
M.theme_names = {
  motivational = "Motivational",
  personalized = "Personalized",
  philosophical = "Philosophical",
  cryptic = "Cryptic",
  poetic = "Poetic",
  zen = "Zen",
  witty = "Witty",
}

-- Messages organized by period, each with text and theme
M.messages = {
  morning = {
    -- Motivational
    { text = "Rise and shine!", theme = "motivational" },
    { text = "New day, new code.", theme = "motivational" },
    { text = "Coffee time!", theme = "motivational" },
    { text = "Let's build.", theme = "motivational" },
    { text = "Fresh start.", theme = "motivational" },
    { text = "Seize the day!", theme = "motivational" },
    { text = "Code awaits.", theme = "motivational" },
    { text = "Morning magic.", theme = "motivational" },
    { text = "Early bird mode.", theme = "motivational" },
    { text = "New beginnings.", theme = "motivational" },
    { text = "Dawn of ideas.", theme = "motivational" },
    { text = "Wake up & code.", theme = "motivational" },
    -- Personalized (with placeholders)
    { text = "Good {time}, {name}!", theme = "personalized" },
    { text = "Welcome back to {project}.", theme = "personalized" },
    { text = "Ready to build {project}?", theme = "personalized" },
    -- Philosophical
    { text = "Today writes tomorrow's history.", theme = "philosophical" },
    { text = "The void awaits your creation.", theme = "philosophical" },
    { text = "Each dawn, a blank canvas.", theme = "philosophical" },
    { text = "Potential is infinite at sunrise.", theme = "philosophical" },
    { text = "Yesterday's bugs are today's wisdom.", theme = "philosophical" },
    { text = "The compiler of fate awaits.", theme = "philosophical" },
    -- Cryptic
    { text = "The bits align at dawn.", theme = "cryptic" },
    { text = "Silence before the storm of keystrokes.", theme = "cryptic" },
    { text = "The machine dreams of your return.", theme = "cryptic" },
    { text = "Initialize your purpose.", theme = "cryptic" },
    { text = "The cursor blinks in anticipation.", theme = "cryptic" },
    { text = "Boot sequence: humanity.", theme = "cryptic" },
    -- Poetic
    { text = "Where light meets logic.", theme = "poetic" },
    { text = "The first commit of consciousness.", theme = "poetic" },
    { text = "Dew on silicon meadows.", theme = "poetic" },
    { text = "Syntax of the rising sun.", theme = "poetic" },
    { text = "The algorithm of awakening.", theme = "poetic" },
    { text = "Compile the morning mist.", theme = "poetic" },
    -- Zen
    { text = "Empty mind, full stack.", theme = "zen" },
    { text = "The path begins with one keystroke.", theme = "zen" },
    { text = "Be water, not spaghetti code.", theme = "zen" },
    { text = "Breathe in bugs, breathe out fixes.", theme = "zen" },
    { text = "The code flows through you.", theme = "zen" },
    { text = "One with the terminal.", theme = "zen" },
    -- Witty
    { text = "May your coffee be strong and your bugs be weak.", theme = "witty" },
    { text = "sudo make me_productive.", theme = "witty" },
    { text = "git commit -m 'new day'", theme = "witty" },
    { text = "Debugging life, one sunrise at a time.", theme = "witty" },
    { text = "404: Sleep not found.", theme = "witty" },
  },

  afternoon = {
    -- Motivational
    { text = "Keep going!", theme = "motivational" },
    { text = "Stay focused.", theme = "motivational" },
    { text = "You got this!", theme = "motivational" },
    { text = "In the zone.", theme = "motivational" },
    { text = "Crushing it.", theme = "motivational" },
    { text = "Flow state.", theme = "motivational" },
    { text = "Keep building.", theme = "motivational" },
    { text = "Momentum!", theme = "motivational" },
    { text = "Make it happen.", theme = "motivational" },
    { text = "Push through.", theme = "motivational" },
    { text = "Stay sharp.", theme = "motivational" },
    { text = "Full steam ahead.", theme = "motivational" },
    -- Personalized (with placeholders)
    { text = "Good {time}, {name}!", theme = "personalized" },
    { text = "{project} awaits your code.", theme = "personalized" },
    { text = "Neovim {version} at your service.", theme = "personalized" },
    -- Philosophical
    { text = "The middle path leads to completion.", theme = "philosophical" },
    { text = "Progress over perfection.", theme = "philosophical" },
    { text = "Every keystroke echoes in eternity.", theme = "philosophical" },
    { text = "You are the architect of logic.", theme = "philosophical" },
    { text = "The journey is the destination.", theme = "philosophical" },
    { text = "Complexity yields to persistence.", theme = "philosophical" },
    -- Cryptic
    { text = "The stack deepens.", theme = "cryptic" },
    { text = "Recursion of the soul.", theme = "cryptic" },
    { text = "Between compilation and revelation.", theme = "cryptic" },
    { text = "The loop knows no fatigue.", theme = "cryptic" },
    { text = "Entropy bows to your will.", theme = "cryptic" },
    { text = "The heap of possibilities.", theme = "cryptic" },
    -- Poetic
    { text = "Sun high, spirits higher.", theme = "poetic" },
    { text = "The rhythm of productive hours.", theme = "poetic" },
    { text = "Dancing with deadlines.", theme = "poetic" },
    { text = "Symphony of syntax.", theme = "poetic" },
    { text = "Where focus meets flow.", theme = "poetic" },
    { text = "The poetry of progress.", theme = "poetic" },
    -- Zen
    { text = "Do. Or do not. There is no try-catch.", theme = "zen" },
    { text = "The bug you seek is within.", theme = "zen" },
    { text = "Patience compiles all things.", theme = "zen" },
    { text = "Mind like water, code like stream.", theme = "zen" },
    { text = "Present moment, perfect code.", theme = "zen" },
    -- Witty
    { text = "It works on my machine.", theme = "witty" },
    { text = "// TODO: Take a break", theme = "witty" },
    { text = "Powered by determination and caffeine.", theme = "witty" },
    { text = "Tabs vs spaces? Yes.", theme = "witty" },
    { text = "git push --force (just kidding).", theme = "witty" },
    { text = "console.log('still alive');", theme = "witty" },
  },

  evening = {
    -- Motivational
    { text = "Wind down.", theme = "motivational" },
    { text = "Golden hour.", theme = "motivational" },
    { text = "Almost there.", theme = "motivational" },
    { text = "Evening flow.", theme = "motivational" },
    { text = "Peaceful code.", theme = "motivational" },
    { text = "Relax & code.", theme = "motivational" },
    { text = "Sunset mode.", theme = "motivational" },
    { text = "Gentle close.", theme = "motivational" },
    { text = "Day's end magic.", theme = "motivational" },
    { text = "Wrap it up.", theme = "motivational" },
    { text = "Twilight coding.", theme = "motivational" },
    { text = "Calm focus.", theme = "motivational" },
    -- Personalized (with placeholders)
    { text = "Good {time}, {name}!", theme = "personalized" },
    { text = "Wrapping up {project}.", theme = "personalized" },
    { text = "{date} — Make it count.", theme = "personalized" },
    -- Philosophical
    { text = "Dusk teaches us to release.", theme = "philosophical" },
    { text = "Tomorrow inherits today's work.", theme = "philosophical" },
    { text = "The code rests, the mind reflects.", theme = "philosophical" },
    { text = "Endings are beginnings in disguise.", theme = "philosophical" },
    { text = "Wisdom comes with the setting sun.", theme = "philosophical" },
    { text = "The day's diff tells a story.", theme = "philosophical" },
    -- Cryptic
    { text = "The shadows compile differently.", theme = "cryptic" },
    { text = "Between day and dream.", theme = "cryptic" },
    { text = "The terminal remembers.", theme = "cryptic" },
    { text = "Twilight protocols engaged.", theme = "cryptic" },
    { text = "The cache of memories fills.", theme = "cryptic" },
    { text = "Sunset is just a merge conflict.", theme = "cryptic" },
    -- Poetic
    { text = "Amber light on tired keys.", theme = "poetic" },
    { text = "The day's last semicolon.", theme = "poetic" },
    { text = "Soft glow of accomplishment.", theme = "poetic" },
    { text = "Colors fade, code remains.", theme = "poetic" },
    { text = "The gentle art of wrapping up.", theme = "poetic" },
    { text = "Evening's tender refactor.", theme = "poetic" },
    -- Zen
    { text = "Let go of what didn't compile.", theme = "zen" },
    { text = "The day completes itself.", theme = "zen" },
    { text = "Peace in the final commit.", theme = "zen" },
    { text = "Acceptance of the day's work.", theme = "zen" },
    { text = "Release attachments to bugs.", theme = "zen" },
    { text = "The evening bell of productivity.", theme = "zen" },
    -- Witty
    { text = "git stash save 'for tomorrow'.", theme = "witty" },
    { text = "Time to rubber duck your thoughts.", theme = "witty" },
    { text = "Ctrl+S your sanity.", theme = "witty" },
    { text = "The code can wait, you can't.", theme = "witty" },
    { text = "Tomorrow's problem for tomorrow's you.", theme = "witty" },
    { text = "End of sprint energy.", theme = "witty" },
  },

  night = {
    -- Motivational
    { text = "Night mode.", theme = "motivational" },
    { text = "Silent focus.", theme = "motivational" },
    { text = "Stars & code.", theme = "motivational" },
    { text = "Midnight oil.", theme = "motivational" },
    { text = "Deep work.", theme = "motivational" },
    { text = "Night shift.", theme = "motivational" },
    { text = "Quiet hours.", theme = "motivational" },
    { text = "Nocturnal flow.", theme = "motivational" },
    { text = "Moon's up, code on.", theme = "motivational" },
    { text = "Night owl vibes.", theme = "motivational" },
    { text = "Darkness, creativity.", theme = "motivational" },
    { text = "3am thoughts.", theme = "motivational" },
    -- Personalized (with placeholders)
    { text = "Late {time}, {name}.", theme = "personalized" },
    { text = "Neovim {version} • {plugin_count} plugins loaded.", theme = "personalized" },
    { text = "The night belongs to {project}.", theme = "personalized" },
    -- Philosophical
    { text = "In darkness, we see clearly.", theme = "philosophical" },
    { text = "The void speaks in functions.", theme = "philosophical" },
    { text = "Night reveals what day conceals.", theme = "philosophical" },
    { text = "Solitude is the compiler of thought.", theme = "philosophical" },
    { text = "Stars are but distant processes.", theme = "philosophical" },
    { text = "The universe debugs itself at night.", theme = "philosophical" },
    -- Cryptic
    { text = "The daemon watches.", theme = "cryptic" },
    { text = "Shadows write in binary.", theme = "cryptic" },
    { text = "The machine never sleeps.", theme = "cryptic" },
    { text = "Midnight's memory leak.", theme = "cryptic" },
    { text = "The clock strikes undefined.", theme = "cryptic" },
    { text = "In the kernel of night.", theme = "cryptic" },
    -- Poetic
    { text = "Moonlit syntax.", theme = "poetic" },
    { text = "The hum of late-night servers.", theme = "poetic" },
    { text = "Starlight on dark themes.", theme = "poetic" },
    { text = "The nocturne of keystrokes.", theme = "poetic" },
    { text = "Dreams in monospace.", theme = "poetic" },
    { text = "The night's source code.", theme = "poetic" },
    -- Zen
    { text = "Silence is the best debugger.", theme = "zen" },
    { text = "The night asks for nothing.", theme = "zen" },
    { text = "Empty roads, clear mind.", theme = "zen" },
    { text = "One with the darkness.", theme = "zen" },
    { text = "The void is full of potential.", theme = "zen" },
    { text = "Stillness compiles faster.", theme = "zen" },
    -- Witty
    { text = "Sleep is for the weakly typed.", theme = "witty" },
    { text = "Who needs sleep? We have coffee.", theme = "witty" },
    { text = "The bugs come out at night.", theme = "witty" },
    { text = "Vampire hours, wizard code.", theme = "witty" },
    { text = "My code works at 3am. Yours?", theme = "witty" },
    { text = "Insomnia-driven development.", theme = "witty" },
    { text = "The night is dark and full of errors.", theme = "witty" },
    { text = "404: Bedtime not found.", theme = "witty" },
  },

  weekend = {
    -- Motivational
    { text = "Side projects!", theme = "motivational" },
    { text = "No meetings.", theme = "motivational" },
    { text = "Code for fun.", theme = "motivational" },
    { text = "Passion time.", theme = "motivational" },
    { text = "Freedom.", theme = "motivational" },
    { text = "Hack away!", theme = "motivational" },
    { text = "Your time.", theme = "motivational" },
    { text = "Create freely.", theme = "motivational" },
    { text = "Build dreams.", theme = "motivational" },
    { text = "Explore & learn.", theme = "motivational" },
    { text = "No deadlines.", theme = "motivational" },
    { text = "Pure joy.", theme = "motivational" },
    -- Personalized (with placeholders)
    { text = "Happy {time}, {name}!", theme = "personalized" },
    { text = "Weekend vibes in {project}.", theme = "personalized" },
    { text = "{date} — Your time to create.", theme = "personalized" },
    -- Philosophical
    { text = "Freedom is the root of creation.", theme = "philosophical" },
    { text = "Play is the highest form of research.", theme = "philosophical" },
    { text = "The soul codes without constraints.", theme = "philosophical" },
    { text = "Joy compiles without errors.", theme = "philosophical" },
    { text = "Purpose needs no permission.", theme = "philosophical" },
    { text = "Passion knows no schedule.", theme = "philosophical" },
    -- Cryptic
    { text = "The calendar lies empty.", theme = "cryptic" },
    { text = "Time bends to your will.", theme = "cryptic" },
    { text = "No watchers in the repo of life.", theme = "cryptic" },
    { text = "The sprint that never ends.", theme = "cryptic" },
    { text = "Jira tickets dissolve into mist.", theme = "cryptic" },
    { text = "The standup of one.", theme = "cryptic" },
    -- Poetic
    { text = "Untethered imagination.", theme = "poetic" },
    { text = "The canvas of free hours.", theme = "poetic" },
    { text = "Where curiosity leads.", theme = "poetic" },
    { text = "The luxury of exploration.", theme = "poetic" },
    { text = "Creativity unscheduled.", theme = "poetic" },
    { text = "The weekend's blank page.", theme = "poetic" },
    -- Zen
    { text = "Code without expectation.", theme = "zen" },
    { text = "The journey without destination.", theme = "zen" },
    { text = "No goal, pure creation.", theme = "zen" },
    { text = "Mind free, fingers fly.", theme = "zen" },
    { text = "The art of aimless building.", theme = "zen" },
    { text = "Present in the process.", theme = "zen" },
    -- Witty
    { text = "No Slack, no problem.", theme = "witty" },
    { text = "Finally, meaningful work.", theme = "witty" },
    { text = "The PR can wait till Monday.", theme = "witty" },
    { text = "Deploying happiness.", theme = "witty" },
    { text = "git checkout -b 'whatever-i-want'.", theme = "witty" },
    { text = "No code review needed.", theme = "witty" },
    { text = "Feature: doing whatever I want.", theme = "witty" },
    { text = "Main branch? Never heard of her.", theme = "witty" },
    { text = "TODO: Nothing. Absolutely nothing.", theme = "witty" },
    { text = "Work-life balance: achieved.", theme = "witty" },
  },
}

return M
