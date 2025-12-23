# Debug script
room = Room.create!(game_type: "Write And Vote")
player = Player.create!(name: "Host", room:)
room.update!(host: player)
# Ensure clean state
Prompt.destroy_all
PromptPack.destroy_all
p = PromptPack.create!(name: "Standard", is_default: true, game_type: "Write And Vote")
10.times { Prompt.create!(body: "Test", prompt_pack: p) }
Player.create!(name: "P2", room:)
Player.create!(name: "P3", room:)

puts "Starting game..."
Games::WriteAndVote.game_started(room:)

game = room.reload.current_game
puts "Game Status: #{game.status}"
puts "Round Ends At: #{game.round_ends_at.inspect}"

if game.round_ends_at.present?
  puts "SUCCESS: Timer set."
else
  puts "FAILURE: Timer is nil."
end
