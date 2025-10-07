# FennecTools for Godot

![Godot 4.x](https://img.shields.io/badge/Godot-4.x-%23478cbf?logo=godot-engine)
![License](https://img.shields.io/github/license/METROINDIO7/FennecTools-Godot)


**FennecTools** is a comprehensive plugin for Godot 4 that provides an integrated set of tools to streamline your game development. It centralizes common systems like dialogues, conditionals, translations, input control, and task organization.

[Documentation](https://my0-29.gitbook.io/fennectools-documentation)

## 🚀 Features

- **Conditional Editor**: Visual editor for game state variables and logic.
- **Dialogue System**: Create complex dialogues with multiple characters and expressions.
- **Translation Manager**: Multi-language support with automatic UI synchronization.
- **Input Control Config**: Customizable input mapping for keyboard, gamepad, and touch.
- **Kanban Board**: Integrated task board for project management.
- **Global API**: Easy access to all features via `FGGlobal` Autoload.

## 📦 Installation

1. Download the plugin from the [releases page](https://github.com/METROINDIO7/FennecTools-Godot/releases) or clone the repository.
2. Copy the `addons/FennecTools` folder to your Godot project.
3. Enable the plugin in `Project -> Project Settings -> Plugins`.
4. Restart the editor and access FennecTools from the main toolbar.

## 🎮 Quick Start

1. **Activate the Plugin**: Go to `Project -> Project Settings -> Plugins` and enable "Fennec Tools".
2. **Open FennecTools**: Click on the "Fennec Tools" tab in the top bar.
3. **Create a Conditional**: In the Conditional Editor, add a new conditional (e.g., `has_key` as a boolean).
4. **Use in Code**:

```gdscript
if FGGlobal.check_condition(1): # has_key
    open_door()
Create a Dialogue: Use the Dialogue System to create a conversation and launch it with a DialogueLauncher node.

📚 Documentation
For complete documentation, including API reference and tutorials, visit the GitBook documentation.


🤝 Contributing
Contributions are welcome! Please feel free to submit issues and pull requests.

📄 License
This project is licensed under the MIT License - see the LICENSE file for details.

text

Este README es conciso pero cubre lo esencial: qué es, características, instalación, un ejemplo rápido y enlaces a documentación y licencia. ¡Espero que sea útil!
