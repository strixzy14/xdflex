local discordLink = "https://discord.gg/paWWE2nZzf"

if setclipboard then
    setclipboard(discordLink)
elseif toclipboard then
    toclipboard(discordLink)
end

pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "[xdflex hub]",
        Text = "Get new loader on Discord! (Copied to Clipboard)",
        Duration = 10
    })
end)

local player = game:GetService("Players").LocalPlayer
if player then
    player:Kick("\n\n[xdflex hub]\n\n❌ This loader is outdated!\nPlease get the new loader on our Discord.\n\n📋 (Discord link has been copied to your clipboard!)\n" .. discordLink)
end
