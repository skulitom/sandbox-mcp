# Sandbox MCP on the Steam Workshop

https://steamcommunity.com/sharedfiles/filedetails/?id=3839989108

[h1]Build and test Garry’s Mod contraptions with your AI assistant.[/h1]
Ask it to assemble a rover, test the wheels and save the result. Sandbox MCP gives your assistant access to props, constraints and measurements in your map. It requires the free Windows x64 companion and an AI app that supports local MCP.

[h2]Connect your game[/h2]
[olist]
[*]Subscribe to the addon. [url=https://github.com/skulitom/sandbox-mcp/releases/latest]Download and extract the companion[/url], then run [b]Setup.vbs[/b] or [b]sandbox-mcp.exe[/b].
[*]Select your AI app in the wizard and restart it. Setup options include Codex, Claude Desktop, Cursor and GitHub Copilot in VS Code. Other local stdio MCP clients can use manual setup.
[*]Start singleplayer Sandbox or host a listen server. Open [b]Q > Utilities > Sandbox MCP > Connection[/b] and click [b]Connect AI[/b].
[/olist]
Try asking, “Build a rover, leave room for the driver, test it and save the blueprint.” You can inspect the result, request a specific change or undo an edit. Blueprints restore supported parts frozen and require the same models and addons. [url=https://www.youtube.com/watch?v=30DsajKY70I]Watch the build demo[/url] · [url=https://github.com/skulitom/sandbox-mcp/blob/main/docs/INSTALL.md]Setup help[/url]

[h2]Optional integrations[/h2]
[list]
[*][url=https://steamcommunity.com/sharedfiles/filedetails/?id=160250458]Wiremod[/url] lets the assistant connect buttons, gates, thrusters and sensors and inspect their signals. [url=https://www.youtube.com/watch?v=OYWIcwcRxZA]Watch it wire a rocket[/url]
[*][url=https://steamcommunity.com/sharedfiles/filedetails/?id=3113528615]Fin 3[/url] lets it tune wings and propellers using measured lift, drag and thrust. [url=https://www.youtube.com/watch?v=vvdCXAwM8vg]Watch the flight test[/url]
[*][url=https://steamcommunity.com/sharedfiles/filedetails/?id=3841216963]FlowMod[/url] lets it connect hoses, operate valves and measure load movement on AI-built machines. [url=https://github.com/skulitom/sandbox-mcp/blob/main/docs/FLOWMOD.md]FlowMod setup and limits[/url]
[*][url=https://steamcommunity.com/sharedfiles/filedetails/?id=3845221917]Cogworks[/url] lets it mount gears, join hubs and connect shafts or belts. Ask it to turn a crank, reverse it and measure the output RPM. Update the Windows companion to 0.5.0 for the mechanical tools. [url=https://github.com/skulitom/sandbox-mcp/blob/main/docs/COGWORKS.md]Gear train example[/url]
[/list]

[h2]Host permissions[/h2]
Only the local singleplayer or listen-server host can connect. The assistant can edit its own builds and prop assemblies you explicitly grant. Screenshots and Expression 2 require separate permission. E2 starts disabled and chips compile stopped. Disconnecting revokes access. Stop any circuits you also want to shut down. Undoing code cannot reverse changes a running chip already made to the world.

Version 0.5 supports Windows x64 and local MCP clients. Dedicated servers and remote hosts are outside its scope. [url=https://github.com/skulitom/sandbox-mcp/blob/main/docs/WORKFLOWS.md]Blueprint and E2 guide[/url] · [url=https://github.com/skulitom/sandbox-mcp]MIT-licensed source[/url]
