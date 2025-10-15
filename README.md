FennecTools for Godot
https://img.shields.io/badge/Godot-4.x-%2523478cbf?logo=godot-engine
https://img.shields.io/github/license/METROINDIO7/FennecTools-Godot
https://img.shields.io/github/v/release/METROINDIO7/FennecTools-Godot

FennecTools is a comprehensive professional plugin for Godot 4 that provides an integrated suite of development tools to streamline your game creation process. Centralize common systems like dialogues, conditionals, translations, and input management in a unified editor interface.

🎯 Why FennecTools?
Stop reinventing the wheel for every project! FennecTools provides:

🚀 Rapid Development - Pre-built systems for common game mechanics

🎨 Visual Editors - No-code configuration for complex systems

🌍 Multi-language Ready - Built-in translation system

🎮 Input Management - Keyboard, gamepad, and touch support

💾 Save System - Automatic slot management and persistence

👥 Team Friendly - Integrated Kanban board for project management

✨ Core Features
🎭 Dialogue System
Create complex branching dialogues with emotional states, character expressions, and voice synchronization.

Key Features:

44 emotional states with visual color coding

Multi-character conversations with | separator

Automatic mouth animation synchronization

Voice line integration with pitch variation

Dynamic character name replacement

Customizable dialogue panels per character

⚙️ Conditional System
Manage game state with three variable types in a visual editor.

Variable Types:

Boolean: Flags and binary states (quest_completed, door_unlocked)

Numeric: Counters and statistics (player_gold, quest_progress)

Text Lists: Inventories and collections (player_items, met_npcs)

🌐 Translation Manager
Full multi-language support with automatic UI updates.

Advantages:

Flexible language codes (no strict ISO requirements)

Real-time editing with instant preview

Group-based node updating

Dynamic text replacement system

🎮 Input Control Config
Create accessible control schemes for all input methods.

Supported Inputs:

Keyboard/Mouse mapping

Gamepad/Controller support

Touch screen controls

Custom action bindings

📋 Kanban Board
Project management directly in Godot with drag & drop functionality.

Organization Tools:

Customizable columns for your workflow

Assignee filtering and due dates

Progress tracking and statistics

Persistent data storage

🚀 Quick Start
Installation
Download: Get the latest release from GitHub

Install: Copy addons/FennecTools to your project

Enable: Go to Project → Project Settings → Plugins and activate "Fennec Tools"

Restart: Completely close and reopen Godot for full functionality

Your First Dialogue System
Create a Character:

gdscript
# Add to your NPC scene:
- CharacterController node
- DialogueLauncher node  
- Set character_group_name: "merchant"
Design Dialogues:

Open Fennec Tools → Dialogue System

Add character "merchant"

Create dialogues with emotional states

Launch Dialogue:

gdscript
# Simple approach
FGGlobal.start_dialog(1, 3) # Start from ID 1, show 3 dialogues

# Advanced approach (recommended)
$DialogueLauncher.start()
Conditional Variables in Action
gdscript
# Check game state
if FGGlobal.check_condition(101): # has_key
    open_door()

# Modify values
FGGlobal.modify_condition(102, 100.0, "add") # Add 100 gold
FGGlobal.add_text_value(103, "Magic Sword") # Add to inventory

# Save progress
FGGlobal.save_game_to_current_slot()
Multi-language Setup
gdscript
# Configure translations
FGGlobal.current_language = "ES"
FGGlobal.set_translation_target_group("ui_elements")
FGGlobal.update_language()

# In your UI nodes:
# - Add to group "ui_elements" 
# - Set node.name to match translation keys
🛠️ System Requirements
Godot Version: 4.x (4.0+ recommended)

Project Setup: GDScript configuration

Space: 5-10 MB free space

Platform: Windows, macOS, Linux, Web, Mobile

📖 Documentation & Support
📚 Full Documentation: GitBook Documentation

🐛 Issue Tracking: GitHub Issues

💬 Community: Godot Engine community forums

🎓 Learning Resources
Example Projects
RPG System: Complete quest system with inventory

Visual Novel: Branching dialogues with emotional expressions

Platformer: Interactive NPCs and progression tracking

Video Tutorials
Getting Started with FennecTools

Advanced Dialogue Systems

Multi-language Implementation

🔧 Advanced Features
Custom Nodes
FennecTools provides specialized nodes for seamless integration:

DialogueLauncher - Advanced dialogue sequence management

CharacterController - Facial expressions and animations

DialogPanelController - Customizable dialogue UI

NodeGrouper - Dynamic node activation/deactivation

ExpressionState - Reusable emotional states

API Access
All systems accessible via global FGGlobal Autoload:

gdscript
# Cross-system integration example
func complete_quest():
    FGGlobal.modify_condition(201, true) # Mark quest complete
    FGGlobal.start_dialog(301, 2) # Celebration dialogue
    FGGlobal.add_text_value(401, "Quest Reward") # Add to inventory
🤝 Contributing
We welcome contributions! Please see our Contributing Guidelines for details.

Development Setup
Fork the repository

Create a feature branch

Submit a pull request with clear description

📄 License
This project is licensed under the MIT License - see the LICENSE file for details.

🏆 Showcase
Games built with FennecTools:

Your Game Here - Submit your FennecTools project!
