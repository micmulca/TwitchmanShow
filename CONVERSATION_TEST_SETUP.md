# Conversation Simulation Test Environment Setup

This guide will help you set up and run the conversation simulation test environment for the TwitchMan Show project using your local LLM model.

## Prerequisites

### 1. LM Studio Setup
- **Download LM Studio**: Get the latest version from [https://lmstudio.ai/](https://lmstudio.ai/)
- **Install and Launch**: Install LM Studio and launch the application
- **Load Your Model**: 
  - Go to the "Local Models" tab
  - Search for and download: `TheBloke/OpenHermes-2.5-Mistral-7B-GGUF`
  - Click "Load" to start the model
- **Start Local Server**: 
  - Go to the "Local Server" tab
  - Click "Start Server"
  - Ensure it's running on `http://localhost:1234`

### 2. Godot Setup
- **Godot Version**: Ensure you're using Godot 4.x
- **Project**: Open the TwitchMan Show project in Godot
- **Dependencies**: All required scripts should be in place

## Running the Test

### Method 1: Using the Test Scene (Recommended)

1. **Open the Test Scene**:
   - In Godot, open `test_conversation_simulation.tscn`
   - This will load the test environment automatically

2. **Use the Test UI**:
   - **Start Conversation Test**: Begins a 10-turn conversation between Fen Barrow and Elias Thorn
   - **Stop Test**: Stops the current test
   - **Check LLM Health**: Verifies connection to your local LLM
   - **Show Conversation Log**: Displays the conversation history
   - **Show Environment**: Displays comprehensive environmental context
   - **Show Participants**: Displays current participants and available characters

3. **Monitor the Console**:
   - Watch the Godot console for detailed output
   - See each turn being processed
   - Monitor LLM requests and responses

### Method 2: Using Console Commands

If you have a console system in place, you can use these commands:

```bash
# Start a conversation test
start_test

# Start test with specific characters
start_test fen_barrow elias_thorn

# Stop the current test
stop_test

# Check LLM health
health

# Show conversation log
log

# Show environmental context
environment

# Show participant information
participants

# Force a character to join the conversation
join <character_id>

# Force a character to leave the conversation
leave <character_id>
```

## Test Configuration

The test environment is configurable through the script variables:

```gdscript
# Test characters (default: Fen Barrow and Elias Thorn)
var test_characters: Array[String] = ["fen_barrow", "elias_thorn"]

# Available conversation topics
var conversation_topics: Array[String] = ["weather", "work", "local_news", "hobbies", "food"]

# Maximum conversation length
var max_conversation_turns: int = 10

# Delay between turns (in seconds)
var turn_delay: float = 2.0
```

## Expected Output

When running successfully, you should see:

```
=== TwitchMan Conversation Simulation Test Environment ===
LLM Model: TheBloke/OpenHermes-2.5-Mistral-7B-GGUF
Local URL: http://localhost:1234/v1

--- Checking LLM Health ---
✓ LLM is healthy and available
✓ Test UI created
=== Test environment ready ===

=== Starting Conversation Simulation ===
✓ Started conversation: group_1234567890_12345
  Participants: ["fen_barrow", "elias_thorn"]
  Initial topic: weather

--- Starting Conversation Turns ---

--- Turn 1 ---
Environment: Weather: Partly cloudy with a gentle southwest breeze | Time: 14:45 (afternoon) | Season: Autumn
Participants: Fen Barrow, Elias Thorn
Next speaker: Fen Barrow (fen_barrow)
Generating dialogue for Fen Barrow...
  LLM request sent: req_1
  Fen Barrow: "The light's changing as those clouds roll in. Makes the beacon even more important for navigation."

--- Turn 2 ---
Environment: Weather: Overcast with moderate winds | Time: 15:00 (afternoon) | Season: Autumn | Events: weather (overcast)
Participants: Fen Barrow, Elias Thorn
  🟢 Maren Thorn joins the conversation!
Next speaker: Elias Thorn (elias_thorn)
Generating dialogue for Elias Thorn...
  LLM request sent: req_2
  Elias Thorn: "Overcast weather can be tricky for fishing, but the fish are still biting."

--- Turn 3 ---
Environment: Weather: Light rain with gusty winds | Time: 15:15 (afternoon) | Season: Autumn | Events: social (character_joined)
Participants: Fen Barrow, Elias Thorn, Maren Thorn
  🔴 Maren Thorn leaves the conversation.
Next speaker: Fen Barrow (fen_barrow)
Generating dialogue for Fen Barrow...
  LLM request sent: req_3
  Fen Barrow: "The rain's making the coastal path slippery. I've been extra careful on my rounds."
```

## Troubleshooting

### LLM Connection Issues

**Problem**: "LLM is not available" error
**Solutions**:
1. Ensure LM Studio is running
2. Check that the server is started on port 1234
3. Verify the model is loaded: `TheBloke/OpenHermes-2.5-Mistral-7B-GGUF`
4. Check firewall settings

**Problem**: Connection timeout
**Solutions**:
1. Increase `request_timeout` in `LLMClient.gd`
2. Check if your model is too large for your hardware
3. Try reducing `max_tokens` in the LLM request

### Character Data Issues

**Problem**: Characters not found
**Solutions**:
1. Ensure character JSON files exist in `data/characters/`
2. Check file permissions
3. Verify JSON syntax is valid

### Performance Issues

**Problem**: Slow response times
**Solutions**:
1. Reduce `turn_delay` for faster conversations
2. Use a smaller/faster model variant
3. Check your hardware specifications

## Customization

### Adding New Characters

1. Create a new character JSON file in `data/characters/`
2. Follow the schema in `character_schema.json`
3. Add the character ID to `test_characters` array

### Modifying Conversation Topics

Edit the `conversation_topics` array to include topics relevant to your world:

```gdscript
var conversation_topics: Array[String] = [
    "weather", "fishing", "lighthouse_maintenance", "local_news", "village_gossip",
    "maritime_safety", "boat_upgrades", "coastal_life", "family_matters", "work_stories"
]
```

### Adjusting Test Parameters

Modify these variables for different test scenarios:

```gdscript
# For longer conversations
var max_conversation_turns: int = 20

# For faster-paced tests
var turn_delay: float = 1.0

# For different character combinations
var test_characters: Array[String] = ["fen_barrow", "elias_thorn", "alice"]
```

## Advanced Features

### Real-time LLM Integration

The test environment is designed to work with real LLM responses. Currently, it simulates responses for testing purposes, but you can:

1. Modify `simulate_llm_response()` to handle real LLM responses
2. Connect to the `llm_response_received` signal from `LLMClient`
3. Process actual generated dialogue from your model

### Environmental Context System

The test environment now includes a comprehensive environmental context system that makes conversations more immersive:

#### **Weather System**
- **Dynamic Weather**: Weather changes every few turns (30% chance per turn)
- **Weather Types**: sunny, partly_cloudy, overcast, light_rain, stormy, fog_rolling_in
- **Weather Effects**: Temperature, wind speed/direction, humidity, visibility, pressure
- **Character Comfort**: Each character's location has unique comfort factors affected by weather

#### **Location System**
- **Fen Barrow**: Lighthouse Point (elevated, windy, isolated)
- **Elias Thorn**: Fisherman's Dock (waterfront, busy, working environment)
- **Environmental Effects**: Each location has unique atmosphere, nearby objects, and comfort factors
- **Dynamic Comfort**: Temperature, wind chill, humidity, noise levels, lighting conditions

#### **Time System**
- **Progressive Time**: Time advances 15 minutes each conversation turn
- **Time of Day**: morning, afternoon, evening, night
- **Seasonal Context**: autumn setting with appropriate weather patterns
- **Day of Week**: Wednesday with community events

#### **World Events**
- **Dynamic Events**: New events appear during conversations (20% chance per turn)
- **Event Types**: weather, maritime, community events
- **Relevance System**: Events have relevance scores that affect conversation topics
- **Impact Tracking**: Events affect fishing conditions, lighthouse visibility, community activities

### Dynamic Character Management System

The test environment now features a sophisticated character entry and exit system that makes conversations feel like living, breathing social interactions:

#### **Automatic Character Discovery**
- **Directory Scanning**: Automatically discovers all characters in `data/characters/`
- **Character Loading**: Loads character data, personalities, schedules, and relationships
- **Dynamic Population**: No need to manually specify which characters can participate

#### **Intelligent Join Decisions**
Characters automatically decide whether to join conversations based on:

**Personality Factors:**
- **Extraversion**: Outgoing characters are more likely to join
- **Openness**: Curious characters join diverse conversations
- **Social Energy**: Characters with high social needs seek interaction

**Contextual Factors:**
- **Group Size**: Smaller groups are more inviting
- **Topic Relevance**: Characters join conversations about their interests/occupation
- **Recent Events**: World events increase social activity
- **Environmental Conditions**: Weather and time affect willingness to socialize

**Relationship Factors:**
- **Friendship Strength**: Characters join conversations with friends
- **Family Ties**: Family members are more likely to join together
- **Shared Interests**: Similar characters naturally gravitate together

**Schedule Factors:**
- **Sleep Patterns**: Characters don't join during sleep hours
- **Work Commitments**: Working characters have reduced availability
- **Meal Times**: Characters are more social around meal times
- **Activity Preferences**: Some times of day are more social than others

#### **Natural Exit Conditions**
Characters leave conversations when:

**Schedule Conflicts:**
- **Sleep Time**: Characters leave when it's time to sleep
- **Work Time**: Characters leave to attend to work duties
- **Meal Times**: Characters leave for meals or food preparation

**Social Factors:**
- **Boredom**: Characters leave when conversation becomes uninteresting
- **Discomfort**: Characters leave when environmental conditions worsen
- **Introversion**: Shy characters need quiet time to recharge
- **Group Size**: Some characters prefer smaller, more intimate conversations

**Personal Needs:**
- **Energy**: Tired characters leave to rest
- **Hunger/Thirst**: Characters leave to attend to physical needs
- **Privacy**: Some characters need alone time

#### **Realistic Behavior Patterns**
- **No Forced Participation**: Characters can't be forced to stay in conversations
- **Natural Flow**: Entries and exits happen organically based on character needs
- **Relationship Dynamics**: Character interactions affect future join/leave decisions
- **Environmental Awareness**: Weather and time influence social behavior
- **Topic Sensitivity**: Characters join conversations relevant to their lives

#### **Character Relationship System**
- **Relationship Strength**: Tracks friendship levels between all characters
- **Shared Characteristics**: Similar ages, occupations, and interests strengthen bonds
- **Family Connections**: Family members have stronger relationships
- **Dynamic Evolution**: Relationships can change based on interaction quality
- **Social Networks**: Characters influence each other's social decisions

### Conversation Memory

The system tracks:
- Turn-by-turn conversation flow
- Topic changes and reasons
- Participant mood shifts
- Relationship effects
- Environmental context for each turn

### Event System Integration

The test environment integrates with the EventBus system:
- World events can influence conversations
- NPC actions are logged
- Mood and relationship changes are tracked

## Next Steps

Once you have the basic test environment working:

1. **Test with Real LLM Responses**: Modify the code to use actual LLM output
2. **Add More Characters**: Create additional character profiles
3. **Expand Topics**: Add more sophisticated conversation topics
4. **Test Edge Cases**: Try different conversation scenarios
5. **Performance Testing**: Monitor system performance with longer conversations

## Support

If you encounter issues:

1. Check the console output for error messages
2. Verify all prerequisites are met
3. Check the Godot debugger for script errors
4. Ensure your LLM model is compatible with the API format

The test environment is designed to be robust and provide clear feedback about what's working and what needs attention.
