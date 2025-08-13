# cursor\_agent\_instructions.md

## 0) Project Context & Goals

- Build a **stream-ready autonomous world** in **Godot 4 (2D, top-down, Pokémon-style)** with characters that perceive, plan, and **socially interact** (no combat for now).
- Player is mainly an **observer** but can influence through console commands.
- **Local LLM via LM Studio** generates dynamic conversations based on mood, relationships, goals, and events.
- Simulation must be **deterministic** and **data-driven**.

## 1) Guardrails & Non-Goals

- No combat systems.
- Single-player or no-player loop must run without input.
- Prioritize determinism and performance over visual polish.

## 2) Tech Setup

- Engine: **Godot 4.x**, language: **GDScript**.
- Autoloads:
  - `LLMClient` for LM Studio API calls.
  - `EventBus` for pub/sub.
- Use **signals** for conversation lifecycle.

## 3) Folder Structure

```
/addons/
/autoload/               # LLMClient.gd, EventBus.gd
/components/             # DialogueComponent.gd, NeedsComponent.gd, ProximityAgent.gd
/controllers/            # ConversationController.gd, FloorManager.gd, TopicManager.gd, ContextPacker.gd, ConversationGroup.gd
/data/                    # JSON configs for actions, dialogue, traits, sim_limits
/debug/                   # Debug UIs
/scenes/                  # World.tscn, NPC.tscn
/ui/                      # DialogueBubble.tscn, Console.tscn
```

## 4) Core Systems

1. **LLM Wiring (M2.5)**
   - `LLMClient` for LM Studio calls, retries, and semi-deterministic sampling.
   - `ContextPacker` builds JSON context per turn.
   - Response parser validates `{utterance, intent, summary_note, relationship_effects, mood_shift}`.
2. **Conversation Engine (M2.7)**
   - `ConversationController` orchestrates groups.
   - `ConversationGroup` holds participants, topics, memory.
   - `FloorManager` manages speaking order.
   - `TopicManager` handles topic switching and event injection.
3. **Concurrency (M3.0)**
   - Scheduler with cooldown+jitter.
   - Caps for `max_active_groups` and `max_participants_per_group`.
   - Backpressure handling with fallback lines.
4. **Memory Compression (M3.5)**
   - Summarize conversations periodically.

## 5) Social Simulation Model

- **Participation invariant**: One conversation per NPC.
- **Drives**: `social_need`, `social_fatigue`, `extroversion`.
- Update needs/fatigue each tick; show in debug UI.

## 6) World Events → Dialogue Hooks

- `EventBus` publishes events.
- `TopicManager` maps to `event_topics.json`.
- `ContextPacker` includes hints with decay.
- Console commands like `:event weather rain`.

## 7) Non-Conversation Actions

- Movement, idle, environment interaction, commerce, food/drink, chores, leisure, rest, grooming, eavesdropping, gestures, reactions, and directed console actions.
- Data-driven from JSON.

## 8) Planner

- Start with **Utility AI**; keep pluggable for future GOAP/BT.

## 9) Console & Debug Tools

- Commands:
  - Conversation: `:topic`, `:merge`, `:inject`, `:mute`.
  - Events: `:event`.
  - Actions: `:move`, `:emote`.

## 10) Config & Limits

- `/data/config/sim_limits.json` defines caps, cooldowns, jitter, and token limits.

## 11) LM Studio Integration

- `.env` for URL/port.
- Health-check at startup; fallback if unavailable.
- Parallel requests with scheduler.

## 12) Milestones

- **M2.5**: LLM wiring, fallback works.
- **M2.7**: Multi-party conversation, topic shifts.
- **M2.8**: Social simulation model and proximity (COMPLETED).
- **M3.0**: Character status management and basic actions (COMPLETED - Sprint 3).
- **M3.5**: Environmental integration and advanced behaviors.
- **M4.0**: Advanced behaviors and complex action chains.
- **M4.5**: Full integration and production readiness.

## Sprint 0 Tasks

1. Create folder structure.
2. Implement `EventBus.gd`.
3. Implement `LLMClient.gd` with retries, timeouts.
4. Add `/data/dialogue/prompt_templates.json` and `/data/dialogue/fallback_templates.json`.
5. Build `Console.tscn` with basic commands.

## Sprint 1 Tasks

1. Implement `ContextPacker.gd`.
2. Create `ConversationGroup.gd`.
3. Build `FloorManager.gd`.
4. Create `TopicManager.gd`.
5. Implement `ConversationController.gd`.
6. Add `DialogueComponent.gd`.
7. Implement scheduler with caps and fallback.

## Sprint 2 Tasks

1. Implement `NeedsComponent.gd`.
2. Create `ProximityAgent.gd`.
3. Add JSON-driven non-conversation actions.
4. Enforce participation invariant.

## Character Action Implementation (Sprint 3-8)

### Overview
Replace `NeedsComponent` with comprehensive `StatusComponent` to drive all non-conversation actions through need-based behavior.

### Core Need Types
- **Physical**: energy, hunger, thirst, health
- **Comfort**: temperature, cleanliness, comfort
- **Activity**: boredom, curiosity, achievement_need
- **Economic**: wealth_satisfaction, material_need, security_need
- **Social**: social_need, social_fatigue (existing)

### Character Template Structure
```json
{
  "character_id": "template_npc",
  "name": "Template NPC",
  "personality": {
    "big_five": {"openness": 0.5, "conscientiousness": 0.5, "extraversion": 0.5, "agreeableness": 0.5, "neuroticism": 0.5},
    "traits": {"risk_tolerance": 0.5, "work_ethic": 0.5, "creativity": 0.5, "patience": 0.5}
  },
  "needs": {
    "physical": {"energy": {"current": 0.8, "decay_rate": 0.02, "recovery_rate": 0.05}},
    "comfort": {"temp_comfort": {"current": 0.0, "decay_rate": 0.02, "recovery_rate": 0.03}},
    "activity": {"boredom": {"current": 0.4, "decay_rate": 0.005, "recovery_rate": 0.1}},
    "economic": {"wealth_satisfaction": {"current": 0.5, "decay_rate": 0.001, "recovery_rate": 0.01}},
    "social": {"social_need": {"current": 0.5, "decay_rate": 0.01, "recovery_rate": 0.08}}
  },
  
  "inventory": {"money": 100, "items": [], "clothing": ["basic_shirt"], "tools": []},
  "schedule": {"sleep_time": {"start": 22, "end": 6}, "work_time": {"start": 8, "end": 17}},
  "relationships": {}, "memories": [], "goals": [], "current_action": null, "location": "home"
}
```

### Implementation Sprints

#### Sprint 3: Foundation & Core Needs (Week 1-2) - COMPLETED ✅
- ✅ Create `StatusComponent.gd` (replaces `NeedsComponent`)
- ✅ Implement all need types with decay/recovery logic
- ✅ Create `CharacterManager` for JSON persistence
- ✅ Update console commands for need management

**Status**: Sprint 3 completed successfully with all 4 tasks completed. The Action System is now fully functional.

#### Sprint 4: Action System & Planning (Week 3-4) - COMPLETED ✅
- ✅ Create `ActionDefinition` system with JSON schema
- ✅ Implement `ActionPlanner` with need-based scoring
- ✅ Basic action library (movement, interaction, rest, hygiene)
- ✅ Action execution framework

#### Sprint 4.5: Character Management System - COMPLETED ✅
- ✅ Create `CharacterManager.gd` as central autoload
- ✅ Implement character template system with base and individual templates
- ✅ Create comprehensive character data structure (needs, inventory, relationships, etc.)
- ✅ Implement character lifecycle management (creation, loading, saving, deletion)
- ✅ Add character query system (by location, need)
- ✅ Create initial character templates for island village population
- ✅ Integrate console commands for character management
- ✅ Add population analytics and export functionality

**Status**: CharacterManager implementation completed successfully. All 8 tasks completed for comprehensive character management system.

## Completion Status

### Sprint 3: Foundation & Core Needs ✅ **100% COMPLETED**
- ✅ Create `StatusComponent.gd` (replaces `NeedsComponent`)
- ✅ Implement all need types with decay/recovery logic
- ✅ Create `CharacterManager` for JSON persistence
- ✅ Update console commands for need management

### Sprint 4: Action System & Planning ✅ **100% COMPLETED**
- ✅ Create `ActionDefinition` system with JSON schema
- ✅ Implement `ActionPlanner` with need-based scoring
- ✅ Basic action library (movement, interaction, rest, hygiene)
- ✅ Action execution framework

### Sprint 4.5: Character Management System ✅ **100% COMPLETED**
- ✅ Create `CharacterManager.gd` as central autoload
- ✅ Implement character template system with base and individual templates
- ✅ Create comprehensive character data structure (needs, inventory, relationships, etc.)
- ✅ Implement character lifecycle management (creation, loading, saving, deletion)
- ✅ Add character query system (by location, need)
- ✅ Create initial character templates for island village population
- ✅ Integrate console commands for character management
- ✅ Add population analytics and export functionality

**Overall Progress**: Core character simulation systems are now fully implemented and integrated. The foundation is complete for advanced environmental integration and behavior systems in future sprints.

#### Sprint 5: Environmental Integration (Week 5-6)
- Create `EnvironmentalSensor` for context awareness
- Weather and time effects on needs
- Location-specific behaviors and schedule system

#### Sprint 6: Advanced Behaviors (Week 7-8)
- Advanced behavior patterns and decision making
- Complex action chains (cooking, crafting)
- Work/commerce and leisure systems

#### Sprint 7: Integration & Polish (Week 9-10)
- Full system integration with existing components
- Performance optimization and debugging tools
- Comprehensive testing

#### Sprint 8: Advanced Features & Polish (Week 11-12)
- Goal system and memory/learning
- Enhanced social dynamics
- Production-ready system

### Technical Architecture
```
StatusComponent (replaces NeedsComponent)
├── NeedManager (tracks all need types)
├── PersonalityModifier (applies traits)
├── NeedInteraction (handles conflicts)
└── NeedVisualizer (debug display)

ActionPlanner
├── NeedAnalyzer (identifies priorities)
├── ActionScorer (calculates best actions)
├── ConflictResolver (handles competing needs)
└── ActionSelector (chooses optimal action)

EnvironmentalSensor
├── LocationDetector (current position)
├── WeatherMonitor (environmental conditions)
├── TimeManager (circadian rhythms)
└── ResourceDetector (available actions)

CharacterManager ✅ IMPLEMENTED
├── DataLoader (JSON loading)
├── PersistenceManager (save/load)
├── TemplateSystem (character creation)
└── CharacterRegistry (active characters)
```

## ✅ **COMPLETED IMPLEMENTATIONS**

### StatusComponent.gd ✅
- **Comprehensive Need Management**: 5 need categories with 20+ individual needs
- **Personality Integration**: Big Five model and custom traits affecting need calculations
- **Environmental Awareness**: Location and context affecting need satisfaction
- **Action Drive Calculation**: Sophisticated scoring system for action selection

### Action System ✅
- **ActionPlanner.gd**: Need-based action selection with scoring and conflict resolution
- **ActionExecutor.gd**: Complete action lifecycle management with progress tracking
- **Comprehensive Action Library**: 25+ actions covering all island village needs
- **Location Integration**: Actions tagged with specific location requirements


### CharacterManager.gd ✅
- **Central Character Registry**: Manages all NPCs with unique IDs and data
- **Template System**: Base template + individual character templates for population
- **Lifecycle Management**: Creation, loading, saving, and deletion of characters
- **Query System**: Location and need-based character queries
- **Population Analytics**: Summary statistics and export functionality
- **Console Integration**: Comprehensive commands for character management

### Console Commands ✅
- **Need Management**: `:needs <npc_id> <command>` for need manipulation
- **Action Control**: `:action <npc_id> <command>` for action planning and execution
- **Execution Management**: `:execute <command>` for action lifecycle control
- **Population Control**: `:population <command>` for population overview and export
- **Character Management**: `:character_manager <command>` for character operations

### Action Drive Calculation
```gdscript
func calculate_action_drive(need_type: String) -> float:
    var base_need = needs[need_type]
    var urgency = 1.0 - base_need  # Higher need = higher urgency
    var personality_modifier = get_personality_modifier(need_type)
    var environmental_modifier = get_environmental_modifier(need_type)
    return urgency * personality_modifier * environmental_modifier
```

### Console Commands
- `:needs <npc_id> <command> [args...]` - Manage NPC needs
- `:character <npc_id> <command> [args...]` - Character management
- `:action <npc_id> <action_type> [args...]` - Force actions
- `:execute <npc_id> <command> [args...]` - Manage action execution
- `:status <npc_id> [detailed]` - Show character status

### Performance Targets
- Need updates: < 16ms (60 FPS)
- Action planning: < 100ms
- Memory usage: < 100MB for 20 characters
- Save/load: < 1 second

## Acceptance Tests

- LLM off → fallback lines.
- LLM on → parsed JSON updates mood/relationships.
- Events injected and decay.
- Caps enforced under load.
- Participation invariant maintained.

## Data Contracts

### Context JSON

Includes: persona, mood, health, relationships, recent topics, goals, location, `event_hint`.

### LLM Reply JSON

```json
{
  "utterance": "...",
  "intent": "continue|change_topic|ask_question|exit|...",
  "summary_note": "...",
  "relationship_effects": [{"target": "npc_id", "delta": 0.1, "tag": "reason"}],
  "mood_shift": {"valence": 1, "arousal": 0}
}
```

On parse error → fallback.

## Coding Style & Determinism

- Centralize RNG seeds.
- Use fixed timestep where possible.
- Log conversation state changes for debug/replay.

