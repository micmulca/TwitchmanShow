# Character Simulation Overview

## Introduction

The TwitchMan Autonomous World features a sophisticated character simulation system that drives non-conversation behaviors through a comprehensive need management system and personality model. This document provides a detailed overview of how characters perceive, prioritize, and respond to their internal states and external environment.

## 🧠 Core Architecture

### StatusComponent Overview

The `StatusComponent` is the heart of the character simulation system, replacing the simpler `NeedsComponent` with a comprehensive status management framework. Each NPC in the world has a StatusComponent that tracks:

- **5 Need Categories** with 20+ individual needs
- **Personality Traits** using the Big Five model plus custom traits
- **Environmental Awareness** for location-based effects
- **Action Drive Calculation** for behavior prioritization
- **Critical Need Detection** for urgent situations

### Component Integration

```
StatusComponent
├── NeedManager (tracks all need types)
├── PersonalityModifier (applies traits)
├── NeedInteraction (handles conflicts)
├── EnvironmentalSensor (location effects)
└── ActionDriveCalculator (behavior priority)
```

## 📊 Need Management System

### Need Categories

The system tracks five primary need categories, each containing multiple individual needs with unique characteristics:

#### 1. Physical Needs
**Energy**: Core vitality that affects all activities
- **Range**: 0.0 (exhausted) to 1.0 (fully energized)
- **Decay Rate**: 0.02 per second (natural fatigue)
- **Recovery Rate**: 0.05 per second (rest recovery)
- **Critical Threshold**: 0.1 (below this triggers alerts)

**Hunger**: Food requirement for survival
- **Range**: 0.0 (satiated) to 1.0 (starving)
- **Decay Rate**: 0.01 per second (gradual hunger)
- **Recovery Rate**: 0.1 per second (eating recovery)
- **Critical Threshold**: 0.9 (above this triggers alerts)

**Thirst**: Water requirement for survival
- **Range**: 0.0 (hydrated) to 1.0 (dehydrated)
- **Decay Rate**: 0.015 per second (faster than hunger)
- **Recovery Rate**: 0.12 per second (drinking recovery)
- **Critical Threshold**: 0.9 (above this triggers alerts)

**Health**: Overall physical condition
- **Range**: 0.0 (critical) to 1.0 (perfect health)
- **Decay Rate**: 0.001 per second (very slow decline)
- **Recovery Rate**: 0.02 per second (natural healing)
- **Critical Threshold**: 0.2 (below this triggers alerts)

#### 2. Comfort Needs
**Temperature Comfort**: Environmental temperature satisfaction
- **Range**: -1.0 (too cold) to 1.0 (too hot), 0.0 is ideal
- **Decay Rate**: 0.02 per second (environmental changes)
- **Recovery Rate**: 0.03 per second (adaptation)
- **Critical Threshold**: 0.8 (extreme temperatures trigger alerts)

**Cleanliness**: Personal hygiene and appearance
- **Range**: 0.0 (filthy) to 1.0 (pristine)
- **Decay Rate**: 0.008 per second (gradual dirtiness)
- **Recovery Rate**: 0.15 per second (washing recovery)
- **Critical Threshold**: 0.1 (below this triggers alerts)

**Comfort**: General physical comfort and relaxation
- **Range**: 0.0 (uncomfortable) to 1.0 (very comfortable)
- **Decay Rate**: 0.01 per second (discomfort accumulation)
- **Recovery Rate**: 0.08 per second (rest recovery)
- **Critical Threshold**: 0.1 (below this triggers alerts)

#### 3. Activity Needs
**Boredom**: Need for stimulation and engagement
- **Range**: 0.0 (engaged) to 1.0 (extremely bored)
- **Decay Rate**: 0.005 per second (gradual boredom)
- **Recovery Rate**: 0.1 per second (activity recovery)
- **Critical Threshold**: 0.9 (above this triggers alerts)

**Curiosity**: Desire to explore and learn
- **Range**: 0.0 (uninterested) to 1.0 (highly curious)
- **Decay Rate**: 0.003 per second (slow decline)
- **Recovery Rate**: 0.05 per second (stimulation recovery)
- **Critical Threshold**: 0.1 (below this triggers alerts)

**Achievement Need**: Drive for accomplishment and progress
- **Range**: 0.0 (content) to 1.0 (driven for achievement)
- **Decay Rate**: 0.002 per second (very slow decline)
- **Recovery Rate**: 0.08 per second (success recovery)
- **Critical Threshold**: 0.1 (below this triggers alerts)

#### 4. Economic Needs
**Wealth Satisfaction**: Financial security and prosperity
- **Range**: 0.0 (financially secure) to 1.0 (wealthy)
- **Decay Rate**: 0.001 per second (very slow decline)
- **Recovery Rate**: 0.01 per second (income recovery)
- **Critical Threshold**: 0.8 (above this triggers alerts)

**Material Need**: Desire for possessions and resources
- **Range**: 0.0 (minimalist) to 1.0 (materialistic)
- **Decay Rate**: 0.001 per second (very slow decline)
- **Recovery Rate**: 0.05 per second (acquisition recovery)
- **Critical Threshold**: 0.8 (above this triggers alerts)

**Security Need**: Financial and material safety
- **Range**: 0.0 (secure) to 1.0 (insecure)
- **Decay Rate**: 0.001 per second (very slow decline)
- **Recovery Rate**: 0.02 per second (stability recovery)
- **Critical Threshold**: 0.8 (above this triggers alerts)

#### 5. Social Needs
**Social Need**: Desire for interaction and connection
- **Range**: 0.0 (solitary) to 1.0 (highly social)
- **Decay Rate**: 0.01 per second (isolation effect)
- **Recovery Rate**: 0.08 per second (interaction recovery)
- **Critical Threshold**: 0.1 (below this triggers alerts)

**Social Fatigue**: Exhaustion from social interaction
- **Range**: 0.0 (fresh) to 1.0 (socially exhausted)
- **Decay Rate**: 0.02 per second (interaction fatigue)
- **Recovery Rate**: 0.05 per second (solitude recovery)
- **Critical Threshold**: 0.8 (above this triggers alerts)

### Need Dynamics

#### Natural Decay and Recovery
- **Physical needs** (energy, hunger, thirst) naturally decay over time
- **Activity needs** (boredom, curiosity, achievement) naturally increase over time
- **Comfort needs** (cleanliness, comfort) gradually decline
- **Health and social fatigue** naturally recover over time

#### Environmental Modifiers
The system applies location-based effects to needs:

**Home Location**:
- Comfort recovery: +0.02 per second
- Cleanliness recovery: +0.01 per second

**Work Location**:
- Achievement need increase: +0.01 per second
- Energy decay: +0.005 per second (work is tiring)

**Outdoors Location**:
- Temperature comfort: Random variation (±0.01 per second)
- Cleanliness decay: +0.002 per second (outdoor activities)

#### Need Interactions and Conflicts
- **Energy affects all activities** - low energy reduces effectiveness
- **Hunger and thirst compete** - both need regular attention
- **Social need vs. social fatigue** - balance between interaction and rest
- **Comfort vs. achievement** - work may reduce comfort but increase achievement

## 🎭 Personality Model

### Big Five Personality Traits

The system implements the widely-accepted Big Five personality model, where each trait ranges from 0.0 (low) to 1.0 (high):

#### Openness to Experience
- **High (0.7-1.0)**: Curious, creative, open to new ideas
- **Medium (0.4-0.6)**: Balanced approach to novelty
- **Low (0.0-0.3)**: Traditional, prefers routine, practical

**Effects on needs**:
- Curiosity decay rate: ±0.03 per second
- Achievement need recovery: ±0.05 per second

#### Conscientiousness
- **High (0.7-1.0)**: Organized, responsible, goal-directed
- **Medium (0.4-0.6)**: Moderately organized
- **Low (0.0-0.3)**: Spontaneous, disorganized, easily distracted

**Effects on needs**:
- Energy maintenance: ±0.1 per second
- Achievement need: ±0.05 per second
- Work ethic modifier: ±0.3

#### Extraversion
- **High (0.7-1.0)**: Outgoing, energetic, socially confident
- **Medium (0.4-0.6)**: Balanced social energy
- **Low (0.0-0.3)**: Reserved, quiet, prefers solitude

**Effects on needs**:
- Social need: ±0.08 per second
- Social fatigue recovery: ±0.05 per second

#### Agreeableness
- **High (0.7-1.0)**: Cooperative, trusting, helpful
- **Medium (0.4-0.6)**: Balanced cooperation
- **Low (0.0-0.3)**: Competitive, challenging, skeptical

**Effects on needs**:
- Social need recovery: ±0.03 per second
- Comfort in social situations: ±0.02 per second

#### Neuroticism
- **High (0.7-1.0)**: Anxious, moody, easily stressed
- **Medium (0.4-0.6)**: Moderate emotional stability
- **Low (0.0-0.3)**: Calm, stable, emotionally secure

**Effects on needs**:
- Energy decay: ±0.02 per second
- Comfort recovery: ±0.03 per second

### Custom Personality Traits

Beyond the Big Five, the system includes additional traits that affect specific behaviors:

#### Risk Tolerance
- **Range**: 0.0 (risk-averse) to 1.0 (risk-seeking)
- **Effects**: Modifies action selection and need urgency

#### Work Ethic
- **Range**: 0.0 (lazy) to 1.0 (hardworking)
- **Effects**: 
  - Achievement need: ±0.02 per second
  - Energy maintenance: ±0.02 per second

#### Creativity
- **Range**: 0.0 (practical) to 1.0 (highly creative)
- **Effects**: Curiosity and achievement need recovery

#### Patience
- **Range**: 0.0 (impatient) to 1.0 (very patient)
- **Effects**: Need decay tolerance and recovery rates

### Personality Modifier System

The system calculates personality modifiers that affect need dynamics:

```gdscript
# Example: Conscientiousness affects energy maintenance
var modifier = (big_five.conscientiousness - 0.5) * 0.1
needs.physical.energy.current += modifier * delta

# Example: Extraversion affects social need
var modifier = (big_five.extraversion - 0.5) * 0.08
needs.social.social_need.current += modifier * delta
```

## 🎯 Action Drive System

### Need Urgency Calculation

The system calculates urgency for each need based on its current state and type:

#### High Urgency Needs (when low)
- **Energy, Health, Cleanliness, Comfort**: Urgent when below 30%
- **Formula**: `1.0 - ((current - min) / range)`

#### High Urgency Needs (when high)
- **Hunger, Thirst, Boredom, Security**: Urgent when above 70%
- **Formula**: `(current - min) / range`

#### Moderate Urgency Needs
- **Curiosity, Achievement Need**: Moderate urgency
- **Formula**: `0.5 + ((current - min) / range) * 0.5`

#### Complex Urgency Needs
- **Social Need**: Urgent when very low (<20%) or very high (>80%)
- **Temperature Comfort**: Urgent when extreme (too hot/cold)

### Action Drive Calculation

The overall action drive is calculated as:

```gdscript
var total_drive = 0.0
var need_count = 0

for each need:
    var urgency = calculate_need_urgency(need_type, current_value)
    var personality_modifier = get_personality_modifier(need_type)
    total_drive += urgency * personality_modifier
    need_count += 1

action_drive = total_drive / need_count
action_drive = clamp(action_drive, -1.0, 1.0)
```

### Need Priority System

Needs are automatically prioritized based on urgency:

1. **Critical needs** (above threshold) get highest priority
2. **High urgency needs** (above 70%) get high priority
3. **Moderate urgency needs** (30-70%) get medium priority
4. **Low urgency needs** (below 30%) get low priority

## 🌍 Environmental Integration

### Location-Based Effects

The system automatically applies environmental modifiers based on the character's current location:

#### Home Environment
- **Comfort recovery**: +0.02 per second
- **Cleanliness recovery**: +0.01 per second
- **Energy recovery**: +0.01 per second (restful)

#### Work Environment
- **Achievement need**: +0.01 per second (productive)
- **Energy decay**: +0.005 per second (tiring)
- **Social need**: +0.005 per second (colleagues)

#### Outdoor Environment
- **Temperature variation**: Random ±0.01 per second
- **Cleanliness decay**: +0.002 per second (dirt)
- **Curiosity**: +0.003 per second (exploration)

### Weather Integration (Planned)

Future versions will include weather effects:
- **Rain**: Reduces temperature comfort, increases indoor activity
- **Sunny**: Improves mood, increases outdoor activity
- **Storm**: Reduces comfort, increases safety concerns

## 🔧 Console Integration

### Status Commands

The system provides comprehensive console commands for debugging and manipulation:

#### Basic Status
```bash
character <npc_id> status          # Show full character status
character <npc_id> needs           # Display all need values
character <npc_id> personality     # Show personality traits
```

#### Need Manipulation
```bash
status_component <npc_id> set_need <need_type> <value>
status_component <npc_id> modify_need <need_type> <delta>
status_component <npc_id> priorities
```

#### Personality Adjustment
```bash
status_component <npc_id> set_personality <category> <trait> <value>
status_component <npc_id> set_location <location>
```

### Example Usage

```bash
# Check Alice's status
character alice status

# Make Alice hungry
status_component alice set_need hunger 0.8

# Make Alice more conscientious
status_component alice set_personality big_five conscientiousness 0.9

# Move Alice to work
status_component alice set_location work

# Check need priorities
status_component alice priorities
```

## 📈 Performance Characteristics

### Update Frequency
- **Need updates**: Every 100ms (10 times per second)
- **Action drive calculation**: Every 100ms
- **Critical need checks**: Every 100ms
- **Priority updates**: Every 100ms

### Memory Usage
- **Per character**: ~2KB for needs + personality
- **20 characters**: ~40KB total
- **Update overhead**: Minimal (simple calculations)

### Scalability
- **Current limit**: 20 characters (configurable)
- **Update batching**: All characters updated in single frame
- **LOD system**: Planned for future optimization

## 🚀 Future Enhancements

### Planned Features

#### Sprint 4: Action System
- **ActionPlanner**: Need-based action selection
- **Action definitions**: JSON-driven action library
- **Action execution**: Lifecycle management

#### Sprint 5: Environmental Integration
- **Weather effects**: Dynamic environmental modifiers
- **Time system**: Circadian rhythms and schedules
- **Resource detection**: Available actions and items

#### Sprint 6: Advanced Behaviors

- **Complex actions**: Multi-step behaviors
- **Economic system**: Trading and commerce

### Integration Points

The StatusComponent is designed to integrate with:
- **ConversationController**: Social need satisfaction
- **EventBus**: Need change notifications
- **World events**: Environmental effect triggers
- **NPC movement**: Location-based need effects

## 📝 Conclusion

The current need management system provides a solid foundation for autonomous character behavior with:

- **Comprehensive need tracking** across 5 categories
- **Sophisticated personality modeling** using Big Five + custom traits
- **Environmental awareness** for location-based effects
- **Intelligent priority system** for behavior selection
- **Full console integration** for debugging and testing

This system exceeds the original design requirements and provides the foundation for complex, realistic character behaviors in the autonomous world simulation. The next phase will focus on implementing the action system to bring these needs and personalities to life through actual behaviors.
