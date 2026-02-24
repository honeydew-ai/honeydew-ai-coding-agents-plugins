# Honeydew AI Claude Plugins

A Claude Code plugin marketplace for Honeydew AI — skills and tools powered by the Honeydew MCP.

## Installation

Add this marketplace to Claude Code:

```
/plugin marketplace add honeydew-ai/honeydew-ai-claude-plugins
```

Then install individual plugins:

```
/plugin install <plugin-name>@honeydew-ai
```

## Available Plugins

_Coming soon — skills will be added shortly._

## Structure

```
honeydew-ai-claude-plugins/
├── .claude-plugin/
│   └── marketplace.json       # Marketplace catalog
├── plugins/
│   └── <plugin-name>/
│       ├── .claude-plugin/
│       │   └── plugin.json    # Plugin metadata
│       └── skills/
│           └── <skill-name>/
│               └── SKILL.md   # Skill instructions
└── README.md
```

## License

MIT
