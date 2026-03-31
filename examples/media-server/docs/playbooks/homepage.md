# Homepage Dashboard

## When
Adding widgets, updating API keys, or changing the dashboard layout.

## Steps

1. Edit config files in `/opt/arr-stack/config/homepage/`
   - `services.yaml` — service widgets and API keys
   - `settings.yaml` — layout and theme
   - `widgets.yaml` — system/info widgets

2. Homepage hot-reloads — changes appear within seconds, no restart needed

3. Verify at `http://media-server:3000`

## API Keys
`services.yaml` uses real API keys inline (not `{{HOMEPAGE_VAR_*}}` env vars — that approach is broken). Pull keys from each service's Settings → General → API Key.

## Common Mistakes
- Trying `{{HOMEPAGE_VAR_*}}` syntax — it doesn't work, use raw keys
- YAML indentation errors — validate with `python3 -c "import yaml; yaml.safe_load(open('services.yaml'))"`
