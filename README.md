# Intro

Forzassist is a Python drift-assist tool for Forza Horizon 6 inspired by CarX Drift Racing Online. It reads Forza's UDP telemetry and provides countersteering through a virtual Xbox controller.

## Why I Made This

I used to play CarX Drift Racing Online for a long time, and I always liked how good drifting felt on controller. The assist in that game made drifting smooth, consistent, and natural without forcing controller players to fight the stick.

When I came back to Forza shortly after Forza 6 came out, I immediately remembered what I disliked about drifting in Forza, constantly tapping the stick left and right to countersteer. It worked, but it looked ugly and felt bad compared to what I was used to. I played and drifted a lot in Forza Horizon 5, and I did get used to it, but knowing I would have to go back to stick tapping again in Forza Horizon 6 made me want to seek a solution.

Looking back, I had no idea what I was getting into. I did not know Python, I barely understood the math involved, and I didn't even know what the word "telemetry" meant. The small and pretty useless ideas i first had somehow turned into a two week journey of trying to build a drift assist i didn't even know was possible. 

I spent days and nights testing, breaking things, tuning values, and rebuilding the logic from scratch, and since i have absolutely ZERO coding knowledge (and i suck at math), this was obviously achieved with the help of AI tools like Claude, Cursor, and ChatGPT. And so what started as a basic idea became a full assist that helps make drifting on a controller a lot more intuitive.
## How does it work?

- Reads Forza telemetry over UDP
- Uses slip angle and yaw rate to calculate assisted steering
- Outputs to a virtual Xbox 360 controller using `vgamepad`

## Installation Methods (wip)

