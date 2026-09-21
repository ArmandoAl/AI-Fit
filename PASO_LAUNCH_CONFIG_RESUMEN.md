# Resumen: Configuración de launch.json con Dart-Defines y Protección en Gitignore

## 1. Estructura de `.vscode/launch.json` y Plantillas Creadas

Para permitir el inicio rápido, depuración y ejecución fluida en simuladores y emuladores (iOS / Android / Chrome) sin riesgo de exponer credenciales en control de versiones, se configuró la arquitectura de lanzamiento local en VS Code / Cursor.

### Archivos Generados:
- **`.vscode/launch.example.json` (Trackeado en Git):** Plantilla pública de referencia para desarrolladores con placeholders.
- **`.vscode/launch.json` (Ignorado por Git):** Archivo de configuración local activo en el workspace.
- **`env.example.json` (Trackeado en Git):** Plantilla de variables de entorno para usar con `--dart-define-from-file`.
- **`env.json` (Ignorado por Git):** Archivo local de variables de entorno.

### Configuraciones Disponibles en `.vscode/launch.json`:
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "AI-Fit (Dev - iOS Simulator)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "toolArgs": [
        "--dart-define=SUPABASE_URL=https://cictlfpnohrnvfchtroa.supabase.co",
        "--dart-define=SUPABASE_ANON_KEY=TU_ANON_KEY_AQUI"
      ]
    },
    {
      "name": "AI-Fit (Dev - Android/Chrome)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "toolArgs": [
        "--dart-define=SUPABASE_URL=https://cictlfpnohrnvfchtroa.supabase.co",
        "--dart-define=SUPABASE_ANON_KEY=TU_ANON_KEY_AQUI"
      ]
    },
    {
      "name": "AI-Fit (Dev - File Defines env.json)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "toolArgs": [
        "--dart-define-from-file=env.json"
      ]
    }
  ]
}
```

---

## 2. Reglas de Protección en `.gitignore`

Se agregaron directivas estrictas en [.gitignore](file:///Users/armandoalvarado/Documents/AI-Fit/.gitignore) para asegurar que ningún archivo local con secretos reales pueda ser añadido accidentalmente a Git:

```gitignore
# VS Code launch configurations containing local secrets
.vscode/launch.json
.vscode/*.local.json
!.vscode/launch.example.json

# Environment files and secrets
.env
.env.*
*.env
env.json
*.env.json
!env.example.json
serviceAccountKey*.json
*.serviceAccountKey.json
```

### Verificación de Seguridad:
Comprobado mediante `git check-ignore -v`:
- `.vscode/launch.json` $\rightarrow$ **Ignorado** por `.gitignore:22`.
- `env.json` $\rightarrow$ **Ignorado** por `.gitignore:55`.
- `.vscode/launch.example.json` $\rightarrow$ **Trackeado** permitido por `!.vscode/launch.example.json`.
- `env.example.json` $\rightarrow$ **Trackeado** permitido por `!env.example.json`.

---

## 3. Instrucciones de Uso para el Desarrollador (F5 / Play)

### Opción A: Configurar mediante `.vscode/launch.json`
1. Abre [.vscode/launch.json](file:///Users/armandoalvarado/Documents/AI-Fit/.vscode/launch.json) en tu editor.
2. Reemplaza `TU_ANON_KEY_AQUI` por tu anon key real de Supabase:
   ```json
   "--dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
   ```
3. En la barra lateral de VS Code o Cursor, ve a la pestaña **Run & Debug** (icono de play con escarabajo) o presiona `Ctrl+Shift+D` / `Cmd+Shift+D`.
4. En el menú desplegable superior selecciona:
   - **`AI-Fit (Dev - iOS Simulator)`** para simulador de iPhone.
   - **`AI-Fit (Dev - Android/Chrome)`** para emulador Android o navegador Chrome.
5. Presiona **F5** (o el botón verde de Play). La app compilará e inyectará automáticamente `SUPABASE_URL` y `SUPABASE_ANON_KEY` en tiempo de compilación.

### Opción B: Configurar mediante `env.json`
1. Copia [env.example.json](file:///Users/armandoalvarado/Documents/AI-Fit/env.example.json) a `env.json` en la raíz del proyecto.
2. Edita `env.json` colocando tus credenciales:
   ```json
   {
     "SUPABASE_URL": "https://cictlfpnohrnvfchtroa.supabase.co",
     "SUPABASE_ANON_KEY": "tu_anon_key_real"
   }
   ```
3. En **Run & Debug**, selecciona **`AI-Fit (Dev - File Defines env.json)`** y pulsa **F5**.

---

## 4. Verificación de Compilación y Calidad de Código

- **`fvm flutter analyze`:**
  ```bash
  Analyzing AI-Fit...
  No issues found! (ran in 5.1s)
  ```
  **0 errores, 0 advertencias**.

- **`fvm flutter test` con flags de `--dart-define` y `--dart-define-from-file`:**
  ```bash
  fvm flutter test --dart-define-from-file=env.json test/smoke_test.dart
  All tests passed! (18/18 tests passed)
  ```
