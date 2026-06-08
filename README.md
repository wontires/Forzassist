# Intro

Forzassist is a Python drift-assist tool for Forza Horizon 6 inspired by CarX Drift Racing Online. It reads Forza's UDP telemetry and provides countersteering through a virtual Xbox controller.

It works by
- Reading Forza telemetry over UDP
- Using slip angle and yaw rate to calculate assisted steering
- Outputting it to a virtual Xbox 360 controller using `vgamepad`

# Why I Made This

I used to play CarX Drift Racing Online for a long time, and I always liked how good drifting felt on controller. The assist in that game made drifting smooth, consistent, and natural without forcing controller players to fight the stick.

When I came back to Forza shortly after Forza 6 came out, I immediately remembered what I disliked about drifting in Forza, constantly tapping the stick left and right to countersteer. It worked, but it looked ugly and felt bad compared to what I was used to. I played and drifted a lot in Forza Horizon 5, and I did get used to it, but knowing I would have to go back to stick tapping again in Forza Horizon 6 made me want to seek a solution.

Looking back, I had no idea what I was getting into. I did not know Python, I barely understood the math involved, and I didn't even know what the word "telemetry" meant. The small and pretty useless ideas i first had somehow turned into a two week journey of trying to build a drift assist i didn't even know was possible. 

I spent days and nights testing, breaking things, tuning values, and rebuilding the logic from scratch, and since i have absolutely ZERO coding knowledge (and i suck at math), this was obviously achieved with the help of AI tools like Claude, Cursor, and ChatGPT. And so what started as a basic idea became a full assist that helps make drifting on a controller a lot more intuitive.

# Installation

## First Method (Easiest)
1. Install Forzassist_Setup.exe
2. Run Forzassist
3. Press on the ⚙ icon at the top right.
4. Enable "Double-Shift Fix" and bind the in-game buttons you use to upshift and downshift.
5. Once in-game, navigate to `Settings > Hud & Gameplay > Telemetry` and enable `Data Out`, make sure to set your Data Out IP Address to 127.0.0.1 and your IP Port to 5600.
   <img width="1005" height="218" alt="image" src="https://github.com/user-attachments/assets/4fa30acb-cda8-42f9-8db7-ca66df0de491" />

6. Start the assist and enjoy!

## Second Method (Hiding your real controller only from Forza)

This method uses a tool called Special K to hide your physical controller from Forza, so Forza only reads the virtual controller created by Forzassist.

1. Install Special K found at https://www.special-k.info/
2. Open Special K / SKIF.exe
3. Add or select Forza Horizon 6.
4. Launch Forza Horizon 6 through Special K.
5. If Special K shows a compatibility warning asking to use Local Injection or SKIF, click OK.
   <img width="370" height="196" alt="image" src="https://github.com/user-attachments/assets/a2fe44b3-d3aa-4ad0-ae8f-c598275b16ef" />

6. Once the game opens, press `Ctrl + Shift + Backspace` to open the Special K control panel.
7. Go to `Input Management > Gamepad`.
8. Hide/block your real controller from the game (usually just need to disable XInput slot 0 and enable slot 1 as seen in the image)
<img width="409" height="440" alt="image" src="https://github.com/user-attachments/assets/6356edb3-aa02-46c3-844d-0ffd2a2d3bce" />

9. Close the Special K menu with `Ctrl + Shift + Backspace`.

10. Make sure your Telemetry Data Out IP Address is set to 127.0.0.1 and your IP Port to 5600 just like in the first method.

11. Run Forzassist, Start the assist and enjoy! 😄

With this method, Forza should only receive input from Forzassist’s virtual controller, which avoids double inputs from the physical controller, rendering the shifting issue obsolete.

# Is this bannable?

I cannot guarantee how Forza or Microsoft may enforce their rules, so use this at your own risk.

Forzassist does not modify game files, memory, physics, money, progression, or online data. It reads Forza's Data Out telemetry and outputs steering through a virtual controller. Method 2 uses Special K only to prevent Forza from reading the physical controller directly, so the game receives input from the virtual controller instead.
