Put bundled model directories here.

Supported bundle layouts:

1. `ios/Models/gemma-4-e2b-it-4bit/...`
2. `ios/Models/gemma-4-e4b-it-4bit/...`

The runtime already prefers bundled resources first:

- `Bundle.main.resourceURL/<directoryName>`
- `Bundle.main.resourceURL/Models/<directoryName>`

If the bundled model is missing or incomplete, the app falls back to
`Documents/models/<directoryName>` and can download the model there.
